import SwiftUI


// MARK: - Alert Message Model
enum AlertMessage {
    case plain(LocalizedStringKey)
    case rich([AlertMessagePart])
}

enum AlertMessagePart: Identifiable {
    case text(String)
    case textKey(LocalizedStringKey)
    case link(text: String, id: String)
    case linkKey(key: LocalizedStringKey, id: String)
    case textColor(String, Color)
    case textKeyColor(LocalizedStringKey, Color)

    var id: String { UUID().uuidString }
}

// MARK: - 按鈕設定
struct AlertButtonConfig: Identifiable {
    let id = UUID()
    let titleKey: LocalizedStringKey
    let action: () -> Void
}

// MARK: - Base Dialog
struct CustomAlertBase: View {

    let title: LocalizedStringKey
    let icon: Image?
    let message: AlertMessage
    let linkActions: [String: () -> Void]?
    let buttons: [AlertButtonConfig]
    let messageAlignment: TextAlignment

    @Environment(\.colorScheme) private var scheme
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {

        let P = DialogPalette(scheme)

        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {

                // ===== 標題 =====
                HStack {
                    Text(title)
                        .font(.system(size: isPad ? 26 : 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isPad ? 14 : 10)
                        .padding(.horizontal, isPad ? 11 : 7)

                    if let icon = icon {
                        icon
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: isPad ? 28 : 20, height: isPad ? 28 : 20)
                            .padding(.trailing, isPad ? 17 : 11)
                    }
                }
                .background(P.titleBG)
                .clipShape(
                    RoundedCornerShape(
                        radius: isPad ? 18 : 12,
                        corners: [.topLeft, .topRight]
                    )
                )

                // ===== 內容 =====
                VStack(alignment: .leading, spacing: isPad ? 24 : 14) {

                    switch message {
                    case .plain(let key):
                        Text(key)
                            .font(.system(size: isPad ? 23 : 15))
                            .foregroundColor(Color("Text_Color"))
                            .multilineTextAlignment(messageAlignment)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)

                    case .rich(let parts):
                        RichTextMessageView(
                            parts: parts,
                            linkActions: linkActions ?? [:],
                            alignment: messageAlignment
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                    }

                    // ===== 按鈕區 =====
                    buttonsView(buttonColor: P.buttonBlue)
                        .padding(.horizontal, isPad ? 60 : 40)
                        .padding(.bottom, isPad ? 10 : 6)
                }
                .padding(isPad ? 32 : 20)
                .background(P.cardBG)
                .clipShape(
                    RoundedCornerShape(
                        radius: isPad ? 18 : 12,
                        corners: [.bottomLeft, .bottomRight]
                    )
                )
            }
            .frame(maxWidth: isPad ? 700 : 640)
            .shadow(radius: isPad ? 30 : 20)
            .padding(.horizontal, isPad ? 40 : 20)
        }
    }

    // MARK: - 按鈕排版
    @ViewBuilder
    private func buttonsView(buttonColor: Color) -> some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        switch buttons.count {
        case 1:
            if let b = buttons.first {
                Button(action: b.action) {
                    Text(b.titleKey)
                        .font(.system(size: isPad ? 23 : 15))
                        .frame(maxWidth: .infinity)
                        .padding(isPad ? 17 : 11)
                }
                .buttonStyle(DialogButtonStyle(bg: buttonColor, fg: .white))
            }

        default:
            HStack(spacing: isPad ? 22 : 16) {
                ForEach(buttons) { b in
                    Button(action: b.action) {
                        Text(b.titleKey)
                            .font(.system(size: isPad ? 23 : 15))
                            .frame(maxWidth: .infinity)
                            .padding(isPad ? 17 : 11)
                    }
                    .buttonStyle(DialogButtonStyle(bg: buttonColor, fg: .white))
                }
            }
        }
    }
}
