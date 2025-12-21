import SwiftUI



struct MailView: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    
    public var body: some View {
        AppBar_Framework(title: "Mail") {
            VStack(alignment: .leading, spacing: 16) {
                Text("這裡是校園信箱頁面")
                    .font(.title3)
                Text("wwwwwwww")
                    .font(.body)
            }
        }
    }
}
