import Foundation



final class VersionManager {

    private struct VersionComparison {
        let isValid: Bool
        let isCurrentAtLeastRemote: Bool
        let isCurrentNewerThanRemote: Bool
        let remoteVersion: String?
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// 將 "26.08.26" 轉成 260826
    private func versionNumber(from version: String?) -> Int? {
        guard let version else { return nil }
        return Int(version.replacingOccurrences(of: ".", with: ""))
    }

    /// 回傳：true = 可以繼續進首頁，false = 被新版本擋下
    func checkNewVersion(
        onResult: @escaping (_ canProceed: Bool, _ remoteVersion: String?) -> Void
    ) {
        readVersionComparison { result in
            if !result.isValid || result.isCurrentAtLeastRemote {
                onResult(true, nil)
                return
            }

            onResult(false, result.remoteVersion)
        }
    }

    /// 判斷目前版本是否高於 Firebase 指定版本。
    ///
    /// 僅在版本資料可正確解析，且目前版本 > Firebase 版本時回傳 true。
    /// 讀取或解析失敗時回傳 false，避免誤略過強制提示。
    func shouldIgnoreForceNotice(
        onResult: @escaping (_ shouldIgnore: Bool) -> Void
    ) {
        readVersionComparison { result in
            onResult(result.isValid && result.isCurrentNewerThanRemote)
        }
    }

    /// 統一讀取並比較目前版本與 Firebase 版本。
    private func readVersionComparison(
        onResult: @escaping (VersionComparison) -> Void
    ) {
        FirebaseDatabaseManager.shared.readData(from: "app_ios/ver") { value in
            let remoteVersion = value as? String
            let appVersionNumber = self.versionNumber(from: self.appVersion)
            let remoteVersionNumber = self.versionNumber(from: remoteVersion)

            let isValid = appVersionNumber != nil && remoteVersionNumber != nil
            let isCurrentAtLeastRemote: Bool
            let isCurrentNewerThanRemote: Bool

            if let appVersionNumber, let remoteVersionNumber {
                isCurrentAtLeastRemote = appVersionNumber >= remoteVersionNumber
                isCurrentNewerThanRemote = appVersionNumber > remoteVersionNumber
            } else {
                isCurrentAtLeastRemote = false
                isCurrentNewerThanRemote = false
            }

            onResult(
                VersionComparison(
                    isValid: isValid,
                    isCurrentAtLeastRemote: isCurrentAtLeastRemote,
                    isCurrentNewerThanRemote: isCurrentNewerThanRemote,
                    remoteVersion: remoteVersion
                )
            )
        }
    }
}
