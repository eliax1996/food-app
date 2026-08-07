import Charts
import SwiftUI

enum HistoryMetric: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case weight = "Weight"

    var id: String { rawValue }
}

struct HistogramItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct HistogramChart: View {
    let items: [HistogramItem]
    let unit: String
    let tint: Color

    private var maxValue: Double {
        max(items.map(\.value).max() ?? 1, 1)
    }

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView("No data yet", systemImage: "chart.xyaxis.line")
        } else {
            Chart(items) { item in
                BarMark(
                    x: .value("Day", item.label),
                    y: .value(unit, item.value)
                )
                .foregroundStyle(tint.gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(valueLabel(for: item.value))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: 0...(maxValue * 1.15))
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 240)
            .padding(.vertical, 8)
        }
    }

    private func valueLabel(for value: Double) -> String {
        if unit == "kg" {
            return value.formatted(.number.precision(.fractionLength(1)))
        }

        return Int(value.rounded()).formatted()
    }
}

#if DEBUG
#Preview("Calorie histogram") {
    List {
        HistogramChart(
            items: [
                HistogramItem(label: "Mon", value: 1_420),
                HistogramItem(label: "Tue", value: 1_680),
                HistogramItem(label: "Wed", value: 1_510),
                HistogramItem(label: "Thu", value: 1_735)
            ],
            unit: "kcal",
            tint: .orange
        )
    }
}
#endif
