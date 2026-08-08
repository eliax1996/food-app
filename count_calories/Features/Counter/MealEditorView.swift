import SwiftUI

struct MealEditorView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let foods: [Food]
    let recentFoods: [Food]
    let isEditing: Bool
    @Binding var selectedMeal: MealType
    @Binding var selectedFood: Food?
    @Binding var searchText: String
    @Binding var amount: Double
    @Binding var portionCount: Double
    let calories: Int
    let onCancel: () -> Void
    let onScanBarcode: () -> Void
    let onSave: () -> Void

    private let commonServingCounts = [0.5, 1, 1.5, 2]

    private var amountUnit: NutritionUnit {
        selectedFood?.nutritionUnit ?? .grams
    }

    private var servingDescription: String {
        guard let selectedFood else { return "Choose a food" }
        let amount = selectedFood.servingGrams.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return "\(selectedFood.calories) kcal per \(amount) \(selectedFood.nutritionUnit.rawValue)"
    }

    private var selectedServingPreset: String {
        servingPresetLabel(portionCount)
    }

    private func servingPresetLabel(_ count: Double) -> String {
        let amount = count.formatted(.number.precision(.fractionLength(0...1)))
        return count == 1 ? "\(amount) serving" : "\(amount) servings"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    if dynamicTypeSize.isAccessibilitySize {
                        Menu {
                            ForEach(MealType.allCases) { meal in
                                Button {
                                    selectedMeal = meal
                                } label: {
                                    if selectedMeal == meal {
                                        Label(meal.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(meal.rawValue)
                                    }
                                }
                            }
                        } label: {
                            LabeledContent("Meal") {
                                HStack(spacing: 6) {
                                    Text(selectedMeal.rawValue)
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel("Meal type")
                        .accessibilityValue(selectedMeal.rawValue)
                    } else {
                        Picker("Meal", selection: $selectedMeal) {
                            ForEach(MealType.allCases) { meal in
                                Text(meal.rawValue).tag(meal)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Meal type")
                    }
                }

                Section("Food") {
                    NavigationLink {
                        FoodSearchView(
                            foods: foods,
                            recentFoods: recentFoods,
                            selectedFood: $selectedFood,
                            searchText: $searchText,
                            amount: $amount
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedFood?.name ?? "Choose food")
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .accessibilityIdentifier("selected-food-name")
                            Text(servingDescription)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary.opacity(0.65))
                        }
                    }
                    .accessibilityIdentifier("choose-food")

                    Button(action: onScanBarcode) {
                        Label("Scan barcode", systemImage: "barcode.viewfinder")
                    }
                }

                Section("Serving") {
                    LabeledContent(amountUnit == .milliliters ? "Volume" : "Amount") {
                        HStack(spacing: 6) {
                            TextField(
                                amountUnit == .milliliters ? "Milliliters" : "Grams",
                                value: $amount,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 88)
                            .accessibilityLabel(amountUnit == .milliliters ? "Volume in milliliters" : "Amount in grams")

                            Text(amountUnit.rawValue)
                                .foregroundStyle(Color.primary.opacity(0.65))
                        }
                    }

                    LabeledContent("Servings") {
                        TextField(
                            "Servings",
                            value: $portionCount,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 88)
                        .accessibilityLabel("Serving count")
                        .accessibilityIdentifier("meal-quantity")
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        Menu {
                            ForEach(commonServingCounts, id: \.self) { count in
                                Button {
                                    portionCount = count
                                } label: {
                                    if portionCount == count {
                                        Label(servingPresetLabel(count), systemImage: "checkmark")
                                    } else {
                                        Text(servingPresetLabel(count))
                                    }
                                }
                            }
                        } label: {
                            LabeledContent("Serving presets") {
                                HStack(spacing: 6) {
                                    Text(selectedServingPreset)
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel("Serving presets")
                        .accessibilityValue(selectedServingPreset)
                    } else {
                        Picker("Serving presets", selection: $portionCount) {
                            ForEach(commonServingCounts, id: \.self) { count in
                                Text(count.formatted(.number.precision(.fractionLength(0...1))))
                                    .tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Serving presets")
                    }
                }

                Section {
                    LabeledContent("Total") {
                        Text("\(calories) kcal")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Calculated total")
                    .accessibilityValue("\(calories) calories")
                    .accessibilityIdentifier("calculated-total")
                } footer: {
                    Text("Total updates with amount and serving count.")
                }
            }
            .navigationTitle(isEditing ? "Edit food" : "Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancel-meal")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: onSave)
                        .disabled(selectedFood == nil || amount <= 0 || portionCount <= 0)
                        .accessibilityIdentifier("save-meal")
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("meal-editor")
    }
}

private struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let foods: [Food]
    let recentFoods: [Food]
    @Binding var selectedFood: Food?
    @Binding var searchText: String
    @Binding var amount: Double

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredFoods: [Food] {
        guard !trimmedSearch.isEmpty else { return foods }
        return foods.filter { food in
            food.name.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    private var uniqueRecentFoods: [Food] {
        var seenNames = Set<String>()
        return recentFoods.filter { food in
            seenNames.insert(food.name.lowercased()).inserted
        }
    }

    var body: some View {
        List {
            if trimmedSearch.isEmpty, !uniqueRecentFoods.isEmpty {
                Section("Recently logged") {
                    ForEach(uniqueRecentFoods.prefix(5)) { food in
                        foodButton(food)
                    }
                }
            }

            Section(trimmedSearch.isEmpty ? "All foods" : "Results") {
                if filteredFoods.isEmpty {
                    ContentUnavailableView.search(text: trimmedSearch)
                } else {
                    ForEach(filteredFoods) { food in
                        foodButton(food)
                    }
                }
            }
        }
        .navigationTitle("Choose food")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search foods"
        )
    }

    private func foodButton(_ food: Food) -> some View {
        Button {
            selectedFood = food
            amount = food.servingGrams
            dismiss()
        } label: {
            FoodSelectionRow(
                food: food,
                isSelected: selectedFood.map { $0 === food } ?? false
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("food-result-\(food.name)")
    }
}

#if DEBUG
private struct MealEditorPreview: View {
    private let foods: [Food]
    @State private var selectedMeal = MealType.breakfast
    @State private var selectedFood: Food?
    @State private var searchText = ""
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
            recentFoods: Array(foods.prefix(2)),
            isEditing: false,
            selectedMeal: $selectedMeal,
            selectedFood: $selectedFood,
            searchText: $searchText,
            amount: $amount,
            portionCount: $portionCount,
            calories: calories,
            onCancel: {},
            onScanBarcode: {},
            onSave: {}
        )
    }
}

#Preview("Meal editor") {
    MealEditorPreview()
}
#endif
