import SwiftUI



@MainActor
final class EventRegistration_Tab1_ListViewModel: ObservableObject, @preconcurrency Identifiable {
    @Published var isExpanded: Bool = false
    let event: EventData
    
    init(event: EventData) {
        self.event = event
    }

    var id: String { event.eventSerialID }

    // 狀態顏色（業務邏輯）
    var stateColor: Color {
        switch event.event_state {
        case "報名中":
            return Color(hex: "#297FCA")
        case "準備中":
            return Color(hex: "#8E8E93")
        default:
            return Color(hex: "#D32F2F")
        }
    }

    var localizedStateText: LocalizedStringKey {
        switch event.event_state {
        case "報名中": return "Event_State_ok"
        case "準備中": return "Event_State_notyet"
        case "報名已截止": return "Event_State_registerOver"
        default: return "Event_State_done"
        }
    }

    func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded.toggle()
        }
    }
}
