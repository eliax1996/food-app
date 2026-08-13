import SwiftUI

struct DailyProgressHeader: View {
    let calories: Int
    let calorieGoal: Int

    private var safeGoal: Int {
        max(calorieGoal, 1)
    }

    private var calorieProgress: Double {
        min(max(Double(calories) / Double(safeGoal), 0), 1)
    }

    private var statusValue: Int {
        abs(calorieGoal - calories)
    }

    private var statusLabel: String {
        calories > calorieGoal ? "kcal over goal" : "kcal remaining"
    }

    private var statusColor: Color {
        calories > calorieGoal ? .red : .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    statusText
                    statusDescription
                }

                VStack(alignment: .leading, spacing: 2) {
                    statusText
                    statusDescription
                }
            }

            ProgressView(value: calorieProgress)
                .tint(calories > calorieGoal ? .red : .orange)
                .accessibilityHidden(true)

            HStack {
                calorieMetric(title: "Eaten", value: calories)

                Spacer()

                calorieMetric(title: "Daily goal", value: calorieGoal)
                    .multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily calories")
        .accessibilityValue("\(calories) eaten, \(statusValue) \(statusLabel), daily goal \(calorieGoal)")
        .accessibilityIdentifier("daily-calorie-total")
    }

    private var statusText: some View {
        Text(statusValue, format: .number)
            .font(.largeTitle.bold())
            .monospacedDigit()
            .foregroundStyle(statusColor)
            .contentTransition(.numericText())
    }

    private var statusDescription: some View {
        Text(statusLabel)
            .font(.headline)
            .foregroundStyle(calories > calorieGoal ? Color.red : Color.primary.opacity(0.65))
    }

    private func calorieMetric(title: String, value: Int) -> some View {
        VStack(alignment: title == "Eaten" ? .leading : .trailing, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.65))
            Text("\(value.formatted()) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct WaterTrackerRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var glasses: Int
    let goal: Int

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    waterSummary
                    waterControls
                }
            } else {
                HStack(spacing: 16) {
                    waterSummary
                    Spacer(minLength: 8)
                    waterControls
                }
            }
        }
    }

    private var waterSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Water", systemImage: "drop.fill")
                .font(.headline)
                .foregroundStyle(.blue)
            Text("\(glasses) of \(goal) glasses")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.65))
                .monospacedDigit()
        }
    }

    private var waterControls: some View {
        HStack(spacing: 8) {
            Button {
                glasses = max(0, glasses - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove glass")
            .disabled(glasses == 0)

            Button {
                glasses = min(30, glasses + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.blue, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add glass")
            .disabled(glasses == 30)
        }
        .accessibilityElement(children: .contain)
    }
}

struct MealSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mealType: MealType
    let entries: [PlateEntry]
    let calories: Int

    private var detail: String {
        switch entries.count {
        case 0:
            "Nothing logged"
        case 1:
            entries[0].foodName
        default:
            "\(entries.count) foods logged"
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        title
                        detailText
                    }

                    Spacer(minLength: 8)
                    calorieText
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    title
                    detailText
                    Spacer(minLength: 4)
                    calorieText
                }
                .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mealType.rawValue)
        .accessibilityValue("\(detail), \(calories) calories")
    }

    private var title: some View {
        Text(mealType.rawValue)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
    }

    private var detailText: some View {
        Text(detail)
            .font(.subheadline)
            .foregroundStyle(Color.primary.opacity(0.65))
            .lineLimit(1)
    }

    @ViewBuilder
    private var calorieText: some View {
        if calories > 0 {
            Text("\(calories) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

struct MealDetailView: View {
    let mealType: MealType
    let entries: [PlateEntry]
    let onAdd: () -> Void
    let onEdit: (PlateEntry) -> Void
    let onDelete: (PlateEntry) -> Void

    @State private var pendingDeletion: PlateEntry?

    var body: some View {
        List {
            if entries.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "Nothing logged for \(mealType.rawValue.lowercased())",
                        systemImage: mealType.systemImage,
                        description: Text("Log food when you're ready.")
                    )
                    Button("Log food", action: onAdd)
                        .accessibilityIdentifier("meal-detail-add-food")
                }
            } else {
                ForEach(entries) { entry in
                    Button {
                        onEdit(entry)
                    } label: {
                        MealEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeletion = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            onEdit(entry)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle(mealType.rawValue)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) {
                    Label("Log food", systemImage: "plus")
                }
            }
        }
        .alert(
            "Delete \(pendingDeletion?.foodName ?? "food")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let pendingDeletion else { return }
                self.pendingDeletion = nil
                onDelete(pendingDeletion)
            }
            .accessibilityIdentifier("confirm-delete-meal")
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("This removes the logged food from \(mealType.rawValue.lowercased()).")
        }
    }
}

struct FoodSelectionRow: View {
    let food: Food
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .foregroundStyle(.primary)
                Text("\(food.calories) kcal / \(food.servingGrams, format: .number.precision(.fractionLength(0...2))) \(food.nutritionUnit.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Color.primary.opacity(0.65))
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct MealEntryRow: View {
    let entry: PlateEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(servingDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.65))
            }

            Spacer(minLength: 8)

            Text("\(entry.calories) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.foodName)
        .accessibilityValue("\(servingDescription), \(entry.calories) calories")
        .accessibilityHint("Swipe for edit or delete actions")
        .accessibilityIdentifier("meal-entry-\(entry.foodName)")
    }

    private var servingDescription: String {
        let amount = entry.weightGrams.formatted(
            .number.precision(.fractionLength(0...2))
        )
        let quantity = entry.portionQuantity.formatted(
            .number.precision(.fractionLength(0...2))
        )
        if entry.portionQuantity == 1 {
            return "1× · \(amount) \(entry.nutritionUnit.rawValue)"
        }
        return "\(quantity)× · \(amount) \(entry.nutritionUnit.rawValue) each"
    }
}

#if DEBUG
private struct CounterComponentsPreview: View {
    private let almondMilk = Food(name: "Almond Milk", calories: 15, servingGrams: 100)
    private let meal = PlateEntry(
        foodName: "Almond Milk",
        calories: 15,
        weightGrams: 100,
        quantity: 1,
        mealType: MealType.breakfast.rawValue
    )

    var body: some View {
        List {
            Section("Daily progress") {
                DailyProgressHeader(
                    calories: 1_280,
                    calorieGoal: 1_700
                )
                WaterTrackerRow(glasses: .constant(5), goal: 8)
            }

            Section("Food selection") {
                FoodSelectionRow(food: almondMilk, isSelected: true)
            }

            Section("Recorded meal") {
                MealEntryRow(entry: meal)
            }
        }
    }
}

#Preview("Counter components") {
    CounterComponentsPreview()
}
#endif
