import SwiftUI


// 共用 主畫面 各個功能 appbar
struct AppBar_Framework<Content: View>: View {
    @EnvironmentObject var appState: AppState
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                //.padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline) // 小標題樣式
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color.accentColor, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            appState.navigate(to: .home)
                        } label: {
                            HStack() {
                                Image(systemName: "chevron.left")
                                Text(LocalizedStringKey("back"))
                            }
                            .foregroundStyle(.white) // simulator 17.x, 18.x 不加入會不顯示圖標文字
                        }
                    }
                }
        }
    }
}
