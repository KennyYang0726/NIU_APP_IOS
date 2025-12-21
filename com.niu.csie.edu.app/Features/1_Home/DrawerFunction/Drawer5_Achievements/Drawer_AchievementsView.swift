import SwiftUI



struct Drawer_AchievementsView: View {

    @StateObject private var vm = Drawer_AchievementsViewModel()
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: isPad ? 13 : 7) {
                    ForEach(Array(vm.features.enumerated()), id: \.offset) { index, feature in
                        let content = Drawer_Achievements_ListView(feature: feature, index: index)
                        if index == vm.features.count - 1 {
                            Button {
                                vm.NightMarketGuyClicked()
                            } label: {
                                content
                            }
                            .buttonStyle(.plain)
                        } else {
                            content
                        }
                    }

                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Linear").ignoresSafeArea())
        .onAppear {
            vm.fetchAchievementStates()
        }
        .overlay() {
            if vm.showDialog {
                CustomAlertOverlay1(
                    title: "Achievements_11_Dialog_Title",
                    icon: nil,
                    message: .rich(vm.nightMarketParts),
                    messageAlignment: .leading,   // 可選參數
                    onConfirm: {
                        vm.showDialog = false
                    },
                    linkActions: [:]
                )
            }
        }
        .toast(isPresented: $vm.showToast) {
            Text(vm.toastMessage)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
        }
    }
}
