import Foundation



final class VersionManager {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// 將 "26.08.26" 轉成 260826
    private func versionNumber(from version: String) -> Int? {
        Int(version.replacingOccurrences(of: ".", with: ""))
    }

    /// 回傳：true = 可以繼續進首頁，false = 被新版本擋下
    func checkNewVersion(
        onResult: @escaping (_ canProceed: Bool, _ remoteVersion: String?) -> Void
    ) {
        FirebaseDatabaseManager.shared.readData(from: "app_ios/ver") { value in
            guard
                let remoteVersion = value as? String,
                let appVersionNumber = self.versionNumber(from: self.appVersion),
                let remoteVersionNumber = self.versionNumber(from: remoteVersion)
            else {
                onResult(true, nil)
                return
            }

            if appVersionNumber < remoteVersionNumber {
                onResult(false, remoteVersion)
            } else {
                onResult(true, nil)
            }
        }
    }
}
