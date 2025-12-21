import SwiftUI


// 活動列表
struct ScoreInquiry_Tab1_View: View {
    
    @ObservedObject var vm = ScoreInquiry_Tab1_ViewModel()
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        VStack {
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
