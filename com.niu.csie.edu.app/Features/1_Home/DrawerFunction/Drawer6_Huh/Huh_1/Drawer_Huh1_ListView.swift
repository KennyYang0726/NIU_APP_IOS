import SwiftUI



struct HuhFeature {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let iconName: String
    let isSystemIcon: Bool
    let pages: [Huh2Page]
}


struct Drawer_Huh1_ListView: View {

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    let feature: HuhFeature
    let index: Int

    var body: some View {
        HStack(spacing: 15) {
            // Icon 大外圈
            ZStack {
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: isPad ? 85 : 60, height: isPad ? 85 : 60)
                // icon
                if feature.isSystemIcon {
                    Image(systemName: feature.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isPad ? 45 : 28, height: isPad ? 45 : 28)
                        .foregroundColor(.primary)
                } else {
                    Text(feature.iconName)
                        .font(.custom("MyFlutterApp", size: isPad ? 55 : 37))
                        .foregroundColor(.primary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.system(size: isPad ? 32 : 19, weight: .semibold))
                    .foregroundColor(.primary)
                Text(feature.subtitle)
                    .font(.system(size: isPad ? 26 : 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: isPad ? 26 : 18))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, isPad ? 18 : 12)
        .background(Color("Linear_Inside"))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal, 11)
    }
}


