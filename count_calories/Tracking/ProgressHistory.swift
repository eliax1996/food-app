import Foundation

nonisolated struct CalorieProgress: Equatable, Sendable {
    let summaries: [DailyCalorieSummary]
    let averageCalories: Double?
    let goalDifference: Double?
}

nonisolated struct WeightProgressPoint: Equatable, Sendable {
    let date: Date
    let kilograms: Double
    /// Persistent ordering metadata. Nil means a hostless compatibility point.
    let stableID: UUID?
    let sequence: Int64?

    init(
        date: Date,
        kilograms: Double,
        stableID: UUID? = nil,
        sequence: Int64? = nil
    ) {
        self.date = date
        self.kilograms = kilograms
        self.stableID = stableID
        self.sequence = sequence
    }
}

nonisolated struct WeightProgress: Equatable, Sendable {
    let points: [WeightProgressPoint]
    let current: Double?
    let periodChange: Double?
    let targetDistance: Double?
    let domain: ClosedRange<Double>?
}

nonisolated enum ProgressHistory {
    static func calorieProgress(
        summaries: [DailyCalorieSummary],
        dailyGoal: Int?,
        limit: Int = 7
    ) -> CalorieProgress {
        guard limit > 0 else {
            return CalorieProgress(summaries: [], averageCalories: nil, goalDifference: nil)
        }

        let recordedSummaries = Array(
            summaries
                .filter { $0.calories >= 0 }
                .sorted { $0.date < $1.date }
                .suffix(limit)
        )
        guard !recordedSummaries.isEmpty else {
            return CalorieProgress(summaries: [], averageCalories: nil, goalDifference: nil)
        }

        let average = recordedSummaries.reduce(0.0) { total, summary in
            total + Double(summary.calories)
        } / Double(recordedSummaries.count)
        let difference = dailyGoal.flatMap { goal in
            goal > 0 ? average - Double(goal) : nil
        }
        return CalorieProgress(
            summaries: recordedSummaries,
            averageCalories: average,
            goalDifference: difference
        )
    }

    static func weightProgress(
        entries: [WeightProgressPoint],
        targetWeight: Double?,
        limit: Int = 14,
        now: Date = .distantFuture
    ) -> WeightProgress {
        guard limit > 0 else {
            return WeightProgress(
                points: [],
                current: nil,
                periodChange: nil,
                targetDistance: nil,
                domain: nil
            )
        }

        let points = Array(
            WeightHistory.sortedOldestFirst(
                entries.filter { $0.kilograms.isFinite && $0.kilograms > 0 && $0.date <= now }
            )
            .suffix(limit)
        )
        let current = points.last?.kilograms
        let change: Double?
        if let current, let first = points.first, points.count > 1 {
            change = current - first.kilograms
        } else {
            change = nil
        }
        let validTarget = targetWeight.flatMap { target in
            target.isFinite && target > 0 ? target : nil
        }
        let distance = current.flatMap { current in validTarget.map { $0 - current } }
        let domain = points.isEmpty ? nil : adaptiveWeightDomain(
            values: points.map(\.kilograms) + (validTarget.map { [$0] } ?? [])
        )

        return WeightProgress(
            points: points,
            current: current,
            periodChange: change,
            targetDistance: distance,
            domain: domain
        )
    }

    static func adaptiveWeightDomain(values: [Double]) -> ClosedRange<Double>? {
        let values = values.filter { $0.isFinite && $0 > 0 }
        guard let minimum = values.min(), let maximum = values.max() else { return nil }

        let padding = max((maximum - minimum) * 0.2, 0.5)
        return max(0.1, minimum - padding)...(maximum + padding)
    }
}
