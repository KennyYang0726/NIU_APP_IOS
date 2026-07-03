import Foundation
import SwiftUI
import Combine


// 流程：SSOSession token -> 依 exp 判斷是否需要 refreshToken POST -> 覆寫 token/exp -> GUID GET 三次 -> 覆寫 guid1/guid2/guid3
@MainActor
final class SessionManager: ObservableObject {

    @Published var ssoDataInvalid: Bool = false // 通知 HomeView 是否登入過期，true 即過期

    /*let webZuvio = WebView_Provider(
        initialURL: "https://irs.zuvio.com.tw/student5/setting/index",
        userAgent: .mobile
    )*/

    let webMail = WebView_Provider(
        initialURL: "https://mail.niu.edu.tw/NUMail/Mobile/Box/INBOX",
        userAgent: .mobile
    )

    // 可選：給 AppRoot 判斷登入/登出後該顯示哪個根畫面
    @Published var isAuthenticated: Bool = true

    private var isRefreshingSSOID = false

    private let loginRepo = LoginRepository()
    private let loginStreak = LoginStreakManager()
    private let loginStreakBright = LoginStreakManagerBright()

    private let refreshThresholdSeconds: TimeInterval = 10 * 60 // 小於10分鐘就判定為需要刷新

    private enum SSOAPI {
        static let refreshToken = "https://ccsys1.niu.edu.tw/SSO/API/Login/refreshToken"
        static let guidBase = "https://ccsys1.niu.edu.tw/SSO/API/GUID"
    }

    private struct RefreshTokenResponse: Decodable {
        let success: Bool?
        let message: String?
        let token: String?
        let exp: String?
    }

    private struct GUIDResponse: Decodable {
        let guid: String?
    }

    // MARK: - Public SSO Entry Points

    /// 建議給 keepAlive 使用。
    /// 只檢查 token/exp，只有 token 已過期或距離 exp 小於 5 分鐘才會刷新 token。
    /// 如果真的有 refresh token，會順便刷新 GUID。
    func refreshSSOSessionIfNeeded() {
        runSSOOperation(
            forceTokenRefresh: false,
            forceGUIDRefresh: false,
            reason: "refresh if needed"
        )
    }

    /// 建議給 HomeView 的 onAppear / onResume 使用。
    /// token 依 exp 判斷是否需要刷新，但 GUID 每次都會強制刷新。
    ///
    /// 原因：
    /// 有些功能頁使用 GUID 直接登入，例如 ACADE、活動報名、M園區。
    /// GUID 可能比 token 更短效，或可能偏向一次性票券。
    /// 所以只因 token 還沒快過期就跳過 GUID 更新，可能會讓功能頁拿到舊 GUID。
    func refreshHomeSSOState() {
        runSSOOperation(
            forceTokenRefresh: false,
            forceGUIDRefresh: true,
            reason: "home refresh token if needed + force refresh GUIDs"
        )
    }

    /// 保留舊名稱，避免其他既有呼叫點壞掉。
    /// 行為等同 refreshSSOSessionIfNeeded()，不會每次都強制刷新。
    func refreshSSOSession() {
        refreshSSOSessionIfNeeded()
    }

    /// 只強制刷新 GUID，不強制 refresh token。
    /// 如果 token 已經快過期，會先 refresh token，再用新 token 抓 GUID。
    func forceRefreshGUIDs() {
        runSSOOperation(
            forceTokenRefresh: false,
            forceGUIDRefresh: true,
            reason: "force refresh GUIDs"
        )
    }

    /// 強制刷新 SSO token，並且刷新 GUID。
    /// 一般不建議使用；除非你明確需要忽略 exp，直接向後端刷新 token。
    func forceRefreshSSOSession() {
        runSSOOperation(
            forceTokenRefresh: true,
            forceGUIDRefresh: true,
            reason: "force refresh token + GUIDs"
        )
    }

    private func runSSOOperation(
        forceTokenRefresh: Bool,
        forceGUIDRefresh: Bool,
        reason: String
    ) {
        guard !isRefreshingSSOID else {
            print("[SSO][HOME] operation already running, skip:", reason)
            return
        }

        isRefreshingSSOID = true

        Task { [weak self] in
            guard let self else { return }

            await self.performSSOOperation(
                forceTokenRefresh: forceTokenRefresh,
                forceGUIDRefresh: forceGUIDRefresh,
                reason: reason
            )
        }
    }

    private func performSSOOperation(
        forceTokenRefresh: Bool,
        forceGUIDRefresh: Bool,
        reason: String
    ) async {
        defer {
            isRefreshingSSOID = false
        }

        print("[SSO][HOME] start operation:", reason)

        var tokenToUse = SSOSession.shared.token

        guard !tokenToUse.isEmpty else {
            print("[SSO][HOME] Missing stored SSO token")
            ssoDataInvalid = true
            return
        }

        do {
            let shouldRefreshToken: Bool

            if forceTokenRefresh {
                shouldRefreshToken = true
            } else {
                shouldRefreshToken = await shouldRefreshSSOToken()
            }

            if shouldRefreshToken {
                let refreshed = try await requestRefreshToken(currentToken: tokenToUse)

                SSOSession.shared.update(
                    token: refreshed.token,
                    exp: refreshed.exp
                )

                tokenToUse = refreshed.token

                print("[SSO][HOME] refreshToken OK, token/exp saved")
            } else {
                print("[SSO][HOME] token still valid, skip token refresh")
            }

            if shouldRefreshToken || forceGUIDRefresh {
                try await refreshAllGUIDs(token: tokenToUse)
            }

            ssoDataInvalid = false
        } catch SSOHomeRefreshError.unauthorized {
            print("[SSO][HOME] token unauthorized / expired")
            ssoDataInvalid = true
        } catch {
            // 非 401 的網路或格式錯誤，不直接視為登入過期，避免誤觸原本的過期 alert。
            print("[SSO][HOME] SSO operation failed:", error.localizedDescription)
        }
    }

    private func shouldRefreshSSOToken() async -> Bool {
        let currentToken = SSOSession.shared.token
        let expString = SSOSession.shared.tokenExp

        guard !currentToken.isEmpty else {
            print("[SSO][HOME] Missing stored SSO token")
            ssoDataInvalid = true
            return false
        }

        guard !expString.isEmpty else {
            print("[SSO][HOME] Missing exp, refresh needed")
            return true
        }

        guard let expDate = parseTaipeiISODate(expString) else {
            print("[SSO][HOME] Cannot parse exp, refresh needed:", expString)
            return true
        }

        let nowDate = await getReliableTaipeiNowDate()
        let remainingSeconds = expDate.timeIntervalSince(nowDate)
        let remainingMinutes = remainingSeconds / 60.0

        print("[SSO][HOME] token remaining minutes:", remainingMinutes)

        if remainingSeconds <= 0 {
            print("[SSO][HOME] token already expired, refresh needed")
            return true
        }

        if remainingSeconds <= refreshThresholdSeconds {
            print("[SSO][HOME] token expires within 5 minutes, refresh needed")
            return true
        }

        return false
    }

    private func refreshAllGUIDs(token: String) async throws {
        let username = loginRepo.loadCredentials()?.username ?? ""

        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[SSO][HOME] Missing username from LoginRepository")
            throw SSOHomeRefreshError.invalidUsername
        }

        let guid1 = try await requestGUID(username: username, token: token, index: 1)
        let guid2 = try await requestGUID(username: username, token: token, index: 2)
        let guid3 = try await requestGUID(username: username, token: token, index: 3)

        SSOSession.shared.updateGUIDs(
            guid1: guid1,
            guid2: guid2,
            guid3: guid3
        )

        print("[SSO][HOME] GUID1 saved:", guid1)
        print("[SSO][HOME] GUID2 saved:", guid2)
        print("[SSO][HOME] GUID3 saved:", guid3)
    }

    // MARK: - Time

    private func fetchTaipeiDateTimeAsync() async -> String? {
        await withCheckedContinuation { continuation in
            TimeService.shared.fetchTaipeiDateTime { datetime in
                continuation.resume(returning: datetime)
            }
        }
    }

    private func getReliableTaipeiNowDate() async -> Date {
        if let serverTimeString = await fetchTaipeiDateTimeAsync(),
           let serverDate = parseTaipeiISODate(serverTimeString) {
            print("[SSO][HOME] using stdtime:", serverTimeString)
            return serverDate
        }

        let localTaipeiString = makeLocalTaipeiISODateTimeString()
        print("[SSO][HOME] stdtime failed, fallback local time:", localTaipeiString)

        // Date 本身是絕對時間點，沒有時區問題。
        // 上面的 localTaipeiString 只用於 log，實際計算直接用 Date() 較穩。
        return Date()
    }

    private func parseTaipeiISODate(_ raw: String) -> Date? {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        let formatterWithFraction = DateFormatter()
        formatterWithFraction.locale = Locale(identifier: "en_US_POSIX")
        formatterWithFraction.calendar = Calendar(identifier: .gregorian)
        formatterWithFraction.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatterWithFraction.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSXXXXX"

        if let date = formatterWithFraction.date(from: cleaned) {
            return date
        }

        let formatterWithoutFraction = DateFormatter()
        formatterWithoutFraction.locale = Locale(identifier: "en_US_POSIX")
        formatterWithoutFraction.calendar = Calendar(identifier: .gregorian)
        formatterWithoutFraction.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatterWithoutFraction.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"

        return formatterWithoutFraction.date(from: cleaned)
    }

    private func makeLocalTaipeiISODateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSXXXXX"

        return formatter.string(from: Date())
    }

    // MARK: - API Errors

    private enum SSOHomeRefreshError: LocalizedError {
        case invalidURL
        case unauthorized
        case badStatus(Int)
        case missingToken
        case missingGUID
        case invalidUsername

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "SSO API URL invalid"
            case .unauthorized:
                return "SSO token unauthorized"
            case .badStatus(let status):
                return "SSO API bad status: \(status)"
            case .missingToken:
                return "SSO refresh response missing token"
            case .missingGUID:
                return "SSO GUID response missing guid"
            case .invalidUsername:
                return "Username is invalid"
            }
        }
    }

    // MARK: - API Requests

    private func requestRefreshToken(currentToken: String) async throws -> (token: String, exp: String?) {
        guard let url = URL(string: SSOAPI.refreshToken) else {
            throw SSOHomeRefreshError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://ccsys1.niu.edu.tw", forHTTPHeaderField: "Origin")
        request.setValue("https://ccsys1.niu.edu.tw/SSO/dashboard/student", forHTTPHeaderField: "Referer")

        print("[SSO][HOME] POST /SSO/API/Login/refreshToken")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""

        print("[SSO][HOME] refreshToken status:", statusCode)
        print("[SSO][HOME] refreshToken body:", body)

        if statusCode == 401 {
            throw SSOHomeRefreshError.unauthorized
        }

        guard statusCode >= 200 && statusCode < 300 else {
            throw SSOHomeRefreshError.badStatus(statusCode)
        }

        let decoded = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)

        guard let token = decoded.token, !token.isEmpty else {
            throw SSOHomeRefreshError.missingToken
        }

        return (token: token, exp: decoded.exp)
    }

    private func requestGUID(
        username: String,
        token: String,
        index: Int
    ) async throws -> String {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            throw SSOHomeRefreshError.invalidUsername
        }

        guard let encodedUsername = trimmedUsername.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(SSOAPI.guidBase)/\(encodedUsername)") else {
            throw SSOHomeRefreshError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://ccsys1.niu.edu.tw/SSO/dashboard/student", forHTTPHeaderField: "Referer")

        print("[SSO][HOME] GET /SSO/API/GUID/\(trimmedUsername) #\(index)")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""

        print("[SSO][HOME] GUID#\(index) status:", statusCode)
        print("[SSO][HOME] GUID#\(index) body:", body)

        if statusCode == 401 {
            throw SSOHomeRefreshError.unauthorized
        }

        guard statusCode >= 200 && statusCode < 300 else {
            throw SSOHomeRefreshError.badStatus(statusCode)
        }

        let decoded = try JSONDecoder().decode(GUIDResponse.self, from: data)

        guard let guid = decoded.guid, !guid.isEmpty else {
            throw SSOHomeRefreshError.missingGUID
        }

        return guid
    }

    // MARK: - 登出流程（不依賴任何畫面是否在眼前）

    func logout(appState: AppState, appSettings: AppSettings, loginRepo: LoginRepository) {
        // let Zuvio_Logout_JS = "setting_logout();"
        let Mail_Logout_JS = """
        (function() {
          var spans = document.querySelectorAll('span.sc-pLxQr.dlxlap');
          for (var i = 0; i < spans.length; i++) {
            if (spans[i].innerText.trim() === '登出') {
              spans[i].click();
              return 'clicked';
            }
          }
          return 'not found';
        })();
        """

        // 新版 SSO token / guid 已由 SSOSession 管理，登出時清掉本機 SSO session 即可。
        SSOSession.shared.clear()

        // 1) Zuvio / Mail WebView 各自執行登出 JS → 清快取。
        let group = DispatchGroup()

        /*group.enter()
        webZuvio.evaluateJS(Zuvio_Logout_JS) { [weak self] _ in
            self?.webZuvio.clearCache {
                group.leave()
            }
        }*/

        group.enter()
        webMail.evaluateJS(Mail_Logout_JS) { [weak self] _ in
            self?.webMail.clearCache {
                group.leave()
            }
        }

        // 2) 立即清本機（帳密/姓名），連續登入紀錄，M園區課程資料
        loginRepo.clearCredentials()
        loginStreak.clearPrefs()
        loginStreakBright.clearPrefs()

        if let EUNI_CourseData = UserDefaults(suiteName: "EUNIcourseData") {
            EUNI_CourseData.removePersistentDomain(forName: "EUNIcourseData")
            EUNI_CourseData.synchronize()
        }

        appSettings.name = ""

        // 3) 統一導回登入頁
        group.notify(queue: .main) {
            self.isAuthenticated = false
            appState.navigate(to: .login, withToast: LocalizedStringKey("logout_success"))
        }
    }
}
