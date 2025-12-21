import SwiftUI



@MainActor
final class EventRegistration_Tab2_ListViewModel: ObservableObject, @preconcurrency Identifiable {
    @Published var isExpanded: Bool = false
    let event: EventData_Apply
    
    init(event: EventData_Apply) {
        self.event = event
    }

    var id: String { event.eventSerialID }

    // 狀態顏色（業務邏輯）
    var stateColor: Color {
        switch event.event_state {
        case "修改資料／取消報名":
            return Color(hex: "#297FCA")
        default:
            return Color(hex: "#D32F2F")
        }
    }

    var localizedStateText: LocalizedStringKey {
        switch event.event_state {
        case "修改資料／取消報名": return "Event_State_ok"
        case "報名已截止": return "Event_State_registerOver"
        case "活動已結束": return "Event_State_done"
        default: return "Event_State_done"
        }
    }

    func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isExpanded.toggle()
        }
    }
}
