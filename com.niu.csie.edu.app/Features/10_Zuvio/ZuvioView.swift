import SwiftUI



struct ZuvioView: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var vm = ZuvioViewModel()
    
    var body: some View {
        AppBar_Framework(title: "Zuvio") {
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
                        if vm.webProvider.webView.canGoBack {
                            vm.webProvider.goBack()
                            return true    // 攔截 pop
                        } else {
                            appState.navigate(to: .home)
                            return false   // 放行 pop（或你直接 navigate）
                        }
                    }
                )
            )
            .onAppear {
                // 初始化狀態
                vm.initializeState()
                vm.colorScheme = colorScheme
            }
        }
    }
}
