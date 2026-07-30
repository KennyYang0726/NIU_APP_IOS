import SwiftUI



class EventRegistrationTabViewModel: ObservableObject {
    @Published var tabs: [LocalizedStringKey] = [
        "eventReg_tab_eventsList",
        "eventReg_tab_myApplyEvents"
    ]
    @Published var selectedIndex: Int = 0

    func selectTab(index: Int) {
        selectedIndex = index
    }
}
