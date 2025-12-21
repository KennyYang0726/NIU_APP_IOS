import SwiftUI



struct DrawerManagerView: View {
    @EnvironmentObject var vm: DrawerManagerViewModel
    @EnvironmentObject var appState: AppState // 注入狀態
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var drawerWidth: CGFloat { isPad ? 320 : 200 } // iPad 寬一點

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    currentPageView(vm.currentPage)
                    // 遮罩：跟著透明度變化
                    Color.black.opacity(vm.isDrawerOpen ? 0.3 : 0.0)
                        .ignoresSafeArea()
                        .allowsHitTesting(vm.isDrawerOpen)
                        .onTapGesture { vm.closeDrawer() }
                        .animation(.easeInOut(duration: 0.25), value: vm.isDrawerOpen)
                        .zIndex(1)

                    // 抽屜：始終在樹上，靠 offset 做開合
                    HStack(spacing: 0) {
                        DrawerView(vm: vm)
                            .frame(width: drawerWidth)
                            .offset(x: vm.isDrawerOpen ? 0 : -drawerWidth)
                            .animation(.easeInOut(duration: 0.25), value: vm.isDrawerOpen)
                        Spacer()
                    }
                    .zIndex(2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { vm.toggleDrawer() }) {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                            .foregroundStyle(.white) // simulator 17.x, 18.x 不加入會不顯示圖標文字
                    }
                }
            }
            .navigationTitle(vm.currentPage.title) // 動態顯示標題
            .toolbarBackground(.visible, for: .navigationBar) // 強制背景顯示
            .toolbarBackground(Color.accentColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline) // 固定使用小標題樣式
        }
    }

    // 用 function 統一管理頁面
    @ViewBuilder
    private func currentPageView(_ page: DrawerPageCase) -> some View {
        switch page {
        case .home: HomeView(drawerVM: vm)
        case .announcements: Drawer_AnnouncementsView()
        case .calendar: Drawer_CalendarView()
        case .questionnaire: Drawer_QuestionnaireView()
        case .achievements: Drawer_AchievementsView()
        case .huh: Drawer_Huh1View()
        case .about: Drawer_AboutView()
        case .settings: Drawer_SettingsView()
        case .logout: Drawer_LogoutView()
        }
    }
}
