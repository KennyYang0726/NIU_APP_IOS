import SwiftUI



@MainActor
final class EUNI1_ListViewModel: ObservableObject, Identifiable {
    @Published var isExpanded: Bool = false
    
    let name: String
    let id: String
    let announcementID: String?
    
    init(name: String, id: String, announcementID: String? = nil) {
        self.name = name
        self.id = id
        self.announcementID = announcementID
    }
    
    func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded.toggle()
        }
    }
}
