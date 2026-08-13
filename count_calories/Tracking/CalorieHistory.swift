import Foundation

nonisolated struct CalorieRecord: Equatable, Sendable {
    let date: Date
    let calories: Int
}

nonisolated struct DailyCalorieSummary: Equatable, Sendable {
    let date: Date
    let calories: Int
    let caloriesAreComplete: Bool

    init(date: Date, calories: Int, caloriesAreComplete: Bool = true) {
        self.date = date
        self.calories = calories
        self.caloriesAreComplete = caloriesAreComplete
    }
}

nonisolated enum CalorieHistory {
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
            let total = CalorieCalculator.assessedTotal(dayRecords.map(\.calories))
            return DailyCalorieSummary(
                date: date,
                calories: total.calories,
                caloriesAreComplete: total.isComplete
            )
        }

        return Array(summaries.sorted { $0.date < $1.date }.suffix(limit))
    }
}
