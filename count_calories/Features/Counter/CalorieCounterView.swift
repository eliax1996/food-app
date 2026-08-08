import Foundation
import SwiftData
import SwiftUI
import os

struct CalorieCounterView: View {
    private let defaultCalorieGoal = 1700
    private let waterGoal = 8

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Food.name) private var foods: [Food]
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]
    @Query private var profiles: [UserProfile]

    @Binding var addMealRequestID: UUID?
    @Binding var waterAdjustmentRequest: WaterAdjustmentRequest?

    @State private var showingAddMeal = false
    @State private var editingEntry: PlateEntry?
    @State private var selectedFood: Food?
    @State private var selectedMeal = MealType.suggestedForCurrentTime
    @State private var searchText = ""
    @State private var weightGrams = 100.0
    @State private var quantity = 1.0
    @State private var newFoodName = ""
    @State private var newFoodCalories = 120
    @State private var newFoodServingGrams = 100.0
    @State private var barcode = ""
    @State private var pendingScannedBarcode: String?
    @State private var pendingBarcodeMealType: MealType?
    @State private var isLookingUpBarcode = false
    @State private var showingBarcodeScanner = false
    @State private var showingFoodTools = false
    @State private var errorMessage: String?

    init(
        addMealRequestID: Binding<UUID?>,
        waterAdjustmentRequest: Binding<WaterAdjustmentRequest?>
    ) {
        _addMealRequestID = addMealRequestID
        _waterAdjustmentRequest = waterAdjustmentRequest
    }

    private var todaysEntries: [PlateEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todaysCalories: Int {
        todaysEntries.reduce(0) { $0 + $1.calories }
    }

    private var todaysWater: WaterDay? {
        waterDays.first { Calendar.current.isDateInToday($0.date) }
    }

    private var dailyCalorieGoal: Int {
        profiles.first?.dailyCalorieGoal ?? defaultCalorieGoal
    }

    private var isDesignReview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-design-review")
#else
        false
#endif
    }

    private func todaysEntries(for mealType: MealType) -> [PlateEntry] {
        todaysEntries.filter { entry in
            (MealType(rawValue: entry.mealType ?? "") ?? .snack) == mealType
        }
    }

    private func calories(for mealType: MealType) -> Int {
        todaysEntries(for: mealType).reduce(0) { $0 + $1.calories }
    }

    private var recentFoods: [Food] {
        var seenNames = Set<String>()
        return entries.compactMap { entry in
            guard seenNames.insert(entry.foodName.lowercased()).inserted else {
                return nil
            }
            return foods.first {
                $0.name.localizedCaseInsensitiveCompare(entry.foodName) == .orderedSame
            }
        }
        .prefix(5)
        .map { $0 }
    }

    private var selectedCalories: Int {
        guard let selectedFood else { return 0 }
        return CalorieCalculator.calories(
            caloriesPerServing: selectedFood.calories,
            servingAmount: selectedFood.servingGrams,
            consumedAmount: weightGrams,
            portionCount: quantity
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DailyProgressHeader(
                        calories: todaysCalories,
                        calorieGoal: dailyCalorieGoal
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    WaterTrackerRow(
                        glasses: waterBinding,
                        goal: waterGoal
                    )
                }

                Section("Meals") {
                    Button {
                        prepareMealSheetForAdd()
                    } label: {
                        Label("Log food", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("add-meal")

                    ForEach(MealType.allCases) { mealType in
                        let mealEntries = todaysEntries(for: mealType)

                        NavigationLink {
                            MealDetailView(
                                mealType: mealType,
                                entries: mealEntries,
                                onAdd: {
                                    prepareMealSheetForAdd(mealType: mealType)
                                },
                                onEdit: prepareMealSheetForEdit,
                                onDelete: deletePlate
                            )
                        } label: {
                            MealSummaryRow(
                                mealType: mealType,
                                entries: mealEntries,
                                calories: calories(for: mealType)
                            )
                        }
                    }
                }

            }
            .listSectionSpacing(16)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            pendingScannedBarcode = nil
                            pendingBarcodeMealType = nil
                            showingBarcodeScanner = true
                        } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder")
                        }
                        .disabled(isLookingUpBarcode)

                        Button {
                            showingFoodTools = true
                        } label: {
                            Label("Enter barcode or create food", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Label("More logging options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .onAppear(perform: prepareLocalData)
            .onChange(of: addMealRequestID) { _, requestID in
                guard requestID != nil else { return }
                prepareMealSheetForAdd()
            }
            .onChange(of: waterAdjustmentRequest) { _, request in
                guard let request else { return }
                adjustWater(by: request.delta)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                synchronizeWaterFromWidgetStore()
                mirrorTodayToWidgetStore()
            }
            .sheet(isPresented: $showingAddMeal, onDismiss: resetMealSheet) {
                MealEditorView(
                    foods: foods,
                    recentFoods: recentFoods,
                    isEditing: editingEntry != nil,
                    selectedMeal: $selectedMeal,
                    selectedFood: $selectedFood,
                    searchText: $searchText,
                    amount: $weightGrams,
                    portionCount: $quantity,
                    calories: selectedCalories,
                    onCancel: {
                        showingAddMeal = false
                        resetMealSheet()
                    },
                    onScanBarcode: scanBarcodeFromMealEditor,
                    onSave: savePlate
                )
                .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $showingFoodTools) {
                FoodToolsView(
                    barcode: $barcode,
                    foodName: $newFoodName,
                    calories: $newFoodCalories,
                    servingAmount: $newFoodServingGrams,
                    isLookingUpBarcode: isLookingUpBarcode,
                    onLookupBarcode: lookupEnteredBarcode,
                    onSaveFood: addFood
                )
            }
            .sheet(isPresented: $showingBarcodeScanner, onDismiss: lookupScannedBarcode) {
                BarcodeScannerView(
                    isPresented: $showingBarcodeScanner,
                    errorMessage: $errorMessage
                ) { scannedBarcode in
                    barcode = scannedBarcode
                    pendingScannedBarcode = scannedBarcode
                }
            }
            .alert("Could not complete action", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var waterBinding: Binding<Int> {
        Binding(
            get: { todaysWater?.glasses ?? 0 },
            set: { newValue in
                let day = todaysWater ?? createTodayWaterDay()
                let previousValue = day.glasses
                day.glasses = newValue
                if newValue > previousValue {
                    day.lastRecordedAt = .now
                }
                if saveChanges() {
                    mirrorTodayToWidgetStore()
                }
            }
        )
    }

    private func adjustWater(by delta: Int) {
        let day = todaysWater ?? createTodayWaterDay()
        day.glasses = max(0, day.glasses + delta)
        if delta > 0 {
            day.lastRecordedAt = .now
        }
        if saveChanges() {
            mirrorTodayToWidgetStore()
        }
    }

    private func prepareLocalData() {
        let existingFoodNames = Set(foods.map(\.name))
        let missingExampleFoods = exampleFoodSeeds
            .filter { !existingFoodNames.contains($0.name) }
            .map { Food(name: $0.name, calories: $0.calories, servingGrams: $0.servingGrams) }

        missingExampleFoods.forEach(modelContext.insert)
        selectedFood = selectedFood ?? (foods + missingExampleFoods).min {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        let currentWaterDay = todaysWater ?? createTodayWaterDay()
        if currentWaterDay.glasses > 0 && currentWaterDay.lastRecordedAt == nil {
            currentWaterDay.lastRecordedAt = .now
        }
        _ = saveChanges()
        synchronizeWaterFromWidgetStore()
        mirrorTodayToWidgetStore()
    }

    private func createTodayWaterDay() -> WaterDay {
        if let storedDays = try? modelContext.fetch(FetchDescriptor<WaterDay>()),
           let existingDay = storedDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            return existingDay
        }

        let day = WaterDay(date: .now)
        modelContext.insert(day)
        return day
    }

    private func prepareMealSheetForAdd(mealType: MealType? = nil) {
        editingEntry = nil
        selectedMeal = mealType ?? MealType.suggestedForCurrentTime
        selectedFood = selectedFood ?? foods.first
        searchText = ""
        quantity = 1
        weightGrams = selectedFood?.servingGrams ?? 100
        showingAddMeal = true
    }

    private func prepareMealSheetForEdit(_ entry: PlateEntry) {
        editingEntry = entry
        selectedMeal = MealType(rawValue: entry.mealType ?? "") ?? .snack
        selectedFood = foods.first { $0.name == entry.foodName } ?? selectedFood ?? foods.first
        searchText = ""
        quantity = entry.portionQuantity
        weightGrams = entry.weightGrams
        showingAddMeal = true
    }

    private func savePlate() {
        guard let selectedFood else { return }

        if let editingEntry {
            editingEntry.foodName = selectedFood.name
            editingEntry.calories = selectedCalories
            editingEntry.weightGrams = weightGrams
            editingEntry.quantity = max(1, Int(quantity.rounded()))
            editingEntry.portionCount = quantity
            editingEntry.servingUnitRawValue = selectedFood.nutritionUnit.rawValue
            editingEntry.mealType = selectedMeal.rawValue
        } else {
            let entry = PlateEntry(
                foodName: selectedFood.name,
                calories: selectedCalories,
                weightGrams: weightGrams,
                quantity: quantity,
                servingUnit: selectedFood.nutritionUnit,
                mealType: selectedMeal.rawValue
            )
            modelContext.insert(entry)
        }

        if saveChanges() {
            mirrorTodayToWidgetStore()
            showingAddMeal = false
            resetMealSheet()
        }
    }

    private func deletePlate(_ entry: PlateEntry) {
        modelContext.delete(entry)
        if saveChanges() {
            mirrorTodayToWidgetStore()
        }
    }

    private func resetMealSheet() {
        editingEntry = nil
        searchText = ""
        quantity = 1
        weightGrams = 100
    }

    private func addFood() {
        let trimmedName = newFoodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, newFoodCalories >= 0, newFoodServingGrams > 0 else {
            return
        }

        let food = Food(
            name: trimmedName,
            calories: newFoodCalories,
            servingGrams: newFoodServingGrams
        )
        modelContext.insert(food)
        if saveChanges() {
            selectedFood = food
            newFoodName = ""
            newFoodCalories = 120
            newFoodServingGrams = 100
            showingFoodTools = false
        }
    }

    private func lookupEnteredBarcode() {
        let enteredBarcode = barcode
        pendingBarcodeMealType = nil
        showingFoodTools = false
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            await lookupBarcode(enteredBarcode)
        }
    }

    private func scanBarcodeFromMealEditor() {
        pendingBarcodeMealType = selectedMeal
        pendingScannedBarcode = nil
        showingAddMeal = false

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            showingBarcodeScanner = true
        }
    }

    private func lookupScannedBarcode() {
        guard let scannedBarcode = pendingScannedBarcode else {
            pendingBarcodeMealType = nil
            return
        }
        pendingScannedBarcode = nil
        Task { await lookupBarcode(scannedBarcode) }
    }

    private func lookupBarcode(_ barcodeToLookup: String) async {
        let requestedMealType = pendingBarcodeMealType
        pendingBarcodeMealType = nil
        isLookingUpBarcode = true
        defer { isLookingUpBarcode = false }

        do {
            let service = NutritionLookupService(
                client: OpenFoodFactsClient(),
                cache: try NutritionCache.applicationCache()
            )
            let result = try await service.lookup(barcode: barcodeToLookup.filter(\.isNumber))
            let nutrition: FoodNutrition
            switch result {
            case let .found(foundNutrition):
                nutrition = foundNutrition
            case .incompleteProduct:
                errorMessage = "This product does not provide usable calorie information."
                return
            case .notFound:
                errorMessage = "No product was found for that barcode."
                return
            }
            let servingAmount = nutrition.defaultAmount.value
            let servingUnit = nutrition.defaultAmount.unit
            let servingCalories = Int(nutrition.calories(for: servingAmount).rounded())
            let food = foods.first {
                $0.matchesLookupProduct(barcode: nutrition.barcode, name: nutrition.name)
            } ?? Food(
                    name: nutrition.name,
                    calories: servingCalories,
                    servingGrams: servingAmount,
                    servingUnit: servingUnit,
                    barcode: nutrition.barcode
                )
            let isNewFood = !foods.contains { $0 === food }
            if isNewFood {
                modelContext.insert(food)
            }
            food.name = nutrition.name
            food.calories = servingCalories
            food.servingGrams = servingAmount
            food.servingUnitRawValue = servingUnit.rawValue
            food.barcode = nutrition.barcode

            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                AppLogger.persistence.error("Failed to save barcode food: \(error.localizedDescription, privacy: .public)")
                errorMessage = "Your food could not be saved. Please try again."
                return
            }
            selectedFood = food
            barcode = ""
            prepareMealSheetForAdd(mealType: requestedMealType)
        } catch {
            errorMessage = "The product lookup failed. Check your connection and try again."
        }
    }

    private func synchronizeWaterFromWidgetStore() {
        guard !isDesignReview else { return }
        guard
            let summary = WidgetDailySummaryStore.load(),
            Calendar.current.isDateInToday(summary.date)
        else {
            return
        }

        let day = todaysWater ?? createTodayWaterDay()
        guard
            day.glasses != summary.waterGlasses
                || day.lastRecordedAt != summary.lastWaterRecordedAt
        else {
            return
        }

        let addedWater = summary.waterGlasses > day.glasses
        day.glasses = summary.waterGlasses
        day.lastRecordedAt = summary.lastWaterRecordedAt
            ?? (addedWater ? .now : day.lastRecordedAt)
        _ = saveChanges()
    }

    private func mirrorTodayToWidgetStore() {
        guard !isDesignReview else { return }

        let calories = todaysCalories
        let waterGlasses = todaysWater?.glasses ?? 0

        WidgetDailySummaryStore.save(
            calories: calories,
            waterGlasses: waterGlasses,
            lastWaterRecordedAt: todaysWater?.lastRecordedAt
        )
        rescheduleReminders()

        Task {
            await CaloriesLiveActivityManager.update(
                calories: calories,
                waterGlasses: waterGlasses,
                calorieGoal: dailyCalorieGoal,
                waterGoal: waterGoal
            )
        }
    }

    private func rescheduleReminders() {
        let persistedEntries = (try? modelContext.fetch(FetchDescriptor<PlateEntry>())) ?? entries
        let persistedWaterDays = (try? modelContext.fetch(FetchDescriptor<WaterDay>())) ?? waterDays
        let mealRecords = persistedEntries.map {
            MealReminderRecord(mealType: $0.mealType, date: $0.date)
        }
        let waterRecords = persistedWaterDays.map {
            WaterReminderRecord(
                date: $0.date,
                glasses: $0.glasses,
                lastRecordedAt: $0.lastRecordedAt
            )
        }

        Task {
            await ReminderNotificationManager.shared.reschedule(
                meals: mealRecords,
                water: waterRecords,
                preferences: .stored()
            )
        }
    }

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error("Failed to save calorie data: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your changes could not be saved. Please try again."
            return false
        }
    }
}

#if DEBUG
#Preview("Counter") {
    CalorieCounterView(
        addMealRequestID: .constant(nil),
        waterAdjustmentRequest: .constant(nil)
    )
    .modelContainer(PreviewData.makeContainer())
}
#endif
