import SwiftUI

struct DailyProgressHeader: View {
    let calories: Int
    let calorieGoal: Int
    let waterGlasses: Int
    let waterGoal: Int

    private var calorieProgress: Double {
        min(Double(calories) / Double(calorieGoal), 1)
    }

    private var waterProgress: Double {
        min(Double(waterGlasses) / Double(waterGoal), 1)
    }

    private var calorieStatus: String {
        calories > calorieGoal ? "Exceeded by \(calories - calorieGoal) kcal" : "\(calorieGoal - calories) kcal remaining"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.headline)
                    Text(calorieStatus)
                        .font(.subheadline)
                        .foregroundStyle(calories > calorieGoal ? .red : .secondary)
                }

                Spacer()

                Text("\(Int((Double(calories) / Double(calorieGoal) * 100).rounded()))%")
                    .font(.title.bold())
                    .foregroundStyle(calories > calorieGoal ? .red : .primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: calorieProgress)
                    .tint(calories > calorieGoal ? .red : .orange)
                HStack {
                    Label("\(calories) / \(calorieGoal) kcal", systemImage: "flame.fill")
                        .accessibilityIdentifier("daily-calorie-total")
                    Spacer()
                    Label("\(waterGlasses) / \(waterGoal) water", systemImage: "drop.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ProgressView(value: waterProgress)
                    .tint(.blue)
            }
        }
        .padding(.vertical, 4)
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
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.foodName)
                    .font(.headline)
                Spacer()
                Text(entry.mealType ?? "Snack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(entry.portionQuantity, format: .number.precision(.fractionLength(0...2)))x, \(entry.weightGrams, format: .number.precision(.fractionLength(0...2))) \(entry.nutritionUnit.rawValue), \(entry.calories) kcal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("meal-entry-\(entry.foodName)")
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
                    calorieGoal: 1_700,
                    waterGlasses: 5,
                    waterGoal: 8
                )
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
