import SwiftUI
import MapKit



struct ZuvioView: View {
    
    @EnvironmentObject var appState: AppState // 注入狀態
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var vm = ZuvioViewModel()
    
    // MARK: - Menu Button Builder
    @ViewBuilder
    private func menuButton(for item: LocationMenuItem) -> some View {
        Button {
            vm.updateCoordinate(
                item.coordinate, toastMessage: String.localized("Toast_Choosed_Location_MenuItem", NSLocalizedString(item.titleKey, comment: ""))
            )
        } label: {
            Text(LocalizedStringKey(item.titleKey))
        }
    }
    
    // MARK: - Menu Model
    private struct LocationMenuItem: Identifiable {
        let id = UUID()
        let titleKey: String
        let coordinate: CLLocationCoordinate2D?
    }

    // MARK: - Menu Data
    private let locationMenuItems: [LocationMenuItem] = [
        .init(titleKey: "EECS_Building", coordinate: .init(latitude: 24.7454820, longitude: 121.7450088)),
        .init(titleKey: "Engineering_Building", coordinate: .init(latitude: 24.7454690, longitude: 121.7440559)),
        .init(titleKey: "Bioresources_Building", coordinate: .init(latitude: 24.7468043, longitude: 121.7455621)),
        .init(titleKey: "HaM_Building", coordinate: .init(latitude: 24.7467896, longitude: 121.7467287)),
        .init(titleKey: "Jiaose_Building", coordinate: .init(latitude: 24.7461405, longitude: 121.7457680)),
        .init(titleKey: "Comprehensive_Building", coordinate: .init(latitude: 24.7462449, longitude: 121.7471765)),
        .init(titleKey: "Guishan", coordinate: .init(latitude: 24.8464381, longitude: 121.9489986)),
        .init(titleKey: "Cancel_Mock", coordinate: nil)
    ]
    
    
    var body: some View {
        AppBar_Framework(title: "Zuvio") {
            ZStack {
                // --- 主要內容 ---
                WebViewContainer(webView: vm.webProvider.webView)
                    .opacity(vm.isWebVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: vm.isWebVisible)
                    .ignoresSafeArea(edges: .bottom)
                // --- FAB 按鈕 ---
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink {
                            MapView(viewModel: vm)
                        } label: {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .ignoresSafeArea()
            }
            // MenuItem
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(locationMenuItems) { item in
                            menuButton(for: item)
                            if item.titleKey == "Guishan" {
                                // 和取消 Mock 之間有一條細線分隔
                                Divider()
                            }
                        }
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 18))
                    }
                }
            }
            // 加載中 prog (注意！放在這裡才是全版面)
            .overlay(
                ProgressOverlay(isVisible: $vm.isOverlayVisible, text: vm.overlayText)
                // Toast 放這裡才會在 prog 上方，因為選取偽座標會同時出
                .toast(isPresented: $vm.showToast) {
                    Text(vm.toastMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                }
            )
            // 返回手勢攔截
            .background(
                NavigationSwipeHijacker(
                    handleSwipe: {
                        if vm.webProvider.webView.canGoBack {
                            vm.webProvider.goBack()
                            return true    // 攔截 pop
                        } else {
                            appState.navigate(to: .home)
                            return false   // 放行 pop（或你直接 navigate）
                        }
                    }
                )
            )
            .onAppear {
                // 初始化狀態
                vm.initializeState()
                vm.colorScheme = colorScheme
            }
        }
    }
}
