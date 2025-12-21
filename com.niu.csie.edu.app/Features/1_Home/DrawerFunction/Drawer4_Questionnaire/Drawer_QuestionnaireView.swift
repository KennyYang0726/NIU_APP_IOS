import SwiftUI



struct Drawer_QuestionnaireView: View {
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        NavigationStack {
            // MARK: - 說明卡片頁面
            ZStack {
                VStack {
                    VStack(spacing: isPad ? 24 : 16) {
                        Text(LocalizedStringKey("Satisfaction_Survey_Text"))
                            .font(.system(size: isPad ? 47 : 21))
                            .foregroundColor(Color("Text_Color"))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 23)
                            .foregroundColor(Color("Linear_Inside"))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 40)

                    // 啟動問卷按鈕
                    NavigationLink {
                        WebQuestionnairePage()
                    } label: {
                        Text(LocalizedStringKey("Start_Satisfaction_Survey"))
                            .font(.system(size: isPad ? 47 : 21))
                            .padding(13)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 40)
                                    .foregroundColor(Color("BG_Color"))
                            )
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, isPad ? 41 : 20)
                    .padding(.top, 40)

                    Spacer()
                }
            }
            .background(Color("Linear").ignoresSafeArea()) // 全域底色
        }
    }
}

// MARK: - 問卷 WebView 頁面
struct WebQuestionnairePage: View {
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    @Environment(\.dismiss) private var dismiss
    @StateObject private var webProvider = WebView_Provider(
        initialURL: "https://forms.gle/vYGJN8sa884ntvWR9",
        userAgent: .mobile
    )

    var body: some View {
        WebViewContainer(webView: webProvider.webView)
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(LocalizedStringKey("Satisfaction_Survey"))
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
        // 返回手勢攔截
        .background(
            NavigationSwipeHijacker(
                handleSwipe: {
                    dismiss()
                    return true     // 我已經處理，系統不要再 pop
                }
            )
        )
        .onAppear {
            // 填寫完成，獲得成就
            webProvider.onPageFinished = { _ in
                webProvider.evaluateJS("javascript:(function() {return document.body.innerText.includes('我們已經收到您回覆的表單');})()") { result in
                    if result! == "1" {
                        AchievementsMethod().achievementsGet(index: "02")
                    }
                }
            }
        }
    }
}
