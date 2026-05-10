import Foundation



struct MarqueeAnnouncement {
    let message: String
    let isOpen: Bool
    let isLoop: Bool
    
    static let empty = MarqueeAnnouncement(
        message: "",
        isOpen: false,
        isLoop: false
    )
    
    var displayText: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
