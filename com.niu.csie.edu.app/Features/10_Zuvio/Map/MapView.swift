import SwiftUI
import MapKit


struct MapView: View {

    @ObservedObject var viewModel: ZuvioViewModel // 傳遞選擇的經緯度，這個物件是從外面傳進來的，「我不負責建立與持有生命週期」，但「我可以完全讀寫這個物件的內容」
    @Environment(\.dismiss) private var dismiss
    // 新增 toast 控制
    @State var showToast: Bool = true
    @State var toastMessage: LocalizedStringKey = "Toast_Entry_Map_Choosing"
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 24.746209,
            longitude: 121.745646
        ),
        span: MKCoordinateSpan(
            // 這裡調整越小，檢視範圍越小
            latitudeDelta: 0.0057,
            longitudeDelta: 0.0057
        )
    )

    var body: some View {
        TapMapView(region: region) { coordinate in
            viewModel.updateCoordinate(coordinate)
            dismiss()
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(LocalizedStringKey("Map_Choosing_Title"))
        .toolbarBackground(.visible, for: .navigationBar) // 強制背景顯示
        .toolbarBackground(Color.accentColor, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // 隱藏預設返回按鈕
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        if isPad {
                            Text(LocalizedStringKey("back")) // iPad 顯示文字
                        }
                    }
                }
                .foregroundColor(.white) // 可依需求調整顏色
            }
        }
        .toast(isPresented: $showToast) {
            Text(toastMessage)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        }
        // 返回手勢攔截
        .background(
            NavigationSwipeHijacker(
                handleSwipe: {
                    dismiss()
                    return true     // 我已經處理，系統不要再 pop
                }
            )
        )
    }
}
