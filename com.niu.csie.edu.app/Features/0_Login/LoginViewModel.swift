import Foundation
import SwiftUI
import Combine

/// MVVM: 負責「狀態」與「業務邏輯」

// MARK: - Alert 狀態枚舉
enum LoginAlert: Identifiable {
    // 基本登入
    case emptyFields
    case loginFailed
    // 發現新版本
    case newVersion(message: String)
    // === SSO 專用 ===
    case ssoCredentialsFailed(message: String)          // 帳密錯誤
    case ssoPasswordExpiring(message: String)           // 密碼即將到期（SweetAlert）
    case ssoPasswordExpired(message: String)            // 密碼已到期（SweetAlert）
    case ssoAccountLocked(lockTime: String?)            // 帳號鎖定
    case ssoSystemError                                 // error.html
    case ssoGeneric(title: String, message: String)     // 其他通用訊息

    var id: String {
        switch self {
        case .emptyFields: return "emptyFields"
        case .loginFailed: return "loginFailed"
        case .newVersion(let m): return m
        case .ssoCredentialsFailed(let m): return "ssoCredentialsFailed:\(m)"
        case .ssoPasswordExpiring(let m): return "ssoPasswordExpiring:\(m)"
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
    @Published var startZuvioLoginProcess = false
    @Published var startSSOLoginProcess = false

    @Published var zuvioLoginSuccess = false
    @Published var ssoLoginSuccess = false
    // 這個代表「兩邊流程都結束了」
    @Published var loginFinishedToken: Int = 0
    // 這個代表「已經允許導頁到 Home」才會觸發
    @Published var proceedToHomeToken: Int = 0

    // progress overlay
    @Published var showOverlay: Bool = false
    @Published var overlayText: LocalizedStringKey = "logining"
    
    // 密碼即將到期：需要使用者按「稍後再說」才可導頁
    private var waitingForPasswordExpiringDecision: Bool = false
    
    // MARK: - Network & Timeout
    private let loginTimeoutInterval: TimeInterval = 17
    private var loginTimeoutWorkItem: DispatchWorkItem?
    
    // MARK: - 衍生屬性
    var zuvioLoginEmail: String {
        let idPart = account.split(separator: "@").first ?? ""
        return "\(idPart)@ms.niu.edu.tw"
    }

    var loginAccount: String {
        return account.split(separator: "@").first.map(String.init) ?? ""
    }

    // MARK: - 動作事件
    func onTapLogin() {
        // 無網際網路
        guard NetworkMonitor.shared.isConnected else {
            LoginActiveAlert = .ssoGeneric(
                title: NSLocalizedString("No_Network_Title", comment: ""),
                message: NSLocalizedString("No_Network_Message", comment: "")
            )
            return
        }
        guard !account.isEmpty, !password.isEmpty else {
            LoginActiveAlert = .emptyFields
            return
        }
        showOverlay = true
        zuvioLoginSuccess = false
        ssoLoginSuccess = false
        startZuvioLoginProcess = true
        startSSOLoginProcess = true
        // 超時檢測開始
        startLoginTimeout()
    }

    func autoLogin() {
        // 無網際網路
        guard NetworkMonitor.shared.isConnected else {
            LoginActiveAlert = .ssoGeneric(
                title: NSLocalizedString("No_Network_Title", comment: ""),
                message: NSLocalizedString("No_Network_Message", comment: "")
            )
            return
        }
        if let saved = repository.loadCredentials() {
            account = saved.username
            password = saved.password
            showOverlay = true
            zuvioLoginSuccess = false
            ssoLoginSuccess = false
            startZuvioLoginProcess = true
            startSSOLoginProcess = true
            // 超時檢測開始
            startLoginTimeout()
        }
    }

    func handleZuvioLoginResult(_ success: Bool) {
        startZuvioLoginProcess = false
        zuvioLoginSuccess = success
        checkLoginResult()
    }

    func handleSSOLoginResult(_ result: SSOLoginResult) {
        switch result {
        case .success:
            startSSOLoginProcess = false
            ssoLoginSuccess = true
            checkLoginResult()
        case .credentialsFailed(let message):
            startSSOLoginProcess = false
            ssoLoginSuccess = false
            LoginActiveAlert = .ssoCredentialsFailed(message: message)
            checkLoginResult()
        case .passwordExpiring(let message):
            startSSOLoginProcess = false
            ssoLoginSuccess = true
            // 要卡住導頁，等使用者按「稍後再說」
            waitingForPasswordExpiringDecision = true
            LoginActiveAlert = .ssoPasswordExpiring(message: message)
            checkLoginResult()
        case .passwordExpired(let message):
            startSSOLoginProcess = false
            ssoLoginSuccess = false
            LoginActiveAlert = .ssoPasswordExpired(message: message)
            checkLoginResult()
        case .accountLocked(let lockTime):
            startSSOLoginProcess = false
            ssoLoginSuccess = false
            LoginActiveAlert = .ssoAccountLocked(lockTime: lockTime)
            checkLoginResult()
        case .systemError:
            startSSOLoginProcess = false
            ssoLoginSuccess = false
            LoginActiveAlert = .ssoSystemError
            checkLoginResult()
        case .generic(let title, let message):
            startSSOLoginProcess = false
            ssoLoginSuccess = false
            LoginActiveAlert = .ssoGeneric(title: title, message: message)
            checkLoginResult()
        }
    }

    private func checkLoginResult() {
        // 當兩邊都完成才收斂
        guard !startZuvioLoginProcess, !startSSOLoginProcess else { return }
        // 超時檢測結束
        loginTimeoutWorkItem?.cancel()
        loginTimeoutWorkItem = nil
        // UI 收斂
        showOverlay = false
        // 這裡代表「本次登入嘗試已完成」
        loginFinishedToken += 1

        let allSuccess = (zuvioLoginSuccess && ssoLoginSuccess)
        if allSuccess {
            // 成功才存帳密
            repository.saveCredentials(username: account.uppercased(), password: password)
            // 如果正在等「密碼即將到期」使用者選擇，就先不要導頁
            if !waitingForPasswordExpiringDecision {
                proceedToHomeToken += 1
            }
        } else {
            // 只有「帳密錯誤」或「密碼已到期（強制）」才清帳密
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
        default:
            return false
        }
    }

    func togglePasswordVisible() {
        isPasswordVisible.toggle()
    }
    
    // MARK: - 密碼即將到期-稍後再說
    func userChoseLaterForPasswordExpiring() {
        waitingForPasswordExpiringDecision = false

        // 只有在兩邊都已成功時，才觸發導頁
        if zuvioLoginSuccess && ssoLoginSuccess {
            proceedToHomeToken += 1
        }
    }

    // MARK: - 開啟修改密碼頁
    func openSSOPasswordChange() {
        guard let url = URL(string: "https://ccsys.niu.edu.tw/SSO/Teac_Secret.aspx") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
            if self.startZuvioLoginProcess || self.startSSOLoginProcess {

                let zuvioPending = self.startZuvioLoginProcess
                let ssoPending = self.startSSOLoginProcess

                self.startZuvioLoginProcess = false
                self.startSSOLoginProcess = false
                self.showOverlay = false
                self.loginFinishedToken += 1

                // 根據卡住的來源顯示不同訊息
                if zuvioPending && ssoPending {
                    self.LoginActiveAlert = .loginFailed
                } else if zuvioPending {
                    self.LoginActiveAlert = .ssoGeneric(
                        title: NSLocalizedString("Dialog_Timeout_Title", comment: ""),
                        message: NSLocalizedString("Dialog_Zuvio_Timeout_Message", comment: "")
                    )
                } else if ssoPending {
                    self.LoginActiveAlert = .ssoGeneric(
                        title: NSLocalizedString("Dialog_Timeout_Title", comment: ""),
                        message: NSLocalizedString("Dialog_SSO_Timeout_Message", comment: "")
                    )
                }
            }
        }

        loginTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + loginTimeoutInterval, execute: workItem)
    }
    
    //
    func handleUpdateAction() {
        FirebaseDatabaseManager.shared.readData(from: "app_ios") { [weak self] value in
            guard let self else { return }
            self.handleFirebaseValue(value)
        }
    }

}

extension LoginViewModel {
    /// 回到 Login 畫面或準備新的登入嘗試時，先把流程狀態清掉
    func resetForFreshAttempt() {
        showOverlay = false
        zuvioLoginSuccess = false
        ssoLoginSuccess = false
        loginFinishedToken = 0
        proceedToHomeToken = 0
        waitingForPasswordExpiringDecision = false
        startZuvioLoginProcess = false
        startSSOLoginProcess = false
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

