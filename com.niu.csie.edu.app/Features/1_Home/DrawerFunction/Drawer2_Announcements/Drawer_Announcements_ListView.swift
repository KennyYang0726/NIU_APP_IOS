import SwiftUI



struct AnnouncementsData: Identifiable, Codable {
    var id: String { title }
    let title: String
    let date: String
    let href_link: String
}

struct Drawer_Announcements_ListView: View {
    
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    let item: AnnouncementsData
    // 註冊 callback
    let onTap: (AnnouncementsData) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: isPad ? 19 : 10) {
            HStack {
                Text(item.title)
                    .font(.system(size: isPad ? 33 : 19))
                    .foregroundColor(.primary)
                Spacer()
                Text(item.date)
                    .font(.system(size: isPad ? 33 : 19))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, isPad ? 15 : 7)
        }
        .background(Color("Linear_Inside"))
        .cornerRadius(11)
        .shadow(radius: 2)
        .padding(.horizontal, 11)
        .onTapGesture {
            onTap(item)
        }
    }
}
