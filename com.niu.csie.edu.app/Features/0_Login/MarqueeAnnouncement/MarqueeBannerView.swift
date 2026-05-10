import SwiftUI



struct MarqueeBannerView: View {
    let announcement: MarqueeAnnouncement
    
    var height: CGFloat = 30
    var speed: CGFloat = 45
    
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = UIScreen.main.bounds.width
    @State private var offsetX: CGFloat = UIScreen.main.bounds.width
    @State private var isVisible: Bool = false
    @State private var runToken = UUID()
    
    private let edgeBuffer: CGFloat = 12
    
    private var text: String {
        announcement.displayText
    }
    
    private var canShow: Bool {
        announcement.isOpen && !text.isEmpty
    }
    
    var body: some View {
        ZStack {
            if canShow {
                Color.black
                
                Text(text)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        TextWidthReader(width: $textWidth)
                    )
                    .offset(x: offsetX)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: canShow ? height : 0)
        .clipped()
        .opacity(isVisible ? 1 : 0)
        .background(
            ContainerWidthReader(width: $containerWidth)
        )
        .onAppear {
            restartWithFadeIn()
        }
        .onChange(of: announcement.message) { _ in
            restartWithFadeIn()
        }
        .onChange(of: announcement.isOpen) { _ in
            if canShow {
                restartWithFadeIn()
            } else {
                fadeOutAndStop()
            }
        }
        .onChange(of: announcement.isLoop) { _ in
            restartWithFadeIn()
        }
        .onChange(of: textWidth) { _ in
            restartWithFadeIn()
        }
        .onChange(of: containerWidth) { _ in
            restartWithFadeIn()
        }
    }
    
    private func restartWithFadeIn() {
        runToken = UUID()
        let token = runToken
        
        guard canShow else {
            fadeOutAndStop()
            return
        }
        
        guard textWidth > 0, containerWidth > 0 else {
            return
        }
        
        let startX = startOffsetX()
        offsetX = startX
        
        withAnimation(.easeInOut(duration: 0.35)) {
            isVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard token == runToken else { return }
            guard canShow else { return }
            runOnce(token: token, shouldFadeIn: false)
        }
    }
    
    private func runOnce(token: UUID, shouldFadeIn: Bool) {
        guard token == runToken else { return }
        guard canShow else { return }
        guard textWidth > 0, containerWidth > 0 else { return }
        
        let startX = startOffsetX()
        let endX = endOffsetX()
        let distance = containerWidth + textWidth + edgeBuffer * 2
        let duration = Double(distance / speed)
        
        offsetX = startX
        
        if shouldFadeIn {
            withAnimation(.easeInOut(duration: 0.35)) {
                isVisible = true
            }
        }
        
        withAnimation(.linear(duration: duration)) {
            offsetX = endX
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard token == runToken else { return }
            guard canShow else { return }
            
            if announcement.isLoop {
                // loop時不要淡出淡入，只是下一輪直接從右側重新開始
                runOnce(token: token, shouldFadeIn: false)
            } else {
                // 非loop時，等文字完整離開左側後才淡出
                withAnimation(.easeInOut(duration: 0.35)) {
                    isVisible = false
                }
            }
        }
    }
    
    private func fadeOutAndStop() {
        runToken = UUID()
        
        withAnimation(.easeInOut(duration: 0.35)) {
            isVisible = false
        }
    }
    
    private func startOffsetX() -> CGFloat {
        (containerWidth + textWidth) / 2 + edgeBuffer
    }
    
    private func endOffsetX() -> CGFloat {
        -((containerWidth + textWidth) / 2 + edgeBuffer)
    }
}

// MARK: - 讀取文字寬度
private struct TextWidthReader: View {
    @Binding var width: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    width = geo.size.width
                }
        }
    }
}

// MARK: - 讀取容器寬度
private struct ContainerWidthReader: View {
    @Binding var width: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    width = geo.size.width
                }
        }
    }
}
