import SwiftUI


import SwiftUI

struct Drawer_AnnouncementsView: View {
    
    @ObservedObject var vm = Drawer_AnnouncementsViewModel()
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        VStack {
            Text(LocalizedStringKey("Announcement_show_only_15_result"))
                .font(.system(size: isPad ? 33 : 19))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.vertical, isPad ? 13 : 7)
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.announcements) { item in
                            Drawer_Announcements_ListView(item: item) { tappedItem in
                                vm.onItemTapped(tappedItem)
                            }
                        }
                    }
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
        .overlay() {
            if vm.showDialog {
                CustomAlertOverlay2(
                    title: "Announcement_Dialog_Title",
                    icon: Image(systemName: "globe"),
                    message: .plain("Announcement_Dialog_Message"),
                    // messageAlignment: .leading,   // 可選參數
                    onCancel: {
                        vm.showDialog = false
                    },
                    onConfirm: {
                        vm.showDialog = false
                        // 確保有選到公告
                        guard var url_final = vm.selectedAnnouncementsDetail?.href_link else {
                            return
                        }
                        // 去除空白
                        url_final = url_final.trimmingCharacters(in: .whitespacesAndNewlines)
                        // 若不是 https 開頭，自動補上完整網址
                        // /var/file/... 通常是 PDF 或附件
                        if !url_final.hasPrefix("https") {
                            let base = "https://www.niu.edu.tw"
                            if url_final.hasPrefix("/") {
                                url_final = base + url_final
                            } else {
                                url_final = base + "/" + url_final
                            }
                        }
                        // 嘗試開啟瀏覽器
                        guard let url = URL(string: url_final) else {
                            print("URL 格式錯誤：\(url_final)")
                            return
                        }
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            print("無法開啟瀏覽器：\(url_final)")
                        }
                    },
                    linkActions: nil
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea())
    }
}
