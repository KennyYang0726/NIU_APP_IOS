import Foundation
import SwiftUI
import Combine


// ViewModel 控制狀態
final class DrawerManagerViewModel: ObservableObject {

    @Published var isDrawerOpen = false
    @Published var currentPage: DrawerPageCase = .home

    
    func switchPage(to page: DrawerPageCase) {
        withAnimation {
            currentPage = page
            isDrawerOpen = false
        }
    }
    
    func toggleDrawer() {
        withAnimation {
            isDrawerOpen.toggle()
        }
    }
    
    func closeDrawer() {
        withAnimation {
            isDrawerOpen = false
        }
    }

}
