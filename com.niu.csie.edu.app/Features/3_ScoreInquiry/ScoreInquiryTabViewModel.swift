import SwiftUI



class ScoreInquiryTabViewModel: ObservableObject {
    @Published var tabs: [LocalizedStringKey] = [
        "scoreInquiry_tab_mid_term_results",
        "scoreInquiry_tab_final_term_results"
    ]
    @Published var selectedIndex: Int = 0

    func selectTab(index: Int) {
        selectedIndex = index
    }
}
