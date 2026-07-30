import SwiftUI


// 我的報名
struct EventRegistration_Tab2_View: View {
    
    @ObservedObject var vm = EventRegistration_Tab2_ViewModel()

    var body: some View {
        VStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.events, id: \.id) { event in
                            EventRegistration_Tab2_ListView(
                                vm: EventRegistration_Tab2_ListViewModel(event: event),
                                onDetailTapped: { e in
                                    vm.showEventDetailDialog = true
                                    vm.selectedEventForDetail = e
                                },
                                onModdingInfoTapped: { e in
                                    // 由於要帶入資料，要等頁面載入完成才能改變標誌
                                    // vm.showModdingEventInfoDialog = true
                                    vm.ModdingEventInfo(EventID: e.eventSerialID)
                                }
                            )
                        }

                    }
                    .padding(.top, 10)
                }
                .toast(isPresented: $vm.showToast) {
                    Text(vm.toastMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                }
                // 移出畫面外的 Webview
                ZStack {
                    WebViewContainer(webView: vm.webProvider.webView)
                        .frame(maxWidth: 100, maxHeight: 100)
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
