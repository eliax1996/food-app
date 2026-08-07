import SwiftUI

struct MealEditorView: View {
    let foods: [Food]
    let isEditing: Bool
    @Binding var selectedMeal: MealType
    @Binding var selectedFood: Food?
    @Binding var searchText: String
    @Binding var showingFoodFilter: Bool
    @Binding var amount: Double
    @Binding var portionCount: Double
    let calories: Int
    let onCancel: () -> Void
    let onSave: () -> Void

    private var amountUnit: NutritionUnit {
        selectedFood?.nutritionUnit ?? .grams
    }

    private var amountSliderUpperBound: Double {
        max(amountUnit == .milliliters ? 1_000 : 500, amount)
    }

    private var filteredFoods: [Food] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return foods }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var visibleFoods: [Food] {
        Array(filteredFoods.prefix(5))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Picker("Type", selection: $selectedMeal) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.rawValue).tag(meal)
                        }
                    }
                }

                Section("Food") {
                    Button {
                        showingFoodFilter.toggle()
                    } label: {
                        HStack {
                            Text("Food")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(selectedFood?.name ?? "Select food")
                                .foregroundStyle(.secondary)
                            Image(systemName: showingFoodFilter ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showingFoodFilter {
                        TextField("Filter foods", text: $searchText)

                        if filteredFoods.isEmpty {
                            ContentUnavailableView("No matching foods", systemImage: "magnifyingglass")
                        } else {
                            ForEach(visibleFoods) { food in
                                Button {
                                    selectFood(food)
                                } label: {
                                    FoodSelectionRow(
                                        food: food,
                                        isSelected: selectedFood.map { $0 === food } ?? false
                                    )
                                }
                            }
                        }
                    }
                }

                Section("Amount") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(amountUnit == .milliliters ? "Volume" : "Weight")
                            Spacer()
                            TextField(
                                amountUnit == .milliliters ? "Milliliters" : "Grams",
                                value: $amount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 84)
                            Text(amountUnit.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $amount, in: 1...amountSliderUpperBound, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField(
                                "Quantity",
                                value: $portionCount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 84)
                            .accessibilityIdentifier("meal-quantity")
                        }

                        HStack {
                            Text("¼")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(
                                value: Binding(
                                    get: { min(max(portionCount, 0.25), 4) },
                                    set: { portionCount = $0 }
                                ),
                                in: 0.25...4,
                                step: 0.25
                            )
                            .accessibilityIdentifier("meal-quantity-slider")
                            Text("4")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Label("\(calories) kcal", systemImage: "fork.knife")
                }
            }
            .navigationTitle(isEditing ? "Edit \(selectedMeal.rawValue)" : "Add \(selectedMeal.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: onSave)
                        .disabled(selectedFood == nil || amount <= 0 || portionCount <= 0)
                        .accessibilityIdentifier("save-meal")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func selectFood(_ food: Food) {
        selectedFood = food
        amount = food.servingGrams
        showingFoodFilter = false
    }
}

#if DEBUG
private struct MealEditorPreview: View {
    private let foods: [Food]
    @State private var selectedMeal = MealType.breakfast
    @State private var selectedFood: Food?
    @State private var searchText = ""
    @State private var showingFoodFilter = true
    @State private var amount = 100.0
    @State private var portionCount = 1.0

    init() {
        let almondMilk = Food(name: "Almond Milk", calories: 15, servingGrams: 100)
        foods = [
            almondMilk,
            Food(name: "Apple", calories: 52, servingGrams: 100),
            Food(name: "Banana", calories: 89, servingGrams: 100)
        ]
        _selectedFood = State(initialValue: almondMilk)
    }

    private var calories: Int {
        guard let selectedFood else { return 0 }
        return CalorieCalculator.calories(
            caloriesPerServing: selectedFood.calories,
            servingAmount: selectedFood.servingGrams,
            consumedAmount: amount,
            portionCount: portionCount
        )
    }

    var body: some View {
        MealEditorView(
            foods: foods,
            isEditing: false,
            selectedMeal: $selectedMeal,
            selectedFood: $selectedFood,
            searchText: $searchText,
            showingFoodFilter: $showingFoodFilter,
            amount: $amount,
            portionCount: $portionCount,
            calories: calories,
            onCancel: {},
            onSave: {}
        )
    }
}

#Preview("Meal editor") {
    MealEditorPreview()
}
#endif
