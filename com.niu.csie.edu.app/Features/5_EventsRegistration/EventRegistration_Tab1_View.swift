import SwiftUI


// 活動列表
struct EventRegistration_Tab1_View: View {
    
    @ObservedObject var vm = EventRegistration_Tab1_ViewModel()

    var body: some View {
        VStack {
            ZStack {
                VStack(spacing: 0) {
                    // 搜尋面板
                    EventSearchPanel(
                        isExpanded: $vm.isSearchPanelExpanded,
                        searchText: $vm.searchText,
                        selectedType: $vm.selectedHourType
                    )
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.displayEvents) { event in
                                let itemVM = EventRegistration_Tab1_ListViewModel(event: event)
                                EventRegistration_Tab1_ListView(
                                    vm: itemVM,
                                    onDetailTapped: { e in
                                        UIApplication.shared.endEditing()
                                        vm.showEventDetailDialog = true
                                        vm.selectedEventForDetail = e
                                    },
                                    onRegisterTapped: { e in
                                        UIApplication.shared.endEditing()
                                        vm.isPostHandled = true
                                        vm.RegisterEvent(EventID: e.eventSerialID)
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIApplication.shared.endEditing()
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            UIApplication.shared.endEditing()
                        }
                    )
                }

                // --- FAB 按鈕 ---
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            // 判斷 FAB 收合與否
                            if vm.isFabExpanded {
                                Button {
                                    guard !vm.isOverlayVisible else { return } // 禁用點擊
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                        vm.isFabExpanded = false
                                        vm.isSearchPanelExpanded.toggle()
                                    }
                                } label: {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.orange.opacity(0.6))
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                Button {
                                    guard !vm.isOverlayVisible else { return } // 禁用點擊
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        vm.isFabExpanded = false
                                    }
                                    vm.showQRScanner = true
                                } label: {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.green.opacity(0.6))
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            Button {
                                guard !vm.isOverlayVisible else { return } // 禁用點擊
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    vm.isFabExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: vm.isFabExpanded ? "xmark" : "magnifyingglass")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        vm.isFabExpanded
                                        ? Color.red.opacity(0.6)
                                        : Color.blue.opacity(0.45)
                                    )
                                    .clipShape(Circle())
                                    .shadow(radius: 6)
                            }
                        }
                        .padding(.trailing, 11)
                        .padding(.bottom, 24)
                    }
                }
                .ignoresSafeArea()
                .toast(isPresented: $vm.showToast) {
                    Text(LocalizedStringKey("Event_Register_Success"))
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
        // 切換至全屏 qrcode 掃描
        .fullScreenCover(isPresented: $vm.showQRScanner) {
            QRCodeScanView { validURL in
                vm.showQRScanner = false
                vm.handleScannedCCSYSURL(validURL)
            }
        }
    }
}
