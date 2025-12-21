import SwiftUI

struct Drawer_Huh2View: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject var vm: Drawer_Huh2ViewModel
    
    let title: LocalizedStringKey
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    init(title: LocalizedStringKey, feature: HuhFeature) {
        self.title = title
        _vm = StateObject(wrappedValue: Drawer_Huh2ViewModel(feature: feature))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TabView {
                    ForEach(vm.pages) { page in
                        VStack(spacing: 20) {
                            // 標題
                            Text(page.title)
                                .font(.system(size: isPad ? 59 : 37).bold())
                                .foregroundColor(.primary)
                                .padding(.horizontal, 22)
                                .padding(.top, isPad ? 31 : 23)
                            // 非滿版圖片
                            Image(page.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: isPad ? 500 : 300)
                                .padding(.top, 20)
                            // 說明文字
                            Text(page.description)
                                .font(.system(size: isPad ? 29 : 19))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 29)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tabViewStyle(.page)
                .onAppear {
                    if colorScheme == .light {
                        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.darkGray
                        UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray3
                    } else {
                        // 暗色模式使用原樣
                        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.white
                        UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray
                    }
                }

            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // NavigationBar 樣式完全比照 AppBar_Framework
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.accentColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // 隱藏預設返回按鈕
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            if isPad {
                                Text(LocalizedStringKey("back")) // iPad 顯示文字
                            }
                        }
                    }
                    .foregroundColor(.white) // 可依需求調整顏色
                }
            }
            // 返回手勢攔截
            .background(
                NavigationSwipeHijacker(
                    handleSwipe: {
                        dismiss()
                        return true     // 我已經處理，系統不要再 pop
                    }
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea())
    }
}
