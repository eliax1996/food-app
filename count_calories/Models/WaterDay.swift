import Foundation
import SwiftData

@Model
final class WaterDay {
    var date: Date
    var glasses: Int
    var lastRecordedAt: Date?

    init(date: Date, glasses: Int = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.glasses = glasses
        lastRecordedAt = glasses > 0 ? date : nil
    }
}
