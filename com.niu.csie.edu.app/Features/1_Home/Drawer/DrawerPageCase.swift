import Foundation
import SwiftUI


// 定義 Drawer case
enum DrawerPageCase {
    case home, announcements, calendar, questionnaire, achievements, huh, about, settings, sponsor, logout

    var title: LocalizedStringKey {
        switch self {
        case .home: return "HomePage"
        case .announcements: return "Announcement"
        case .calendar: return "Calendar"
        case .questionnaire: return "Satisfaction_Survey"
        case .achievements: return "Achievements"
        case .huh: return "huh"
        case .about: return "About"
        case .settings: return "Settings"
        case .sponsor: return "Sponsor"
        case .logout: return "Logout"
        }
    }
}
