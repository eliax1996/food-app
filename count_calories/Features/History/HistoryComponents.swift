import Charts
import SwiftUI

enum HistoryMetric: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case weight = "Weight"

    var id: String { rawValue }
}

struct CalorieProgressChart: View {
    let progress: CalorieProgress
    let dailyGoal: Int?

    private var chartMaximum: Double {
        let values = progress.summaries.map { Double($0.calories) }
        let goal = dailyGoal.map(Double.init) ?? 0
        return max(values.max() ?? 0, goal, 1) * 1.15
    }

    var body: some View {
        Chart {
            ForEach(progress.summaries, id: \.date) { summary in
                BarMark(
                    x: .value("Day", summary.date, unit: .day),
                    y: .value("Calories", summary.calories)
                )
                .foregroundStyle(Color.orange.gradient)
                .cornerRadius(4)
            }

            if let dailyGoal, dailyGoal > 0 {
                RuleMark(y: .value("Daily goal", dailyGoal))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: 0...chartMaximum)
        .chartXAxis {
            AxisMarks(values: progress.summaries.map(\.date)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine()
                AxisValueLabel(format: IntegerFormatStyle<Int>.number.notation(.compactName))
            }
        }
        .frame(height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(calorieAccessibilitySummary)
        .accessibilityIdentifier("progress-calorie-chart")
    }

    private var calorieAccessibilitySummary: String {
        let count = progress.summaries.count
        let dayLabel = count == 1 ? "recorded day" : "recorded days"
        let average = progress.averageCalories?.formatted(.number.precision(.fractionLength(0))) ?? "no"
        return "Calories trend for \(count) \(dayLabel). Average \(average) calories."
    }
}

struct WeightProgressChart: View {
    let progress: WeightProgress
    let targetWeight: Double?

    var body: some View {
        Chart {
            ForEach(Array(progress.points.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Weight", point.kilograms)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.linear)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Weight", point.kilograms)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(28)
            }

            if let targetWeight, targetWeight.isFinite, targetWeight > 0 {
                RuleMark(y: .value("Target", targetWeight))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: progress.domain ?? 0.1...1)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine()
                AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)))
            }
        }
        .frame(height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weightAccessibilitySummary)
        .accessibilityIdentifier("progress-weight-chart")
    }

    private var weightAccessibilitySummary: String {
        let count = progress.points.count
        let weightLabel = count == 1 ? "recorded weight" : "recorded weights"
        let current = progress.current.map { "Current \($0.formatted(.number.precision(.fractionLength(1)))) kilograms." } ?? ""
        return "Weight trend with \(count) \(weightLabel). \(current)"
    }
}
