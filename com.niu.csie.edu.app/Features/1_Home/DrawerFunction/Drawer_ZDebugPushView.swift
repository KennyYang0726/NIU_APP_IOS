/// Debug View
import FirebaseMessaging
import SwiftUI


/// 1_Home/Drawer/DrawerManagerView 暫時替換一個
struct Drawer_ZDebugPushView: View {
    
    @State private var fcmToken: String = "（尚未取得）"
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRegistered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("推播診斷面板").font(.title).bold()

            Button("重新要求通知授權") {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                    refresh()
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }

            Button("送一顆本地通知（3 秒後）") {
                let content = UNMutableNotificationContent()
                content.title = "本地通知測試"
                content.body = "這是用來模擬推播呈現流程"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
                let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
            }

            Button("抓 FCM Token") {
                Messaging.messaging().token { token, error in
                    if let token = token {
                        fcmToken = token
                    } else {
                        fcmToken = "nil（免費簽名時常見；即使有值也無法收 APNs）"
                    }
                }
            }
            
            Button("重新要求通知授權") {
                FirebaseMessagingManager.shared.requestAuthorization { granted in
                    print("使用者重新授權結果：\(granted)")
                }
            }

            Button("查詢授權狀態") {
                FirebaseMessagingManager.shared.getNotificationStatus { status in
                    print("目前通知授權狀態：\(FirebaseMessagingManager.shared.describeStatus(status))")
                }
            }

            Divider()

            Text("授權狀態：\(desc(of: authStatus))")
            Text("isRegisteredForRemoteNotifications：\(isRegistered.description)")
            Text("FCM Token：\(fcmToken)")
                .lineLimit(5)
                .textSelection(.enabled)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea()) // 全域底色
        .onAppear { refresh() }
    }

    private func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authStatus = settings.authorizationStatus
                self.isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
            }
        }
        Messaging.messaging().token { token, _ in
            DispatchQueue.main.async {
                self.fcmToken = token ?? "nil"
            }
        }
    }

    private func desc(of status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未詢問"
        case .denied: return "拒絕"
        case .authorized: return "允許"
        case .provisional: return "暫時授權"
        case .ephemeral: return "臨時授權（App Clip）"
        @unknown default: return "未知"
        }
    }
}
