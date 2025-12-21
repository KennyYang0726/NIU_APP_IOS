import SwiftUI


// 我的報名
struct ScoreInquiry_Tab2_View: View {
    
    @ObservedObject var vm = ScoreInquiry_Tab2_ViewModel()
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        VStack {
            // 排名資訊
            VStack {
                HStack {
                    Text("Ranking_Text")
                    Text("Ranking \(vm.rankText)")
                    Spacer()
                }
                HStack {
                    Text("Avg")
                    Text(vm.avgText)
                    Spacer()
                }
            }
            .padding(isPad ? 21 : 10)
            .background(Color("AccentColor"))
            .foregroundStyle(.white)
            .font(.system(size: isPad ? 37 : 19))
            .cornerRadius(15)
            .shadow(radius: 2)
            .padding(.top, isPad ? 21 : 11)
            .padding(.horizontal, isPad ? 37 : 11)
            // 成績列表
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.courseList) { courseVM in
                            ScoreInquiry_Tab_ListView(vm: courseVM)
                        }
                    }
                    .padding(.top, 10)
                }
                // 移出畫面外的 Webview
                ZStack {
                    WebViewContainer(webView: vm.webProvider.webView)
                        //.frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .offset(x: UIScreen.main.bounds.width * 2)
                }
            }
        }
        // 加載中 prog (注意！放在這裡才是全版面)
        .overlay(
            ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea()) // 全域底色
    }
}
