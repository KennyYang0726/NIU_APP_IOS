import SwiftUI


/// 共用的活動資訊 Row 元件
struct EventInfoRow: View {
    var icon: String
    var label: LocalizedStringKey
    var value: String

    // @Environment(\.horizontalSizeClass) private var horizontalClass
    // @Environment(\.verticalSizeClass) private var verticalClass

    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: icon)
                .font(.system(size: isPad ? 37 : 18))
                .frame(width: isPad ? 50 : 20)
                .padding(.leading, 10)
            Text(label)
                .font(.system(size: isPad ? 31 : 14))
                .frame(width: 120, alignment: .leading)
            Spacer(minLength: isPad ? 59 : 0)
            Text(value)
                .font(.system(size: isPad ? 30 : 13))
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
