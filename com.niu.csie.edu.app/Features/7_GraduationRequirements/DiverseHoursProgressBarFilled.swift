import SwiftUI



struct DiverseHoursProgressBarFilled: View {
    var progress: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let height = geo.size.height
            let width = fullWidth * progress
            
            let jointOffset: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 18 : 8
            let effectiveOffset = jointOffset * 2
            
            let fillShape = Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: width, y: 0))
                
                // 尾端斜切
                path.addLine(to: CGPoint(x: width - effectiveOffset, y: height))
                
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            
            fillShape
                .fill(barColor(for: progress))
                // 關鍵：再次用外框裁切，避免溢出
                .mask(
                    DiverseHoursProgressBarShape()
                )
        }
    }
    
    private func barColor(for progress: CGFloat) -> Color {
        if progress < 0.37 {
            return Color(hex: "#94003C").opacity(0.6)
        } else if progress < 0.67 {
            return Color(hex: "#BCBE00").opacity(0.6)
        } else {
            return Color(hex: "#6CB712").opacity(0.6)
        }
    }
    
}


