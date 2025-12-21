//
//  Firebase、通知註冊，位置權限註冊
//
import UIKit
import SwiftUI
import Firebase
import FirebaseMessaging
import UserNotifications
import CoreLocation



final class PushDiag {
    static func log(_ msg: String) { print("🔎 [Push] \(msg)") }
}


class AppDelegate: NSObject,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate,
                   MessagingDelegate,
                   CLLocationManagerDelegate {

    private var locationManager: CLLocationManager?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        // 初始化 Firebase（讀取 GoogleService-Info.plist）
        FirebaseApp.configure()

        // 設定通知中心與 FCM 的 delegate
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // 要求授權（授權成功才註冊 APNs，避免時序問題）
        requestNotificationPermission(application: application)
        
        // 要求定位授權
        setupLocationManager()
        
        // 啟動時從 Firebase 讀取學期值，更新 AppSettings
        AppSettingsManager.shared.loadSemester()

        // 診斷：目前是否已註冊遠端通知（方便確認 registerForRemoteNotifications 是否有成功）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            PushDiag.log("isRegisteredForRemoteNotifications = \(application.isRegisteredForRemoteNotifications)")
        }

        return true
    }
    
    
    private func requestNotificationPermission(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                PushDiag.log("通知授權錯誤：\(error)")
                return
            }
            PushDiag.log("通知授權授與：\(granted)")

            // 有授權再註冊 APNs
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - 定位設定與授權
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        guard let manager = locationManager else { return }

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // iOS 14+ 新寫法（iOS16支援）
        let status = manager.authorizationStatus
        handleAuthorizationStatus(status)
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            PushDiag.log("首次要求位置授權")
            locationManager?.requestWhenInUseAuthorization()

        case .restricted:
            PushDiag.log("位置權限受限制（可能是家長控制）")

        case .denied:
            PushDiag.log("使用者拒絕位置權限，可引導至設定開啟")

        case .authorizedWhenInUse:
            PushDiag.log("位置權限：使用期間允許")
            // locationManager?.startUpdatingLocation()

        case .authorizedAlways:
            // 雖然你不用背景定位，但仍可能顯示這個狀態（例如使用者手動開啟）
            PushDiag.log("位置權限：永遠允許（但僅在前景使用）")
            // locationManager?.startUpdatingLocation()

        @unknown default:
            PushDiag.log("未知的授權狀態")
        }
    }

    /* 不需無時無刻取得定位
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        PushDiag.log("位置授權變更：\(status.rawValue)")
        handleAuthorizationStatus(status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            PushDiag.log("目前位置：\(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        PushDiag.log("定位錯誤：\(error.localizedDescription)")
    }*/
    
    // MARK: - APNs 註冊結果
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PushDiag.log("APNs Device Token：\(tokenString)")

        // 關鍵：把 APNs token 交給 FCM
        // 官方文件說明，若未設定 APNs token 即取得 FCM Token，該 FCM Token 無法透過 APNs 送達。:contentReference[oaicite:10]{index=10}
        Messaging.messaging().apnsToken = deviceToken

        // 在 APNs token 設定完成後，再主動抓一次 FCM Token（避免早於 APNs token 的時機取得到「無法送達」的 token）
        Messaging.messaging().token { token, error in
            if let error = error {
                PushDiag.log("取得 FCM Token 失敗（APNs 已設定後）：\(error)")
            } else if let token = token {
                PushDiag.log("FCM Token（主動，APNs OK）：\(token)")
            } else {
                PushDiag.log("FCM Token 為 nil（可能是免費簽名或網路狀況）")
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushDiag.log("註冊遠端通知失敗：\(error.localizedDescription)")
        #if targetEnvironment(simulator)
        PushDiag.log("（模擬器不支援推播，請用真機）")
        #endif
    }

    // MARK: - FCM Token 更新
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        
        guard let fcmToken = fcmToken else {
            PushDiag.log("FCM Token（delegate）為 nil")
            return
        }
        PushDiag.log("FCM Token（delegate）：\(fcmToken)")

        // 建議：如果未來要做「針對特定使用者推播」，可以在這裡把 token 上傳到自己的後端
        // 例如：AppServerAPI.shared.updatePushToken(fcmToken)
    }

    // MARK: - 前景通知呈現
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // App 在前景時也顯示 banner / 聲音 / badge
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - 使用者點擊通知（背景 / App 被滑掉 → 點通知回來）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        PushDiag.log("使用者點擊通知：\(userInfo)")

        // 這裡可以依 userInfo 做導頁或資料更新
        // 例如：NavigationManager.shared.handlePush(userInfo)

        completionHandler()
    }

    // MARK: - 點擊通知/背景抓取（處理 data-only 或導航）
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        PushDiag.log("收到遠端通知 payload：\(userInfo)")
        completionHandler(.newData)
    }
}

