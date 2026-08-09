import Foundation
import SwiftData
import SwiftUI
import os

private enum BarcodeFlowOrigin: Equatable {
    case today
    case mealEditor
}

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
    @State private var newFoodCarbohydrates: Double?
    @State private var newFoodProtein: Double?
    @State private var newFoodFat: Double?
    @State private var newFoodFiber: Double?
    @State private var barcode = ""
    @State private var pendingScannedBarcode: String?
    @State private var barcodeFlowOrigin = BarcodeFlowOrigin.today
    @State private var scannerManualEntryRequested = false
    @State private var preservesMealDraftOnDismissal = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeLookupFailure: BarcodeLookupFailure?
    @State private var barcodeLookupFailureBarcode: String?
    @State private var barcodeLookupTask: Task<Void, Never>?
    @State private var activeBarcodeLookup: String?
    @State private var barcodeLookupGeneration = 0
    @State private var barcodeLookupSucceeded = false
    @State private var showingBarcodeScanner = false
    @State private var showingFoodTools = false
    @State private var errorMessage: String?
    @State private var remoteFoodSearch: RemoteFoodSearchService?
    @State private var remoteSearchCoordinator: RemoteFoodSearchCoordinator?

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

    private var todaysNutritionSummary: DailyNutritionSummary {
        DailyNutrition.summary(
            records: todaysEntries.map {
                LoggedNutrition(calories: $0.calories, nutrients: $0.nutrients)
            },
            calorieGoal: dailyCalorieGoal
        )
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

    private var selectedNutrients: FoodNutrients {
        selectedFood?.consumedNutrients(
            consumedAmount: weightGrams,
            portionCount: quantity
        ) ?? .empty
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

                    NavigationLink {
                        DailyNutritionView(summary: todaysNutritionSummary)
                    } label: {
                        NutritionBalanceRow(summary: todaysNutritionSummary)
                    }
                    .accessibilityIdentifier("nutrition-balance-link")
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
                            beginBarcodeFlow(from: .today)
                            showingBarcodeScanner = true
                        } label: {
                            Label("Scan barcode", systemImage: "barcode.viewfinder")
                        }
                        .disabled(isLookingUpBarcode)

                        Button(action: showFoodToolsFromToolbar) {
                            Label("Enter barcode or create food", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Label("More logging options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                prepareLocalData()
                if remoteFoodSearch == nil {
                    let service = FoodSearchServiceFactory.make()
                    remoteFoodSearch = service
                    remoteSearchCoordinator = service.map {
                        RemoteFoodSearchCoordinator(
                            service: $0,
                            languages: FoodSearchServiceFactory.preferredLanguages
                        )
                    }
                }
            }
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
            .sheet(isPresented: $showingAddMeal, onDismiss: mealEditorDidDismiss) {
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
                    remoteSearch: remoteSearchCoordinator,
                    onSelectRemoteFood: selectRemoteFood,
                    onCancel: {
                        showingAddMeal = false
                    },
                    onScanBarcode: scanBarcodeFromMealEditor,
                    onSave: savePlate
                )
                .environment(\.dynamicTypeSize, dynamicTypeSize)
            }
            .sheet(isPresented: $showingFoodTools, onDismiss: foodToolsDidDismiss) {
                FoodToolsView(
                    barcode: $barcode,
                    foodName: $newFoodName,
                    calories: $newFoodCalories,
                    servingAmount: $newFoodServingGrams,
                    carbohydrates: $newFoodCarbohydrates,
                    protein: $newFoodProtein,
                    fat: $newFoodFat,
                    fiber: $newFoodFiber,
                    isLookingUpBarcode: isLookingUpBarcode,
                    barcodeLookupFailure: barcodeLookupFailure,
                    onBarcodeChanged: barcodeDidChange,
                    onDone: dismissFoodTools,
                    onLookupBarcode: lookupEnteredBarcode,
                    onSaveFood: addFood
                )
            }
            .sheet(isPresented: $showingBarcodeScanner, onDismiss: scannerDidDismiss) {
                BarcodeScannerView(
                    isPresented: $showingBarcodeScanner,
                    onScan: { scannedBarcode in
                        barcode = scannedBarcode
                        pendingScannedBarcode = scannedBarcode
                    },
                    onEnterManually: {
                        scannerManualEntryRequested = true
                        showingBarcodeScanner = false
                    }
                )
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
            editingEntry.applyNutritionSnapshot(selectedNutrients)
            editingEntry.mealType = selectedMeal.rawValue
        } else {
            let entry = PlateEntry(
                foodName: selectedFood.name,
                calories: selectedCalories,
                weightGrams: weightGrams,
                quantity: quantity,
                servingUnit: selectedFood.nutritionUnit,
                nutrients: selectedNutrients,
                mealType: selectedMeal.rawValue
            )
            modelContext.insert(entry)
        }

        if saveChanges() {
            mirrorTodayToWidgetStore()
            showingAddMeal = false
        }
    }

    private func deletePlate(_ entry: PlateEntry) {
        modelContext.delete(entry)
        if saveChanges() {
            mirrorTodayToWidgetStore()
        }
    }

    private func mealEditorDidDismiss() {
        if preservesMealDraftOnDismissal {
            preservesMealDraftOnDismissal = false
            return
        }
        resetMealSheet()
    }

    private func resetMealSheet() {
        editingEntry = nil
        searchText = ""
        quantity = 1
        weightGrams = 100
    }

    private func selectRemoteFood(_ nutrition: FoodNutrition) -> Bool {
        let servingAmount = nutrition.defaultAmount.value
        let servingUnit = nutrition.defaultAmount.unit
        let servingCalories = Int(nutrition.calories(for: servingAmount).rounded())
        let food = foods.first { $0.barcode == nutrition.barcode } ?? Food(
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
        food.applyNutrition(nutrition)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error("Failed to save remote search food: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your food could not be saved. Please try again."
            return false
        }
        selectedFood = food
        weightGrams = servingAmount
        return true
    }

    private func addFood() {
        let trimmedName = newFoodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, newFoodCalories >= 0, newFoodServingGrams > 0 else {
            return
        }

        cancelBarcodeLookup()
        let food = Food(
            name: trimmedName,
            calories: newFoodCalories,
            servingGrams: newFoodServingGrams,
            nutrientsPerServing: FoodNutrients(
                carbohydratesGrams: newFoodCarbohydrates,
                proteinGrams: newFoodProtein,
                fatGrams: newFoodFat,
                fiberGrams: newFoodFiber
            )
        )
        modelContext.insert(food)
        if saveChanges() {
            selectedFood = food
            weightGrams = food.servingGrams
            newFoodName = ""
            newFoodCalories = 120
            newFoodServingGrams = 100
            newFoodCarbohydrates = nil
            newFoodProtein = nil
            newFoodFat = nil
            newFoodFiber = nil
            showingFoodTools = false
        }
    }

    private func beginBarcodeFlow(from origin: BarcodeFlowOrigin) {
        cancelBarcodeLookup()
        barcodeLookupFailure = nil
        barcodeLookupFailureBarcode = nil
        pendingScannedBarcode = nil
        scannerManualEntryRequested = false
        barcodeLookupSucceeded = false
        barcodeFlowOrigin = origin
    }

    private func showFoodToolsFromToolbar() {
        beginBarcodeFlow(from: .today)
        showingFoodTools = true
    }

    private func barcodeDidChange() {
        let generation = barcodeLookupGeneration
        Task { @MainActor in
            await Task.yield()
            guard generation == barcodeLookupGeneration else { return }
            let currentBarcode = barcode.filter(\.isNumber)
            if let failureBarcode = barcodeLookupFailureBarcode,
               currentBarcode != failureBarcode {
                barcodeLookupFailure = nil
                barcodeLookupFailureBarcode = nil
            }
        }
    }

    private func lookupEnteredBarcode() {
        startBarcodeLookup()
    }

    private func dismissFoodTools() {
        cancelBarcodeLookup()
        barcodeLookupFailure = nil
        barcodeLookupFailureBarcode = nil
        showingFoodTools = false
    }

    private func foodToolsDidDismiss() {
        cancelBarcodeLookup()
        barcodeLookupFailure = nil
        barcodeLookupFailureBarcode = nil
        let origin = barcodeFlowOrigin
        let lookupSucceeded = barcodeLookupSucceeded
        clearBarcodeFlow()

        switch (origin, lookupSucceeded) {
        case (.today, true):
            prepareMealSheetForAdd()
        case (.mealEditor, _):
            showingAddMeal = true
        case (.today, false):
            break
        }
    }

    private func scanBarcodeFromMealEditor() {
        beginBarcodeFlow(from: .mealEditor)
        preservesMealDraftOnDismissal = true
        showingAddMeal = false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            showingBarcodeScanner = true
        }
    }

    private func scannerDidDismiss() {
        if scannerManualEntryRequested {
            scannerManualEntryRequested = false
            showingFoodTools = true
            return
        }

        guard pendingScannedBarcode != nil else {
            let origin = barcodeFlowOrigin
            clearBarcodeFlow()
            if origin == .mealEditor {
                showingAddMeal = true
            }
            return
        }

        pendingScannedBarcode = nil
        showingFoodTools = true
        startBarcodeLookup()
    }

    private func startBarcodeLookup() {
        let barcodeToLookup = barcode.filter(\.isNumber)
        guard (8...14).contains(barcodeToLookup.count) else {
            barcodeLookupFailure = .invalid
            barcodeLookupFailureBarcode = barcodeToLookup
            return
        }

        cancelBarcodeLookup()
        barcodeLookupFailure = nil
        barcodeLookupFailureBarcode = nil
        activeBarcodeLookup = barcodeToLookup
        isLookingUpBarcode = true
        let generation = barcodeLookupGeneration
        barcodeLookupTask = Task { @MainActor in
            await performBarcodeLookup(barcode: barcodeToLookup, generation: generation)
        }
    }

    private func performBarcodeLookup(barcode: String, generation: Int) async {
        do {
            let service = try NutritionLookupServiceFactory.make()
            let result = try await service.lookup(barcode: barcode)
            guard isCurrentBarcodeLookup(generation) else { return }

            let nutrition: FoodNutrition
            switch result {
            case let .found(foundNutrition):
                nutrition = foundNutrition
            case .incompleteProduct:
                finishBarcodeLookup(generation, failure: .incomplete)
                return
            case .notFound:
                finishBarcodeLookup(generation, failure: .notFound)
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
            food.applyNutrition(nutrition)

            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                AppLogger.persistence.error("Failed to save barcode food: \(error.localizedDescription, privacy: .public)")
                finishBarcodeLookup(generation, failure: .saveFailed)
                return
            }
            guard isCurrentBarcodeLookup(generation) else { return }

            selectedFood = food
            weightGrams = servingAmount
            isLookingUpBarcode = false
            barcodeLookupTask = nil
            activeBarcodeLookup = nil
            barcodeLookupFailure = nil
            barcodeLookupFailureBarcode = nil
            barcodeLookupSucceeded = true
            self.barcode = ""
            showingFoodTools = false
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentBarcodeLookup(generation) else { return }
            finishBarcodeLookup(generation, failure: BarcodeLookupFailure.classify(error))
        }
    }

    private func isCurrentBarcodeLookup(_ generation: Int) -> Bool {
        generation == barcodeLookupGeneration && !Task.isCancelled
    }

    private func finishBarcodeLookup(_ generation: Int, failure: BarcodeLookupFailure) {
        guard isCurrentBarcodeLookup(generation) else { return }
        isLookingUpBarcode = false
        barcodeLookupTask = nil
        barcodeLookupFailureBarcode = activeBarcodeLookup
        activeBarcodeLookup = nil
        barcodeLookupFailure = failure
    }

    private func cancelBarcodeLookup() {
        barcodeLookupGeneration &+= 1
        barcodeLookupTask?.cancel()
        barcodeLookupTask = nil
        activeBarcodeLookup = nil
        isLookingUpBarcode = false
    }

    private func clearBarcodeFlow() {
        pendingScannedBarcode = nil
        scannerManualEntryRequested = false
        barcodeLookupSucceeded = false
        barcodeFlowOrigin = .today
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
    .environment(\.locale, Locale(identifier: "en_US"))
}
#endif
