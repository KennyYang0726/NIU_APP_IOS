import Foundation


// 不同檔案要呼叫對方的 func，可以使用這個通知廣播
extension Notification.Name {
    static let didSubmitEventRegistration = Notification.Name("didSubmitEventRegistration")
    static let didChangeEventRegistration = Notification.Name("didChangeEventRegistration")
}
