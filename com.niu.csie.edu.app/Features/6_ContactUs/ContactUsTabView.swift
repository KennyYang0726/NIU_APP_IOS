import SwiftUI



struct ContactUsTabView: View {
    
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ContactUsTabViewModel()
    // 使用 @StateObject 讓子頁面「持續存在」，達到在 init 預先載入效果
    // .onAppear 仍然不會觸發，需要真正滑到才會執行
    @StateObject private var tab1 = ContactUs_Tab1_ViewModel()
    @StateObject private var tab2 = ContactUs_Tab2_ViewModel()
    @Namespace private var animation
    @GestureState private var dragTranslation: CGFloat = 0
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        AppBar_Framework(title: "Contact_Us") {
            VStack(spacing: 0) {
                // 細黑線
                Rectangle()
                    .fill(Color.black.opacity(0.7)) // 淡黑色線條
                    .frame(height: 0.2)
                GeometryReader { geo in
                    let tabWidth = geo.size.width / CGFloat(viewModel.tabs.count)
                    
                    // Tab Bar
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(Array(viewModel.tabs.enumerated()), id: \.offset) { index, title in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        viewModel.selectTab(index: index)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(title)
                                            .font(isPad ? .title3 : .headline)
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(viewModel.selectedIndex == index ? .white : .gray)
                                    }
                                    .frame(width: tabWidth, height: isPad ? 55 : 44)
                                }
                            }
                        }
                        // 下劃線（等寬 + 可滑動）
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: isPad ? 5 : 3)
                            Rectangle()
                                .fill(Color("ColorPrimary"))
                                .frame(width: tabWidth, height: isPad ? 5 : 3)
                                .offset(x: underlineOffset(tabWidth: tabWidth, dragOffset: dragTranslation, width: geo.size.width))
                        }
                    }
                    .background(Color.accentColor)
                }
                .frame(height: isPad ? 59 : 46)
                .shadow(radius: 1)

                // Page View (左右滑動)
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let pages: [AnyView] = [
                        AnyView(ContactUs_Tab1_View(vm: tab1)),
                        AnyView(ContactUs_Tab2_View(vm: tab2))
                    ]
                    
                    HStack(spacing: 0) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            page.frame(width: width)
                        }
                    }
                    .offset(x: -CGFloat(viewModel.selectedIndex) * width + dragTranslation)
                    .gesture(
                        
                        DragGesture()
                            .updating($dragTranslation) { value, state, _ in
                                // 限制拖曳方向，避免出現黑畫面
                                let translation = value.translation.width
                                if (viewModel.selectedIndex == 0 && translation > 0) ||
                                    (viewModel.selectedIndex == viewModel.tabs.count - 1 && translation < 0) {
                                    // 到邊界時不再允許繼續滑
                                    state = 0
                                } else {
                                    state = translation
                                }
                            }
                            .onEnded { value in
                                let threshold = width / 2
                                var newIndex = viewModel.selectedIndex
                                if value.translation.width < -threshold {
                                    newIndex = min(newIndex + 1, viewModel.tabs.count - 1)
                                } else if value.translation.width > threshold {
                                    newIndex = max(newIndex - 1, 0)
                                }
                                viewModel.selectTab(index: newIndex)
                            }
                    )
                    .animation(.easeInOut(duration: 0.25), value: viewModel.selectedIndex)
                }
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
        }
    }

    // 計算滑動中下劃線位置（跟手勢同步）
    private func underlineOffset(tabWidth: CGFloat, dragOffset: CGFloat, width: CGFloat) -> CGFloat {
        // 當前 index 的基準位置
        let baseX = CGFloat(viewModel.selectedIndex) * tabWidth
        
        // 根據滑動距離轉換成 tab 移動比例
        let progress = dragOffset / width
        let interpolatedX = baseX - (progress * tabWidth)
        
        return interpolatedX
    }
}
