import SwiftUI



struct PortraitCanvas<Content: View>: View {
    private let content: Content
    var backgroundColor: Color

    init(
        backgroundColor: Color = .black,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let screenBounds = UIScreen.main.bounds
            let screenW = screenBounds.width
            let screenH = screenBounds.height

            // 用寬 > 高 判斷是否橫向
            let isLandscape = screenW > screenH

            ZStack {
                // 背景黑邊，只在橫向時「視覺上」才會看到
                backgroundColor
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if isLandscape {
                    // iPad 橫向：內容維持「直向寬度」，左右出現黑邊
                    let portraitWidth = screenH * (screenW / screenH > 1 ? screenH / screenW : 1)

                    content
                        .frame(width: screenH * 0.75, height: screenH)
                        .clipped()
                        .position(
                            x: geo.size.width / 2,
                            y: geo.size.height / 2
                        )
                } else {
                    // 直向：完全滿版
                    content
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        // 完全無視虛擬鍵盤
        .ignoresSafeArea(.keyboard)
    }
}
