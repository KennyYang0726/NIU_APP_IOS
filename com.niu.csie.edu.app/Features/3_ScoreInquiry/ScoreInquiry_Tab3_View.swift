import SwiftUI



struct ScoreInquiry_Tab3_View: View {
    
    @Environment(\.colorScheme) var colorScheme
    @StateObject var vm = ScoreInquiry_Tab3_ViewModel()

    var body: some View {
        ZStack {
            WebViewContainer(webView: vm.webProvider.webView)
                .ignoresSafeArea(edges: .bottom)
                .opacity(vm.isWebVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: vm.isWebVisible)
        }
        // 加載中 prog (注意！放在這裡才是全版面)
        .overlay(
            ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea()) // 全域底色
        .onAppear {
            vm.colorScheme = colorScheme
        }
    }
}
