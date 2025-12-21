import SwiftUI



struct Huh2Page: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let imageName: String
    let description: LocalizedStringKey
}

final class Drawer_Huh2ViewModel: ObservableObject {

    @Published var pages: [Huh2Page] = []

    init(feature: HuhFeature) {
        // 未來你會將 HuhFeature 中的 pages 帶進來
        self.pages = feature.pages
    }
}
