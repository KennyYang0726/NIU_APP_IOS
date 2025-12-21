import SwiftUI



struct DrawerView: View {
    @ObservedObject var vm: DrawerManagerViewModel
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: SessionManager
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(settings.name)
                .font(isPad ? .title : .title3)  // iPad 放大字體
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, isPad ? 24 : 16)
                .padding(.vertical, isPad ? 20 : 14)
            
            Divider().background(Color.white.opacity(0.8)) // 分隔線 白色半透明
            
            VStack(alignment: .leading, spacing: isPad ? 28 : 20) {
                drawerItem(icon: "house", title: "HomePage", page: .home)
                drawerItem(icon: "megaphone.fill", title: "Announcement", page: .announcements)
                drawerItem(icon: "calendar", title: "Calendar", page: .calendar)
                drawerItem(icon: "doc.text.fill", title: "Questionnaire", page: .questionnaire)
                drawerItem(icon: "trophy.fill", title: "Achievements", page: .achievements)
                drawerItem(icon: "questionmark.circle", title: "huh", page: .huh)
                drawerItem(icon: "info.circle", title: "About", page: .about)
                drawerItem(icon: "gearshape.fill", title: "Settings", page: .settings)
                drawerItem(icon: "rectangle.portrait.and.arrow.forward", title: "Logout", page: .logout)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, isPad ? 24 : 16)
            .padding(.top, isPad ? 28 : 20)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.accentColor)
        .padding(.top, 0)
    }
    
    private func drawerItem(icon: String, title: LocalizedStringKey, page: DrawerPageCase) -> some View {
        HStack(spacing: isPad ? 16 : 12) {
            Image(systemName: icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: isPad ? 39 : 25, height: isPad ? 39 : 25) // iPad 放大圖示
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: isPad ? 27 : 19, weight: .medium))  // iPad 放大字體
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, isPad ? 12 : 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if page == .logout {
                session.logout(appState: appState,
                               appSettings: settings,
                               loginRepo: LoginRepository()) // 無需執行跳頁
            } else {
                vm.switchPage(to: page)
            }
        }
    }
}
