import SwiftUI



struct ProgressOverlay: View {
    @Binding var isVisible: Bool
    var text: LocalizedStringKey

    var body: some View {
        if isVisible {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)  // 防止點擊穿透

                VStack(spacing: 10) {
                    // 使用 TimelineView 讓圖示持續旋轉
                    TimelineView(.animation) { timeline in
                        let duration: Double = 1.2
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let angle = (now.truncatingRemainder(dividingBy: duration)) / duration * 360
                        
                        Image("AppIcon_Round")
                            .resizable()
                            .frame(width: 67, height: 67)
                            .rotationEffect(.degrees(angle))
                    }

                    Text(text)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .transition(.opacity)
        }
    }
}
