//  com_niu_csie_edu_appApp.swift
//  指定 app 進入點
//  新版寫法，有漸變切換主題效果
import SwiftUI



@main
struct com_niu_csie_edu_appApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings()
    @StateObject private var session  = SessionManager()
    @StateObject private var drawerVM = DrawerManagerViewModel()   // 避免抽屜在切換主題是被重建，因為重建後的init頁面是主頁
    
    var body: some Scene {
        let scheme = currentSwiftUIColorScheme()
        
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(appState)
                .environmentObject(session)
                .environmentObject(drawerVM)
                .applyIf(scheme != nil) { view in
                    view.environment(\.colorScheme, scheme!)
                }
                // 不再用 preferredColorScheme 來控制主題，改由 UIKit 管
                .onAppear {
                    // 啟動時套一次目前主題（不動畫）
                    applyTheme(animated: false)
                    // App 啟動後先執行匿名登入
                    FirebaseAuthManager.shared.signInAnonymously()
                }
                .onChange(of: settings.theme) { _ in
                    // 之後每次改 theme 都用淡入淡出
                    applyTheme(animated: true)
                    // 這行讓 SwiftUI 重新讀 environment（特別是 iOS 16，已知bug）
                    DispatchQueue.main.async {
                        settings.objectWillChange.send()
                    }
                }
        }
    }
    
    // MARK: - 把 AppTheme 轉成 UIKit 的 UIUserInterfaceStyle
    private func uiStyle(for theme: AppTheme) -> UIUserInterfaceStyle {
        switch theme {
        case .default:
            return .unspecified   // 跟隨系統
        case .bright:
            return .light
        case .dark:
            return .dark
        }
    }
    
    // MARK: - 套用主題（可以選擇要不要動畫）
    private func applyTheme(animated: Bool) {
        guard let windowScene = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.windows.first
        else { return }
        
        let style = uiStyle(for: settings.theme)
        
        if animated {
            UIView.transition(
                with: window,
                duration: 0.35,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: {
                    window.overrideUserInterfaceStyle = style
                },
                completion: nil
            )
        } else {
            window.overrideUserInterfaceStyle = style
        }
    }
    
    // ios 16 已知 bug (新添加的)
    private func currentSwiftUIColorScheme() -> ColorScheme? {
        guard let style = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first?
            .overrideUserInterfaceStyle else { return nil }
        
        switch style {
        case .dark: return .dark
        case .light: return .light
        default: return nil // 跟隨系統
        }
    }

}


extension View {
    @ViewBuilder
    func applyIf(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


/*
舊版寫法，會瞬間應用切換主題
@main
struct com_niu_csie_edu_appApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var session = SessionManager()

    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(session)
                .preferredColorScheme(resolveColorScheme(settings.theme)) // 即時反映設定改變
                .onAppear {
                    // App 啟動後先執行匿名登入
                    FirebaseAuthManager.shared.signInAnonymously()
                }
        }
    }
    
    // 傳遞當前設置的主題色
    private func resolveColorScheme(_ theme: AppTheme) -> ColorScheme? {
        switch theme {
            case .default:
                return nil
            case .bright:
                return .light
            case .dark:
                return .dark
        }
    }
}
*/
