import SwiftUI



struct MailView: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var vm = MailViewModel()
    
    public var body: some View {
        AppBar_Framework(title: "Mail") {
            ZStack {
                WebViewContainer(webView: vm.webProvider.webView)
                    .opacity(vm.isWebVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: vm.isWebVisible)
                    .ignoresSafeArea(edges: .bottom)
                ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
            }
            // 返回手勢攔截 + 補登入網頁
            .background(
                ZStack {
                    // 返回手勢攔截
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
                    // 補登入網頁
                    if vm.startMailLoginProcess {
                        MailLoginWebView(
                            account: vm.loginAccount,
                            password: vm.password
                        ) { success in
                            vm.handleMailLoginResult(success)
                        }
                        .frame(width: 1, height: 1)
                        .opacity(0)
                        .allowsHitTesting(false)
                    }
                }
            )
            .onAppear {
                vm.InitialSettings()
                vm.colorScheme = colorScheme
            }
        }
    }
}
