import Foundation

struct CalorieRecord: Equatable, Sendable {
    let date: Date
    let calories: Int
}

struct DailyCalorieSummary: Equatable, Sendable {
    let date: Date
    let calories: Int
}

enum CalorieHistory {
    static func dailySummaries(
        for records: [CalorieRecord],
        calendar: Calendar = .current,
        limit: Int = 14
    ) -> [DailyCalorieSummary] {
        guard limit > 0 else { return [] }

        let groupedRecords = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
        let summaries = groupedRecords.map { date, dayRecords in
            DailyCalorieSummary(
                date: date,
                calories: dayRecords.reduce(0) { $0 + $1.calories }
            )
        }

        return Array(summaries.sorted { $0.date < $1.date }.suffix(limit))
    }
}
