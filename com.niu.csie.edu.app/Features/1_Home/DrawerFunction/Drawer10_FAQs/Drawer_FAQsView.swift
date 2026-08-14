import SwiftUI



struct Drawer_FAQsView: View {
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private let faqItems = Drawer_FAQsModel.defaultItems

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(faqItems) { item in
                    faqItemView(item)
                }
            }
            .padding(.top, isPad ? 18 : 8)
            .padding(.bottom, isPad ? 26 : 14)
        }
        .background(Color("Linear").ignoresSafeArea())
    }

    // MARK: - FAQ Item
    private func faqItemView(_ item: FAQItem) -> some View {
        VStack(spacing: isPad ? 14 : 8) {
            // 問題：靠右顯示，對齊 Android FAQ 的提問泡泡
            HStack {
                Spacer(minLength: isPad ? 110 : 54)

                Text(LocalizedStringKey(item.questionKey))
                    .font(.system(size: isPad ? 30 : 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, isPad ? 24 : 16)
                    .padding(.vertical, isPad ? 17 : 11)
                    .background(
                        RoundedRectangle(cornerRadius: isPad ? 28 : 22)
                            .foregroundColor(Color.accentColor)
                    )
                    .frame(maxWidth: isPad ? 650 : 420, alignment: .trailing)
            }
            .padding(.horizontal, isPad ? 24 : 14)

            // 回答：靠左顯示，使用 Drawer 既有內容底色
            HStack {
                Text(LocalizedStringKey(item.answerKey))
                    .font(.system(size: isPad ? 27 : 16))
                    .foregroundColor(Color("Text_Color"))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, isPad ? 24 : 16)
                    .padding(.vertical, isPad ? 17 : 11)
                    .background(
                        RoundedRectangle(cornerRadius: isPad ? 24 : 18)
                            .foregroundColor(Color("Linear_Inside"))
                    )
                    .frame(maxWidth: isPad ? 650 : 420, alignment: .leading)

                Spacer(minLength: isPad ? 110 : 54)
            }
            .padding(.horizontal, isPad ? 24 : 14)

            Divider()
                .padding(.horizontal, isPad ? 40 : 30)
                .padding(.top, isPad ? 18 : 12)
        }
        .padding(.bottom, isPad ? 20 : 14)
    }
}
