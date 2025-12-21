import SwiftUI



struct EUNI2View: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var vm = EUNI2ViewModel()
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        NavigationStack {
            ZStack {
                // --- WebView ---
                WebViewContainer(webView: vm.webProvider.webView)
                    .opacity(vm.isWebVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: vm.isWebVisible)
                    .ignoresSafeArea(edges: .bottom)
                // --- 這裡啥都沒有 ---
                if vm.showNone {
                    VStack {
                        Text(LocalizedStringKey("ThisCourseDoesNotHaveAny"))
                            .font(.system(size: isPad ? 43 : 23))
                            .foregroundColor(.primary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color("Linear").ignoresSafeArea())  // 與主背景一致
                }
                ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
            }
            // title 使用從 EUNI1 傳入的 fullTitle
            .navigationTitle(EUNI2LaunchConfig.fullTitle)
            .navigationBarTitleDisplayMode(.inline)

            // NavigationBar 樣式完全比照 AppBar_Framework
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.accentColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

            // 返回按鈕（跳回 EUNI 而不是 home）
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.navigate(to: .EUNI)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(LocalizedStringKey("back"))
                        }
                        .foregroundStyle(.white) // simulator 17.x, 18.x 不加入會不顯示圖標文字
                    }
                }
            }
            // 返回手勢攔截
            .background(
                NavigationSwipeHijacker(
                    handleSwipe: {
                        if vm.webProvider.webView.canGoBack {
                            vm.webProvider.goBack()
                            return true    // 攔截 pop
                        } else {
                            appState.navigate(to: .EUNI)
                            return false   // 放行 pop（或你直接 navigate）
                        }
                    }
                )
            )
        }
        .onAppear {
            vm.initializeState()
            vm.colorScheme = colorScheme
        }
    }
}
