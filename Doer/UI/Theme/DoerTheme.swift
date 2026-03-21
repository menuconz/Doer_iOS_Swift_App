import SwiftUI

struct DoerTheme {
    // MARK: - Primary Colors
    static let primary = Color(hex: "#667685")
    static let primaryDark = Color(hex: "#4A5A67")
    static let white = Color.white
    static let black = Color.black

    // MARK: - Status Colors
    static func shiftStatusColor(_ statusId: Int) -> Color {
        switch ShiftStatus.fromValue(statusId) {
        case .created: return Color(hex: "#FFA500")
        case .accepted: return Color(hex: "#2196F3")
        case .ongoing: return Color(hex: "#4CAF50")
        case .completed: return Color(hex: "#8BC34A")
        case .notCompleted: return Color(hex: "#F44336")
        case .finishJob: return Color(hex: "#8BC34A")
        }
    }

    static func shiftStatusText(_ statusId: Int) -> String {
        switch ShiftStatus.fromValue(statusId) {
        case .created: return "Created"
        case .accepted: return "Accepted"
        case .ongoing: return "Ongoing"
        case .completed: return "Completed"
        case .notCompleted: return "Not Completed"
        case .finishJob: return "Finish Job"
        }
    }

    // MARK: - Sub-Item Status Colors
    static func subItemStatusColor(_ status: Int) -> Color {
        switch SubItemStatus.fromValue(status) {
        case .awaitingPrevious: return Color(hex: "#FFA500")
        case .workingOnIt: return Color(hex: "#2196F3")
        case .stuck: return Color(hex: "#F44336")
        case .done: return Color(hex: "#4CAF50")
        }
    }

    // MARK: - HS Required Colors
    static func hsRequiredColor(_ value: Int) -> Color {
        switch HSRequiredStatus.fromValue(value) {
        case .noHS: return Color(hex: "#8E8E93")
        case .sssp: return Color(hex: "#FFA500")
        case .jsa: return Color(hex: "#2196F3")
        case .take5: return Color(hex: "#9C27B0")
        case .done: return Color(hex: "#4CAF50")
        case .missingHS: return Color(hex: "#F44336")
        }
    }

    // MARK: - Lead Status Colors
    static func leadStatusColor(_ statusId: Int) -> Color {
        switch LeadStatus.fromValue(statusId) {
        case .newLead: return Color(hex: "#2196F3")
        case .quoteSent: return Color(hex: "#FFA500")
        case .won: return Color(hex: "#4CAF50")
        case .contacted: return Color(hex: "#9C27B0")
        case .quoteExpired: return Color(hex: "#F44336")
        case .drafted: return Color(hex: "#8E8E93")
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static func fromHexString(_ hexString: String) -> Color? {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !hex.isEmpty else { return nil }
        return Color(hex: hexString)
    }
}
