import Foundation



final class VersionManager {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// 回傳：true = 可以繼續進首頁，false = 被新版本擋下
    func checkNewVersion(
        onResult: @escaping (_ canProceed: Bool, _ remoteVersion: String?) -> Void
    ) {
        FirebaseDatabaseManager.shared.readData(from: "app_ios/ver") { value in
            guard let remoteVersion = value as? String else {
                onResult(true, nil)
                return
            }

            if remoteVersion != self.appVersion {
                onResult(false, remoteVersion)
            } else {
                onResult(true, nil)
            }
        }
    }
}


