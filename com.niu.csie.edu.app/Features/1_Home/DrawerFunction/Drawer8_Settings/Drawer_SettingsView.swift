import SwiftUI



struct Drawer_SettingsView: View {

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appState: AppState
    @State var showDialog = false
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        // 自訂「主題選擇區塊」
        ZStack {
            // 全域底色
            Color("Linear").ignoresSafeArea()
            VStack {
                // Picker
                if (isPad) {
                    HStack {
                        Text(LocalizedStringKey("Theme"))
                            .font(.system(size: 31))
                        Spacer()
                        Picker(
                            (LocalizedStringKey("Theme")), selection: $settings.theme) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Text(LocalizedStringKey(theme.rawValue))
                            }
                        }
                        .pickerStyle(.segmented)
                        .fontWidth(.expanded)
                    }.padding(17)
                    .background(Color("Linear_Inside").opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 19))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 37)
                    .padding(.vertical, 19)
                } else {
                    HStack {
                        Text(LocalizedStringKey("Theme"))
                            .font(.system(size: 17))
                        Spacer()
                        Picker(
                            (LocalizedStringKey("Theme")), selection: $settings.theme) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Text(LocalizedStringKey(theme.rawValue))
                            }
                        }
                        .pickerStyle(.menu) // 類似 Android Spinner
                        .fontWidth(.expanded)
                        .tint(.blue) // 選中顏色
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 17)
                    .background(
                        Color("Linear_Inside"))
                    .clipShape(RoundedRectangle(cornerRadius: 37))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 37)
                    .padding(.vertical, 19)
                }
                // 刪除使用者資料
                Button {
                    showDialog = true
                } label: {
                    Text(LocalizedStringKey("delete_user_data"))
                        .font(.system(size: isPad ? 37 : 19))
                        .padding(5)
                        .frame(maxWidth: .infinity)
                }
                .background(
                    RoundedRectangle(cornerRadius: 40).foregroundColor(Color.red)
                )
                .padding(.top, isPad ? 47 : 19)
                .padding(.horizontal, isPad ? 199 : 91)
                .foregroundColor(.white)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .overlay() {
            if showDialog {
                CustomAlertOverlay2(
                    title: "DelUserDatabase",
                    icon: nil,
                    message: .rich([
                        .textKey("DelUserDatabaseMessage1"),
                        .linkKey(key: "DelUserDatabaseMessage_link", id: "0"),
                        .textKey("DelUserDatabaseMessage2")
                        ]),
                    // messageAlignment: .leading,   // 可選參數
                    onCancel: {
                        showDialog = false
                    },
                    onConfirm: {
                        showDialog = false
                        // 1) 刪除資料庫中使用者資料
                        let userID = LoginRepository().loadCredentials()?.username ?? "取得學號失敗"
                        FirebaseDatabaseManager.shared.deleteData(at: "users/\(userID)") { error in
                            if let error = error {
                                print("刪除失敗：\(error.localizedDescription)")
                                appState.navigate(to: .home, withToast: "刪除失敗")
                            } else {
                                // print("刪除成功")
                                // 2) 立即清本機（帳密/姓名），M園區課程資料
                                LoginRepository().clearCredentials()
                                if let EUNI_CourseData = UserDefaults(suiteName: "EUNIcourseData") {
                                    EUNI_CourseData.removePersistentDomain(forName: "EUNIcourseData")
                                    EUNI_CourseData.synchronize()
                                }
                                settings.name = ""
                                // 3) 統一導回登入頁
                                appState.navigate(to: .login, withToast: LocalizedStringKey("DelUserDatabaseSuccess"))
                            }
                        }
                    },
                    linkActions: [
                        "0": {
                            UIApplication.shared.open(URL(string: "https://raw.githubusercontent.com/KennyYang0726/NIU_APP/refs/heads/main/database_content.jpg")!)
                        }
                    ]
                )
            }
        }
    }
}
