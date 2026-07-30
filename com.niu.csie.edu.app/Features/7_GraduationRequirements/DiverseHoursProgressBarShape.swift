import SwiftUI



struct DiverseHoursProgressBarShape: Shape {
    
    // 斜邊 (越大越斜)
    var jointOffset: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 18 : 8
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topY: CGFloat = 0 // Y 起點 (於上方，接下來往下是正的)
        let halfY: CGFloat = rect.height/2 // 一半的 Y
        let back_1: CGFloat = rect.width/1.7 // 第一段返回
        
        // 左上
        path.move(to: CGPoint(x: 0, y: topY))
        // 完成上方最長邊
        path.addLine(to: CGPoint(x: rect.width, y: topY))
        // 右上至左下 斜切下降
        path.addLine(to: CGPoint(x: rect.width - jointOffset, y: halfY))
        // 向左返回一段
        path.addLine(to: CGPoint(x: back_1, y: halfY))
        // 右上至左下 斜切下降
        path.addLine(to: CGPoint(x: back_1 - jointOffset, y: rect.height))
        // 主體底邊回到左下
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        // 將筆畫拉回最左上方起點處
        path.closeSubpath()
        return path
    }
}
