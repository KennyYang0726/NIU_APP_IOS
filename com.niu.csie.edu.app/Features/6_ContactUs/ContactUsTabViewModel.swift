import SwiftUI



class ContactUsTabViewModel: ObservableObject {
    @Published var tabs: [LocalizedStringKey] = [
        "contactus_tab_feedback",
        "contactus_tab_bugreport"
    ]
    @Published var selectedIndex: Int = 0

    func selectTab(index: Int) {
        selectedIndex = index
    }
}
