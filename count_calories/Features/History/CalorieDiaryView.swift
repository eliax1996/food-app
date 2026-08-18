import SwiftUI

struct CalorieDiaryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let days: [CalorieDiaryDay]
    @State private var selectedDate: Date

    init(days: [CalorieDiaryDay], initialDate: Date) {
        self.days = days
        _selectedDate = State(initialValue: initialDate)
    }

    private var selectedDay: CalorieDiaryDay? {
        days.first { $0.date == selectedDate }
    }

    private var adjacentDays: (previous: CalorieDiaryDay?, next: CalorieDiaryDay?) {
        CalorieDiary.adjacentDays(to: selectedDate, in: days)
    }

    var body: some View {
        List {
            Section {
                dayHeader
            }

            if let selectedDay {
                ForEach(selectedDay.mealGroups) { group in
                    Section(group.mealType) {
                        ForEach(group.records) { record in
                            CalorieDiaryEntryRow(record: record)
                        }
                        mealTotal(group.calorieTotal)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No recorded foods",
                    systemImage: "fork.knife",
                    description: Text("Choose another recorded day from Progress.")
                )
                .accessibilityIdentifier("calorie-diary-empty")
            }
        }
        .navigationTitle("Food Diary")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("calorie-diary")
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("calorie-diary-date")

            if let selectedDay {
                if selectedDay.calorieTotal.isComplete {
                    Text("\(selectedDay.calorieTotal.calories.formatted()) kcal")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .accessibilityIdentifier("calorie-diary-total")
                } else {
                    Label("Calorie total incomplete", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("calorie-diary-total-incomplete")
                    Text("Known entries total \(selectedDay.calorieTotal.calories.formatted()) kcal. One or more logged foods has invalid legacy calorie data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(entryCountText(selectedDay.entryCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("calorie-diary-entry-count")
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    dayNavigationButton(
                        title: "Previous Recorded Day",
                        systemImage: "chevron.left",
                        day: adjacentDays.previous
                    )
                    dayNavigationButton(
                        title: "Next Recorded Day",
                        systemImage: "chevron.right",
                        day: adjacentDays.next
                    )
                }
            } else {
                HStack(spacing: 12) {
                    dayNavigationButton(
                        title: "Previous",
                        systemImage: "chevron.left",
                        day: adjacentDays.previous
                    )
                    dayNavigationButton(
                        title: "Next",
                        systemImage: "chevron.right",
                        day: adjacentDays.next
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayNavigationButton(
        title: String,
        systemImage: String,
        day: CalorieDiaryDay?
    ) -> some View {
        Button {
            guard let day else { return }
            selectedDate = day.date
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(day == nil)
        .accessibilityValue(day?.date.formatted(date: .complete, time: .omitted) ?? "No recorded day")
        .accessibilityIdentifier(systemImage == "chevron.left"
            ? "calorie-diary-previous-day"
            : "calorie-diary-next-day")
    }

    private func mealTotal(_ total: FoodCalorieTotal) -> some View {
        HStack {
            Text(total.isComplete ? "Meal total" : "Meal total incomplete")
                .foregroundStyle(.secondary)
            Spacer()
            Text(total.isComplete ? "\(total.calories.formatted()) kcal" : "Unavailable")
                .fontWeight(.semibold)
                .foregroundStyle(total.isComplete ? Color.primary : Color.orange)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private func entryCountText(_ count: Int) -> String {
        count == 1 ? "1 logged food" : "\(count) logged foods"
    }
}

private struct CalorieDiaryEntryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: CalorieDiaryRecord

    private var hasValidCalories: Bool {
        FoodCaloriePolicy.isValid(record.calories)
    }

    private var servingText: String {
        guard record.loggedAmount.isFinite, record.loggedAmount > 0 else { return "Amount unavailable" }
        let amount = record.loggedAmount.formatted(.number.precision(.fractionLength(0...2)))
        let unit = record.unitRawValue
        guard record.portionCount.isFinite, record.portionCount > 0 else {
            return "\(amount) \(unit)"
        }
        let portions = record.portionCount.formatted(.number.precision(.fractionLength(0...2)))
        if abs(record.portionCount - 1) < 0.000_001 {
            return "1× · \(amount) \(unit)"
        }
        return "\(portions)× · \(amount) \(unit) each"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    entryDescription
                    calorieLabel
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    entryDescription
                    Spacer(minLength: 8)
                    calorieLabel
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.foodName)
        .accessibilityValue(hasValidCalories
            ? "\(servingText), logged at \(record.date.formatted(date: .omitted, time: .shortened)), \(record.calories) calories"
            : "\(servingText), logged at \(record.date.formatted(date: .omitted, time: .shortened)), calorie value unavailable")
        .accessibilityIdentifier("calorie-diary-entry-\(record.id.uuidString)")
    }

    private var entryDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.foodName)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(servingText) · \(record.date.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var calorieLabel: some View {
        if hasValidCalories {
            Text("\(record.calories.formatted()) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        } else {
            Label("Unavailable", systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }
}

#if DEBUG
#Preview("Historical food diary") {
    NavigationStack {
        CalorieDiaryView(
            days: CalorieDiary.days(from: [
                CalorieDiaryRecord(
                    id: UUID(),
                    date: .now.addingTimeInterval(-86_400),
                    mealType: "Breakfast",
                    foodName: "Oatmeal with Blueberries",
                    calories: 360,
                    loggedAmount: 280,
                    portionCount: 1,
                    unitRawValue: "g"
                ),
                CalorieDiaryRecord(
                    id: UUID(),
                    date: .now.addingTimeInterval(-82_800),
                    mealType: "Lunch",
                    foodName: "Grilled Chicken & Quinoa Bowl",
                    calories: 540,
                    loggedAmount: 420,
                    portionCount: 1,
                    unitRawValue: "g"
                )
            ]),
            initialDate: Calendar.current.startOfDay(for: .now.addingTimeInterval(-86_400))
        )
    }
}
#endif
