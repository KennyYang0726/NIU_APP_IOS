// AppState.swift
import SwiftUI



enum NavigationAnimation {
    case slideLeft   // 右→左
    case slideRight  // 左→右
}

enum AppRoute {
    case login
    case home
    //case huh2
    // Home 的功能頁
    case EUNI                 // M園區
    case EUNI2                // M園區-畫面
    case Score_Inquiry        // 成績查詢
    case Class_Schedule       // 我的課表
    case Event_Registration   // 活動報名
    case Contact_Us           // 聯絡我們
    case Graduation_Threshold // 畢業門檻
    case Subject_System       // 選課系統
    case Bus                  // 公車動態
    case ZUVIO                // ZUVIO
    case Take_Leave           // 請假系統
    case Mail                 // 校園信箱
}

class AppState: ObservableObject {
    @Published var route: AppRoute = .login // 設定初始畫面為 login
    @Published var toastMessage: LocalizedStringKey? = nil
    @Published var navAnimation: NavigationAnimation = .slideLeft
        
    func navigate(to route: AppRoute, withToast message: LocalizedStringKey? = nil) {
        if let msg = message {
            toastMessage = msg // 跳頁 + show Toast
        }
        let current = self.route   // 目前所在頁面
        let target  = route        // 要去的頁面
        // 決定動畫
        switch (current, target) {
        case (.login, .home):
            // login → home 要左滑
            navAnimation = .slideLeft
        case (_, .home):
            // 其他頁 → home 右滑
            navAnimation = .slideRight
        case (.EUNI2, .EUNI):
            // EUNI2 → EUNI 右滑
            navAnimation = .slideRight
        case (_, .login):
            // 回 login 右滑
            navAnimation = .slideRight
        default:
            // 其餘正常左滑
            navAnimation = .slideLeft
        }
        // 用於 NavigationStack 的話，要先把 navAnimation 設好再切 route
        withAnimation(.easeInOut(duration: 0.32)) {
            self.route = route // 提供簡單的跳頁方法
        }
    }
}
