import Foundation

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    static var suggestedForCurrentTime: MealType {
        suggested(at: .now)
    }

    static func suggested(at date: Date, calendar: Calendar = .current) -> MealType {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        case 16..<21:
            return .dinner
        default:
            return .snack
        }
    }
}
