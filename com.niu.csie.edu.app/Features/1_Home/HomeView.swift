import SwiftUI

// MARK: - 資料模型
struct HomeFeature: Identifiable {
    let id = UUID()
    let KeyIndex: Int              // 用來程式判斷 (case 不能用 localize 字串)
    let title: LocalizedStringKey  // UI 顯示 (可本地化)
    let iconName: String
    let isSystemIcon: Bool
}

let defaultFeatures: [HomeFeature] = [
    .init(KeyIndex: 0, title: "EUNI", iconName: "\u{e809}", isSystemIcon: false),
    .init(KeyIndex: 1, title: "Score_Inquiry", iconName: "\u{e801}", isSystemIcon: false),
    .init(KeyIndex: 2, title: "Class_Schedule", iconName: "\u{e803}", isSystemIcon: false),
    .init(KeyIndex: 3, title: "Event_Registration", iconName: "\u{e80a}", isSystemIcon: false),
    .init(KeyIndex: 4, title: "Contact_Us", iconName: "\u{e800}", isSystemIcon: false),
    .init(KeyIndex: 5, title: "Graduation_Threshold", iconName: "\u{e802}", isSystemIcon: false),
    .init(KeyIndex: 6, title: "Subject_System", iconName: "\u{e807}", isSystemIcon: false),
    .init(KeyIndex: 7, title: "Bus", iconName: "\u{e806}", isSystemIcon: false),
    .init(KeyIndex: 8, title: "Zuvio",  iconName: "\u{e804}", isSystemIcon: false),
    // 用 SF Symbols
    .init(KeyIndex: 9, title: "Take_Leave", iconName: "person.fill.xmark", isSystemIcon: true)
    // .init(KeyIndex: 10, title: "Mail",  iconName: "\u{e808}", isSystemIcon: false)
]


// MARK: - HomeView
struct HomeView: View {
    @StateObject private var vm: HomeViewModel
    //@StateObject private var vm = HomeViewModel(appSettings: AppSettings)
    @ObservedObject var drawerVM: DrawerManagerViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @EnvironmentObject var appState: AppState // 注入狀態
    @EnvironmentObject var appSettings: AppSettings // 注入狀態
    @EnvironmentObject var session: SessionManager // 執行 js 取得 ssoid
    @StateObject private var keepAlive = SSOKeepAliveService() // 當畫面在主頁時，keep-alive，他會呼叫 SessionManager
    
    @State private var didRunCheckOnce = false // 檢查 onReceive 匿名登入完成
    @State private var isLeavingHome = false // 檢查是否為離開 View，
                                             // 無論登出 or 進入其他功能
    
    private let loginStreak = LoginStreakManager()
    private let loginStreakBright = LoginStreakManagerBright()
    
    private let title = NSLocalizedString("HomePage", comment: "")
    // 固定三欄
    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 20),
         GridItem(.flexible(), spacing: 20),
         GridItem(.flexible(), spacing: 20)]
    }
    
    // 在 init 中建立 ViewModel 並注入 appSettings
    init(drawerVM: DrawerManagerViewModel, appSettings: AppSettings = AppSettings()) {
        self._vm = StateObject(wrappedValue: HomeViewModel(appSettings: appSettings))
        self.drawerVM = drawerVM
    }

    var body: some View {
        ZStack {
            // 背景色
            Color("Linear")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ScrollView 內容
                ScrollView {
                    VStack(spacing: 32) {
                        LazyVGrid(columns: columns,
                                  alignment: .center,
                                  spacing: hSizeClass == .regular ? 28 : 20) {
                            ForEach(defaultFeatures) { feature in
                                FeatureItemView(feature: feature,
                                                isPad: hSizeClass == .regular)
                                .contentShape(Rectangle())
                                // 新增點擊事件
                                .onTapGesture {
                                    if let route = route(for: feature.KeyIndex) {
                                        appState.navigate(to: route)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // 這裡放一個 Spacer，佔據和底圖一樣的高度
                        GeometryReader { proxy in
                            Color.clear
                                .frame(height: proxy.size.height)
                        }
                        .frame(height: 0) // 不要影響 ScrollView 高度

                    }
                }
                // 底部圖片
                Image("NIU_background")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, hSizeClass == .regular ? -67 : -37) // 負數往下推
            }
        }
        // 登出中 prog (注意！放在這裡才是全版面)
        .overlay(
            ProgressOverlay(isVisible: $vm.showOverlay, text: vm.overlayText)
            // Toast 若觸發夜市
            .toast(isPresented: $vm.showMatchedSpotToast) {
                Text(vm.matchedSpotToastText)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
            }
            .offset(y: -59)
        )
        .onAppear {
            // 先第一次取得，接下來若持續閒置，由 keepAlive 負責
            session.refreshSSOID()
            keepAlive.start(with: session)
            // 紀錄連續登入天數
            loginStreak.onLogin()
            loginStreakBright.onLogin()
            // 取得定位(夜市星人)
            vm.CheckIfInNightMarket()
        }
        // onResume，怕有人回前景但session過期
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        )) { _ in
            session.refreshSSOID()
        }
        .onDisappear {
            keepAlive.stop()
        }
        // 登入階段過期，重新登入提示
        .alert(LocalizedStringKey("Dialog_Error_Title"), isPresented: $session.ssoDataInvalid) {
            Button(LocalizedStringKey("Dialog_OK")) {
                session.ssoDataInvalid = false
                appState.navigate(to: .login)
            }
        } message: {
            Text(LocalizedStringKey("SSO_LoginSessionInvalidHint"))
        }
        .interactiveDismissDisabled() // 禁止點背景取消
    }

    // 把 Home 的標題字串對應到 AppRoute
    private func route(for keyIndex: Int) -> AppRoute? {
        switch keyIndex {
        case 0:     return .EUNI
        case 1:     return .Score_Inquiry
        case 2:     return .Class_Schedule
        case 3:     return .Event_Registration
        case 4:     return .Contact_Us
        case 5:     return .Graduation_Threshold
        case 6:     return .Subject_System
        case 7:     return .Bus
        case 8:     return .ZUVIO
        case 9:     return .Take_Leave
        case 10:    return .Mail
        default:    return nil
        }
    }
}

// MARK: - 功能 Item
private struct FeatureItemView: View {
    let feature: HomeFeature
    let isPad: Bool

    var body: some View {
        VStack(spacing: isPad ? 12 : 8) {
            ZStack {
                Circle()
                    .strokeBorder(Color("HomeItemCircle"), lineWidth: isPad ? 3 : 2)
                    .frame(width: isPad ? 110 : 70, height: isPad ? 110 : 70)
                // 若是系統圖片
                if feature.isSystemIcon {
                    // 內建 SF Symbols
                    Image(systemName: feature.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isPad ? 55 : 28, height: isPad ? 55 : 31)
                        .foregroundStyle(.primary)
                } else {
                    // TTF 自訂圖示
                        Text(feature.iconName) // 這裡使用 Text
                            .font(.custom("MyFlutterApp", size: isPad ? 61 : 37))
                            .foregroundStyle(.primary)
                }
            }

            Text(feature.title)
                .font(.system(size: isPad ? 29 : 17, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, minHeight: isPad ? 160 : 110)
        .contentShape(Rectangle())
        .padding(.vertical, isPad ? 10 : 6)
    }
}


// MARK: - 預覽
#Preview {
    HomeView(drawerVM: DrawerManagerViewModel(), appSettings: AppSettings())
}

