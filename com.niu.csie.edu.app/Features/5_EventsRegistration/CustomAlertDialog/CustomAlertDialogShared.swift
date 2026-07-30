import SwiftUI



// MARK: - 主題配色
struct DialogPalette {
    let titleBG: Color
    let cardBG: Color
    let buttonBlue: Color
    
    init(_ scheme: ColorScheme) {
        if scheme == .dark {
            titleBG = Color("BG_Color")
            cardBG = Color("Linear")
            buttonBlue = Color("BG_Color")
        } else {
            titleBG = Color("BG_Color")
            cardBG = Color("Linear")
            buttonBlue = Color("BG_Color")
        }
    }
}

// MARK: - Table 結構
struct TableRow<Content: View>: View {
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    let label: LocalizedStringKey
    let content: () -> Content
    
    init(_ label: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: isPad ? 23 : 13))
                .foregroundColor(Color("Text_Color"))
                .frame(width: 120, alignment: .leading)
            content()
                .font(.system(size: isPad ? 23 : 13))
                .foregroundColor(Color("Text_Color"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

struct TableBox<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color("Text_Color"), lineWidth: 1.3)
        )
    }
}

// MARK: - 共用按鈕樣式
struct DialogButtonStyle: ButtonStyle {
    let bg: Color
    let fg: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(height: 40)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(fg)
            .background(bg.opacity(configuration.isPressed ? 0.85 : 1))
            .cornerRadius(10)
    }
}

// MARK: - 圓角形狀（支援指定邊角）
struct RoundedCornerShape: Shape {
    var radius: CGFloat = 12.0
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
