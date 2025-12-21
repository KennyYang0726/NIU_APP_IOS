import SwiftUI



struct ClassScheduleView: View {
    
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var vm = ClassScheduleViewModel()
    
    var body: some View {
        AppBar_Framework(title: "Class_Schedule") {
            ZStack {
                WebViewContainer(webView: vm.webProvider.webView)
                    .opacity(vm.isWebVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: vm.isWebVisible)
                    .ignoresSafeArea(edges: .bottom)
                
                ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
            }
            // 返回手勢攔截
            .background(
                NavigationSwipeHijacker(
                    handleSwipe: {
                        appState.navigate(to: .home)
                        return false   // 放行 pop（或你直接 navigate）
                    }
                )
            )
            .onAppear {
                // 初始化狀態
                vm.InitialSettings()
                vm.colorScheme = colorScheme
            }
        }
    }
}
