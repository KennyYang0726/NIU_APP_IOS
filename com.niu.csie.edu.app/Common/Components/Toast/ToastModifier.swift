import SwiftUI



extension View {
    func toast<Content: View>(
        isPresented: Binding<Bool>,
        duration: Double = 2,   // 可調整顯示秒數
        bottomPadding: CGFloat = 50, // 距離螢幕下緣的距離
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                VStack {
                    Spacer()
                    content()
                        .padding(.horizontal, 16)   // 左右留白
                        .padding(.bottom, bottomPadding) // 往上推一點
                        .onAppear {
                            // 自動隱藏
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isPresented.wrappedValue = false
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity)) // 從下方滑入 + 淡入淡出
                        .animation(.easeInOut, value: isPresented.wrappedValue)
                }
            }
        }
    }
}
