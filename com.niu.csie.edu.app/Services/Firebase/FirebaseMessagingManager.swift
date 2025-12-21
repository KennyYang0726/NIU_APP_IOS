import Foundation
import UserNotifications



final class FirebaseMessagingManager {
    static let shared = FirebaseMessagingManager()

    private init() {}

    /// 查詢目前通知授權狀態
    func getNotificationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    /// 重新要求通知授權（但不註冊遠端通知）
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("重新要求通知授權錯誤：\(error.localizedDescription)")
                completion?(false)
                return
            }
            print("重新要求通知授權結果：\(granted)")
            completion?(granted)
        }
    }

    /// （可選）開一個便利方法讓 UI 讀取目前狀態描述字串
    func describeStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未詢問"
        case .denied: return "已拒絕"
        case .authorized: return "已授權"
        case .provisional: return "暫時授權"
        case .ephemeral: return "臨時授權（App Clip）"
        @unknown default: return "未知狀態"
        }
    }
}
