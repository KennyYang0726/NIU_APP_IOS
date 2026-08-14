import Foundation
import SwiftUI
import Combine

/// MVVM: 負責「狀態」與「業務邏輯」

// MARK: - Alert 狀態枚舉
enum LoginAlert: Identifiable {
    // 基本登入
    case emptyFields
    case loginFailed
    // 強制提示
    case forceNotice(title: String, message: String)
    // 發現新版本
    case newVersion(message: String)
    // === SSO 專用 ===
    case ssoCredentialsFailed(message: String)          // 帳密錯誤
    case ssoPasswordExpired(message: String)            // 密碼已到期（SweetAlert）
    case ssoAccountLocked(lockTime: String?)            // 帳號鎖定；新版直接傳 SweetAlert 文字
    case ssoSystemError                                 // 系統錯誤
    case ssoGeneric(title: String, message: String)     // 其他通用訊息

    var id: String {
        switch self {
        case .emptyFields: return "emptyFields"
        case .loginFailed: return "loginFailed"
        case .forceNotice(let title, let message): return "forceNotice:\(title)|\(message)"
        case .newVersion(let m): return m
        case .ssoCredentialsFailed(let m): return "ssoCredentialsFailed:\(m)"
        case .ssoPasswordExpired(let m): return "ssoPasswordExpired:\(m)"
        case .ssoAccountLocked(let t): return "ssoAccountLocked:\(t ?? "")"
        case .ssoSystemError: return "ssoSystemError"
        case .ssoGeneric(let t, let m): return "ssoGeneric:\(t)|\(m)"
        }
    }
}

// MARK: - ViewModel 主體
final class LoginViewModel: ObservableObject {

    private let repository = LoginRepository()
    private let versionManager = VersionManager()

    // MARK: - 使用者輸入 & UI 狀態
    @Published var account: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false

    // MARK: - Alert 狀態
    @Published var LoginActiveAlert: LoginAlert?

    // MARK: - 登入狀態與流程
    @Published var startSSOLoginProcess = false
    @Published var startMailLoginProcess = false

    @Published var ssoLoginSuccess = false
    @Published var mailLoginSuccess = false
    // 這個代表「流程都結束了」
    @Published var loginFinishedToken: Int = 0
    // 這個代表「已經允許導頁到 Home」才會觸發
    @Published var proceedToHomeToken: Int = 0

    // progress overlay
    @Published var showOverlay: Bool = false
    @Published var overlayText: LocalizedStringKey = "logining"
    
    // MARK: - 跑馬燈公告
    @Published var marqueeAnnouncement: MarqueeAnnouncement = .empty
    
    // MARK: - Network & Timeout
    private let loginTimeoutInterval: TimeInterval = 17
    private var loginTimeoutWorkItem: DispatchWorkItem?
    
    // MARK: - 衍生屬性
    var loginAccount: String {
        return account.split(separator: "@").first.map(String.init) ?? ""
    }

    // MARK: - 動作事件
    func onTapLogin() {
        // 無網際網路
        guard NetworkMonitor.shared.isConnected else {
            LoginActiveAlert = .ssoGeneric(
                title: AppLocalization.localized("No_Network_Title", comment: ""),
                message: AppLocalization.localized("No_Network_Message", comment: "")
            )
            return
        }
        guard !account.isEmpty, !password.isEmpty else {
            LoginActiveAlert = .emptyFields
            return
        }
        cancelLoginTimeout()
        showOverlay = true
        ssoLoginSuccess = false
        mailLoginSuccess = false
        LoginActiveAlert = nil
        startSSOLoginProcess = true
        startMailLoginProcess = true
        // 超時檢測開始
        startLoginTimeout()
    }

    func autoLogin() {
        // 無網際網路
        guard NetworkMonitor.shared.isConnected else {
            LoginActiveAlert = .ssoGeneric(
                title: AppLocalization.localized("No_Network_Title", comment: ""),
                message: AppLocalization.localized("No_Network_Message", comment: "")
            )
            return
        }
        if let saved = repository.loadCredentials() {
            account = saved.username
            password = saved.password
            cancelLoginTimeout()
            showOverlay = true
            ssoLoginSuccess = false
            mailLoginSuccess = false
            LoginActiveAlert = nil
            startSSOLoginProcess = true
            startMailLoginProcess = true
            // 超時檢測開始
            startLoginTimeout()
        }
    }
    
    func handleMailLoginResult(_ success: Bool) {
        startMailLoginProcess = false
        mailLoginSuccess = success
        checkLoginResult()
    }

    /// 新版 SSO 的結果收斂。
    /// SSOLoginWebView 會在 dashboard 姓名擷取完成後，才回傳 .success。
    /// 失敗狀態則由新版 SweetAlert 文字轉成固定 case 後回傳。
    func handleSSOLoginResult(_ result: SSOLoginResult) {
        switch result {
        case .success(_):
            finishSSOLogin(success: true)

        case .credentialsFailed(let message):
            finishSSOLogin(
                success: false,
                alert: .ssoCredentialsFailed(message: message)
            )

        case .accountLocked(let message):
            finishSSOLogin(
                success: false,
                alert: .ssoAccountLocked(lockTime: message)
            )

        case .passwordExpired(let message):
            finishSSOLogin(
                success: false,
                alert: .ssoPasswordExpired(message: message)
            )

        case .ssoUnauthorized(let message):
            finishSSOLogin(
                success: false,
                alert: .ssoGeneric(
                    title: AppLocalization.localized("login_failed_title", comment: ""),
                    message: message
                )
            )

        case .systemError(let message):
            if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finishSSOLogin(
                    success: false,
                    alert: .ssoSystemError
                )
            } else {
                finishSSOLogin(
                    success: false,
                    alert: .ssoGeneric(
                        title: AppLocalization.localized("Dialog_SystemError_Title", comment: ""),
                        message: message
                    )
                )
            }

        case .generic(let title, let message):
            finishSSOLogin(
                success: false,
                alert: .ssoGeneric(title: title, message: message)
            )
        }
    }

    /// 單一入口收斂 SSO 結果，避免不同 case 漏掉 startSSOLoginProcess 或 checkLoginResult。
    ///
    /// 規則：
    /// - SSO 成功：保留原本三方登入收斂邏輯，等 Zuvio / Mail 都完成後才關閉 overlay、儲存帳密與導頁。
    /// - SSO 失敗：本次登入已不可能成功，立即取消超時計時器、關閉其他 WebView 流程、關閉 overlay，避免之後又跳出 timeout alert。
    private func finishSSOLogin(
        success: Bool,
        alert: LoginAlert? = nil
    ) {
        startSSOLoginProcess = false
        ssoLoginSuccess = success

        if let alert {
            LoginActiveAlert = alert
        }

        if success {
            checkLoginResult()
            return
        }

        // SSO 已明確失敗，整體登入不可能成功；立即終止本輪所有流程。
        cancelLoginTimeout()

        startMailLoginProcess = false
        startSSOLoginProcess = false

        mailLoginSuccess = false
        ssoLoginSuccess = false

        showOverlay = false

        loginFinishedToken += 1

        if shouldClearCredentialsForThisFailure() {
            repository.clearCredentials()
        }
    }

    private func cancelLoginTimeout() {
        loginTimeoutWorkItem?.cancel()
        loginTimeoutWorkItem = nil
    }

    private func checkLoginResult() {
        // 當三邊都完成才收斂
        guard !startSSOLoginProcess, !startMailLoginProcess else { return }
        // 超時檢測結束
        cancelLoginTimeout()
        // UI 收斂
        showOverlay = false
        // 這裡代表「本次登入嘗試已完成」
        loginFinishedToken += 1

        let allSuccess = (ssoLoginSuccess && mailLoginSuccess)
        if allSuccess {
            // 成功才存帳密
            repository.saveCredentials(username: account.uppercased(), password: password)
            proceedToHomeToken += 1
        } else {
            // 只有「帳密錯誤」、「密碼已到期」或「新版 SSO Unauthorized」才清帳密
            if shouldClearCredentialsForThisFailure() {
                repository.clearCredentials()
            }
        }
    }

    private func shouldClearCredentialsForThisFailure() -> Bool {
        guard let alert = LoginActiveAlert else { return false }
        switch alert {
        case .ssoCredentialsFailed:
            return true
        case .ssoPasswordExpired:
            return true
        case .ssoGeneric(_, let message):
            let lowered = message.lowercased()
            return message.contains("Unauthorized") || lowered.contains("unauthorized")
        default:
            return false
        }
    }

    func togglePasswordVisible() {
        isPasswordVisible.toggle()
    }
    
    // MARK: - 開啟修改密碼頁
    func openSSOPasswordChange(completion: @escaping () -> Void) {
        guard let url = URL(string: "https://ccsys1.niu.edu.tw/SSO/force-change-password") else {
            completion()
            return
        }
        UIApplication.shared.open(url, options: [:]) { _ in
            completion()
        }
        startSSOLoginProcess = false
    }
    
    func checkAppVersionThenProceed(onProceed: @escaping () -> Void) {
        versionManager.checkNewVersion { [weak self] canProceed, remoteVersion in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if !canProceed, let remoteVersion = remoteVersion {
                    self.LoginActiveAlert = .newVersion(message: remoteVersion)
                } else {
                    onProceed()
                }
            }
        }
    }
    
    // 超時檢測
    private func startLoginTimeout() {
        loginTimeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 若登入尚未完成，視為失敗
            if self.startSSOLoginProcess || self.startMailLoginProcess {

                let ssoPending = self.startSSOLoginProcess
                let mailPending = self.startMailLoginProcess

                self.stopAllLoginProcessesForTimeout()
                self.loginFinishedToken += 1

                // 根據卡住的來源顯示不同訊息
                if ssoPending {
                    self.LoginActiveAlert = .ssoGeneric(
                        title: AppLocalization.localized("Dialog_Timeout_Title", comment: ""),
                        message: AppLocalization.localized("Dialog_SSO_Timeout_Message", comment: "")
                    )
                } else if mailPending {
                    self.LoginActiveAlert = .ssoGeneric(
                        title: AppLocalization.localized("Dialog_Timeout_Title", comment: ""),
                        message: AppLocalization.localized("Dialog_Mail_Timeout_Message", comment: "")
                    )
                }
            }
        }

        loginTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + loginTimeoutInterval, execute: workItem)
    }

    /// 超時時必須一次關閉所有 WebView 流程，避免 SSOLoginWebView 被 VM 判定超時後仍持續 reload。
    private func stopAllLoginProcessesForTimeout() {
        startSSOLoginProcess = false
        startMailLoginProcess = false

        showOverlay = false

        ssoLoginSuccess = false
        mailLoginSuccess = false

    }
    
    // MARK: - 版本資訊讀取
    func handleUpdateAction() {
        FirebaseDatabaseManager.shared.readData(from: "app_ios") { [weak self] value in
            guard let self else { return }
            self.handleFirebaseValue(value)
        }
    }
    
    // MARK: - 跑馬燈公告讀取
    func fetchMarqueeAnnouncement() {
        FirebaseDatabaseManager.shared.readData(from: "system/公告/跑馬燈") { [weak self] value in
            guard let self else { return }
            
            DispatchQueue.main.async {
                guard let dict = value as? [String: Any] else {
                    print("跑馬燈公告資料格式錯誤或不存在")
                    self.marqueeAnnouncement = .empty
                    return
                }
                
                let message = dict["Message"] as? String ?? ""
                
                let isOpen: Bool
                if let boolValue = dict["Open"] as? Bool {
                    isOpen = boolValue
                } else if let numberValue = dict["Open"] as? NSNumber {
                    isOpen = numberValue.boolValue
                } else {
                    isOpen = false
                }
                
                let isLoop: Bool
                if let boolValue = dict["Loop"] as? Bool {
                    isLoop = boolValue
                } else if let numberValue = dict["Loop"] as? NSNumber {
                    isLoop = numberValue.boolValue
                } else {
                    isLoop = false
                }

                self.marqueeAnnouncement = MarqueeAnnouncement(
                    message: message,
                    isOpen: isOpen,
                    isLoop: isLoop
                )
            }
        }
    }
    
    // MARK: - 強制提示讀取
    func fetchForceNotice() {
        versionManager.shouldIgnoreForceNotice { [weak self] shouldIgnore in
            guard let self else { return }
            guard !shouldIgnore else { return }

            self.loadForceNotice()
        }
    }

    private func loadForceNotice() {
        FirebaseDatabaseManager.shared.readData(from: "system/公告/強制提示") { [weak self] value in
            guard let self else { return }

            DispatchQueue.main.async {
                guard let dict = value as? [String: Any] else {
                    print("強制提示資料格式錯誤或不存在")
                    return
                }

                let title = dict["Title"] as? String ?? ""
                let message = dict["Message"] as? String ?? ""

                let isOpen: Bool
                if let boolValue = dict["Open"] as? Bool {
                    isOpen = boolValue
                } else if let numberValue = dict["Open"] as? NSNumber {
                    isOpen = numberValue.boolValue
                } else {
                    isOpen = false
                }

                guard isOpen else { return }

                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !cleanTitle.isEmpty || !cleanMessage.isEmpty else { return }
                
                // 觸發 forceNotice 前，先停止所有登入流程與成功狀態
                self.startSSOLoginProcess = false
                self.startMailLoginProcess = false
                self.ssoLoginSuccess = false
                self.mailLoginSuccess = false

                self.LoginActiveAlert = .forceNotice(
                    title: cleanTitle.isEmpty ? "提示" : cleanTitle,
                    message: cleanMessage
                )
            }
        }
    }

}


extension LoginViewModel {
    /// 回到 Login 畫面或準備新的登入嘗試時，先把流程狀態清掉
    func resetForFreshAttempt() {
        cancelLoginTimeout()

        showOverlay = false
        ssoLoginSuccess = false
        mailLoginSuccess = false
        loginFinishedToken = 0
        proceedToHomeToken = 0
        startSSOLoginProcess = false
        startMailLoginProcess = false
        LoginActiveAlert = nil
    }
    
    /// Firebase app 更新資料解析 + 決策
    func handleFirebaseValue(_ value: Any?) {
        guard
            let dict = value as? [String: Any],
            let useAppStore = dict["AppStore"] as? Bool,
            let downloadPage = dict["app下載頁面"] as? String
        else {
            return
        }
        if useAppStore {
            openAppStore()
        } else {
            openDownloadPage(downloadPage)
        }
    }
    
    func openAppStore() {
        openURL("https://apps.apple.com/tw/app/niu-%E5%AE%9C%E5%A4%A7%E5%AD%B8%E7%94%9Fapp/id6756336266")
    }

    func openDownloadPage(_ urlString: String) {
        openURL(urlString)
    }

    func openURL(_ urlString: String) {
        guard
            let url = URL(string: urlString),
            UIApplication.shared.canOpenURL(url)
        else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
