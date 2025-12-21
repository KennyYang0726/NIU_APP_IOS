import SwiftUI



struct AchievementsFeature {
    let iconName: String
    let title: String
    let subtitle: String
    let status: String
}


struct Drawer_Achievements_ListView: View {

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    let feature: AchievementsFeature
    let index: Int

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                // icon
                Image(feature.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isPad ? 79 : 47)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(feature.title)
                        .font(.system(size: isPad ? 32 : 20, weight: .semibold))
                        .foregroundColor(.primary)
                    Image(feature.status)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isPad ? 113 : 79)
                    Spacer()
                }
                Text(feature.subtitle)
                    .font(.system(size: isPad ? 26 : 15))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, isPad ? 18 : 12)
        .background(Color("Linear_Inside"))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
