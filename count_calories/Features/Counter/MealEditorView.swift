import SwiftUI
import UIKit

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
    let remoteSearch: RemoteFoodSearchCoordinator?
    let onSelectRemoteFood: (FoodNutrition) -> Bool
    let onCancel: () -> Void
    let onScanBarcode: () -> Void
    let onSave: () -> Void

    private let commonServingCounts = [0.5, 1, 1.5, 2]

    private struct AmountAdjustment: Identifiable {
        let title: String
        let delta: Double
        let identifier: String

        var id: String { identifier }
    }

    private let amountAdjustments = [
        AmountAdjustment(title: "−10", delta: -10, identifier: "amount-decrease-10"),
        AmountAdjustment(title: "−1", delta: -1, identifier: "amount-decrease-1"),
        AmountAdjustment(title: "+1", delta: 1, identifier: "amount-increase-1"),
        AmountAdjustment(title: "+10", delta: 10, identifier: "amount-increase-10")
    ]

    private var amountUnit: NutritionUnit {
        selectedFood?.nutritionUnit ?? .grams
    }

    private var amountNoun: String {
        amountUnit == .milliliters ? "volume" : "amount"
    }

    private var amountUnitSingular: String {
        amountUnit == .milliliters ? "milliliter" : "gram"
    }

    private var amountAccessibilityValue: String {
        let formattedAmount = amount.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return "\(formattedAmount) \(amountUnitName(for: amount))"
    }

    private var canSave: Bool {
        selectedFood != nil
            && FoodAmountAdjustment.isValid(amount)
            && portionCount.isFinite
            && portionCount > 0
    }

    private func amountUnitName(for value: Double) -> String {
        abs(value) == 1 ? amountUnitSingular : "\(amountUnitSingular)s"
    }

    private func amountAdjustmentAccessibilityLabel(
        for adjustment: AmountAdjustment
    ) -> String {
        let action = adjustment.delta < 0 ? "Decrease" : "Increase"
        let magnitude = abs(adjustment.delta)
        let formattedMagnitude = magnitude.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return "\(action) \(amountNoun) by \(formattedMagnitude) \(amountUnitName(for: magnitude))"
    }

    @ViewBuilder
    private var amountAdjustmentControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(amountAdjustments) { adjustment in
                    amountAdjustmentButton(adjustment)
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(amountAdjustments) { adjustment in
                    amountAdjustmentButton(adjustment)
                }
            }
        }
    }

    private func amountAdjustmentButton(_ adjustment: AmountAdjustment) -> some View {
        let result = FoodAmountAdjustment.result(for: amount, delta: adjustment.delta)

        return Button {
            guard let result = FoodAmountAdjustment.result(for: amount, delta: adjustment.delta) else {
                return
            }
            amount = result
        } label: {
            Text(adjustment.title)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, minHeight: 44)
        .disabled(result == nil)
        .accessibilityLabel(amountAdjustmentAccessibilityLabel(for: adjustment))
        .accessibilityValue("Current \(amountAccessibilityValue)")
        .accessibilityHint("Changes \(amountNoun) only; serving count stays unchanged.")
        .accessibilityIdentifier(adjustment.identifier)
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
                            amount: $amount,
                            remoteSearch: remoteSearch,
                            onSelectRemoteFood: onSelectRemoteFood
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
                            .accessibilityValue(amountAccessibilityValue)
                            .accessibilityIdentifier("meal-amount")

                            Text(amountUnit.rawValue)
                                .foregroundStyle(Color.primary.opacity(0.65))
                        }
                    }

                    amountAdjustmentControls

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
                    Button(isEditing ? "Save" : "Add") {
                        guard canSave else { return }
                        onSave()
                    }
                    .disabled(!canSave)
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
    @Environment(\.dismissSearch) private var dismissSearch

    let foods: [Food]
    let recentFoods: [Food]
    @Binding var selectedFood: Food?
    @Binding var searchText: String
    @Binding var amount: Double
    let remoteSearch: RemoteFoodSearchCoordinator?
    let onSelectRemoteFood: (FoodNutrition) -> Bool

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSearch: String {
        FoodSearchQuery.normalize(searchText)
    }

    private var filteredFoods: [Food] {
        guard !trimmedSearch.isEmpty else { return foods }
        return foods.filter { food in
            food.name.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    private var localCandidates: [FoodSearchLocalCandidate] {
        filteredFoods.map { FoodSearchLocalCandidate(barcode: $0.barcode) }
    }

    private var uniqueRecentFoods: [Food] {
        var seenNames = Set<String>()
        return recentFoods.filter { food in
            seenNames.insert(food.name.lowercased()).inserted
        }
    }

    private var canSearchRemote: Bool {
        normalizedSearch.count >= 3
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

            Section(trimmedSearch.isEmpty ? "All foods" : "Saved foods") {
                if filteredFoods.isEmpty, canSearchRemote {
                    Text("No saved foods match.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if filteredFoods.isEmpty {
                    ContentUnavailableView.search(text: trimmedSearch)
                } else {
                    ForEach(filteredFoods) { food in
                        foodButton(food)
                    }
                }
            }

            if canSearchRemote, let remoteSearch {
                Section("Open Food Facts") {
                    if remoteSearch.foods.isEmpty, !remoteSearch.isLoading, remoteSearch.errorMessage == nil {
                        Text("Search Open Food Facts for matching products.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(remoteSearch.foods) { food in
                        remoteFoodButton(food)
                    }

                    if remoteSearch.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Searching Open Food Facts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Searching Open Food Facts")
                    }

                    if let errorMessage = remoteSearch.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            Button("Retry Open Food Facts") {
                                remoteSearch.loadMore(query: searchText, localCandidates: localCandidates)
                            }
                            .accessibilityIdentifier("retry-open-food-facts")
                        }
                    }

                    Button(remoteSearch.foods.isEmpty ? "Search Open Food Facts" : "Load more from Open Food Facts") {
                        remoteSearch.loadMore(query: searchText, localCandidates: localCandidates)
                    }
                    .disabled(remoteSearch.isLoading)
                    .accessibilityIdentifier("search-open-food-facts")

                    Link("Data from Open Food Facts", destination: URL(string: "https://world.openfoodfacts.org")!)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Open Food Facts attribution")
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
        .onAppear {
            remoteSearch?.update(query: searchText, localCandidates: localCandidates)
        }
        .onChange(of: searchText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidates = foods
                .filter { food in
                    trimmed.isEmpty || food.name.localizedCaseInsensitiveContains(trimmed)
                }
                .map { FoodSearchLocalCandidate(barcode: $0.barcode) }
            remoteSearch?.update(query: newValue, localCandidates: candidates)
        }
        .onDisappear {
            remoteSearch?.cancel()
        }
    }

    private func foodButton(_ food: Food) -> some View {
        Button {
            selectedFood = food
            amount = food.servingGrams
            finishSelection()
        } label: {
            FoodSelectionRow(
                food: food,
                isSelected: selectedFood.map { $0 === food } ?? false
            )
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("food-result-\(food.name)")
    }

    private func finishSelection() {
        dismissSearch()
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            dismiss()
        }
    }

    private func remoteFoodButton(_ food: FoodNutrition) -> some View {
        Button {
            if onSelectRemoteFood(food) {
                finishSelection()
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .foregroundStyle(.primary)
                Text("\(Int(food.caloriesPer100.rounded())) kcal / 100 \(food.defaultAmount.unit.rawValue) · \(food.defaultAmount.value.formatted(.number.precision(.fractionLength(0...2)))) \(food.defaultAmount.unit.rawValue) serving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(food.name), Open Food Facts result")
        .accessibilityValue(
            "\(Int(food.calories(for: food.defaultAmount.value).rounded())) calories per \(food.defaultAmount.value.formatted(.number.precision(.fractionLength(0...2)))) \(food.defaultAmount.unit.rawValue) serving"
        )
        .accessibilityIdentifier("remote-food-result-\(food.barcode)")
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
            remoteSearch: nil,
            onSelectRemoteFood: { _ in false },
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
