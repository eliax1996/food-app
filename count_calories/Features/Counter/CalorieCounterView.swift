import Foundation
import SwiftData
import SwiftUI
import os

private enum BarcodeFlowOrigin: Equatable {
    case today
    case mealEditor
    case bulkReview(UUID)
}

struct CalorieCounterView: View {
    private let defaultCalorieGoal = 1700
    private let waterGoal = 8

    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Food.name) private var foods: [Food]
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]
    @Query(sort: \FoodLogCompletion.attestedAt, order: .reverse) private var foodLogCompletions: [FoodLogCompletion]
    @Query private var profiles: [UserProfile]

    @Binding var addMealRequestID: UUID?
    @Binding var waterAdjustmentRequest: WaterAdjustmentRequest?

    @State private var showingAddMeal = false
    @State private var bulkMealController: BulkMealDraftController?
    @State private var suspendedBulkMealController: BulkMealDraftController?
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
    @State private var foodToolsIntent = FoodToolsIntent.barcode
    @State private var foodToolsSucceeded = false
    @State private var confirmingEmptyFoodLogCompletion = false
    @State private var errorMessage: String?
    @State private var remoteFoodSearch: RemoteFoodSearchService?
    @State private var remoteSearchCoordinator: RemoteFoodSearchCoordinator?
    @State private var isLiveActivityActive = false
    @State private var liveActivityMessage: String?

    init(
        addMealRequestID: Binding<UUID?>,
        waterAdjustmentRequest: Binding<WaterAdjustmentRequest?>
    ) {
        _addMealRequestID = addMealRequestID
        _waterAdjustmentRequest = waterAdjustmentRequest
    }

    private var todaysEntries: [PlateEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: .now) }
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
            || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
#else
        false
#endif
    }

    private var usesBulkFoodFixture: Bool {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-ui-testing-bulk-food")
            || arguments.contains("-design-review-bulk-food")
#else
        return false
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    WaterTrackerRow(
                        glasses: waterBinding,
                        goal: waterGoal
                    )
                    .listRowInsets(EdgeInsets(top: -3, leading: 16, bottom: -3, trailing: 16))

                    foodLogStatusRow
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    NavigationLink {
                        DailyNutritionView(summary: todaysNutritionSummary)
                    } label: {
                        NutritionBalanceRow(summary: todaysNutritionSummary)
                    }
                    .accessibilityIdentifier("nutrition-balance-link")
                    .listRowInsets(EdgeInsets(top: -2, leading: 16, bottom: -2, trailing: 16))
                }

                Section("Meals") {
                    Button {
                        prepareMealSheetForAdd()
                    } label: {
                        Label("Log food", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("add-meal")

                    Button {
                        Task { await prepareBulkMealSheet() }
                    } label: {
                        Label("Describe meal", systemImage: "text.bubble.fill")
                    }
                    .accessibilityIdentifier("describe-meal")

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
                        .accessibilityIdentifier("meal-summary-\(mealType.rawValue.lowercased())")
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                }

                Section {
                    Color.clear
                        .frame(height: 84)
                        .accessibilityHidden(true)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listSectionSpacing(0)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        beginBarcodeFlow(from: .today)
                        showingBarcodeScanner = true
                    } label: {
                        Label("Scan barcode", systemImage: "barcode.viewfinder")
                    }
                    .disabled(isLookingUpBarcode)
                    .accessibilityIdentifier("scan-barcode")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: showManualBarcodeTools) {
                            Label("Enter barcode manually", systemImage: "barcode")
                        }

                        Button(action: showCustomFoodTools) {
                            Label("Create custom food", systemImage: "plus.circle")
                        }

                        Divider()

                        if isLiveActivityActive {
                            Button(action: stopLiveActivity) {
                                Label("Stop Live Activity", systemImage: "stop.circle")
                            }
                            .accessibilityIdentifier("stop-live-activity")
                        } else {
                            Button(action: startLiveActivity) {
                                Label("Start Live Activity", systemImage: "waveform.path")
                            }
                            .accessibilityIdentifier("start-live-activity")
                        }
                    } label: {
                        Label("More logging options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                isLiveActivityActive = CaloriesLiveActivityManager.isActive
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
                isLiveActivityActive = CaloriesLiveActivityManager.isActive
                mirrorTodayToWidgetStore()
            }
            .alert("Live Activity", isPresented: Binding(
                get: { liveActivityMessage != nil },
                set: { if !$0 { liveActivityMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(liveActivityMessage ?? "Unknown error")
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
            .sheet(item: $bulkMealController, onDismiss: bulkMealDidDismiss) { controller in
                BulkMealLoggingView(
                    foods: foods.isEmpty && usesBulkFoodFixture
                        ? exampleFoodSeeds.map {
                            Food(name: $0.name, calories: $0.calories, servingGrams: $0.servingGrams)
                        }
                        : foods,
                    controller: controller,
                    onCreateCustomFood: createCustomFoodForBulkReview,
                    onConfirm: confirmBulkMeal
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
                    intent: foodToolsIntent,
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
            .alert("Complete empty food log?", isPresented: $confirmingEmptyFoodLogCompletion) {
                Button("I ate nothing today") {
                    markTodayFoodLogComplete()
                }
                Button("Keep logging", role: .cancel) {}
            } message: {
                Text("No food is logged for today. Confirm only if this is a genuine zero-intake day; missing food must stay in progress.")
            }
            .alert("Could not complete action", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private enum FoodLogStatus {
        case inProgress
        case complete
        case needsReview

        var title: String {
            switch self {
            case .inProgress: "In progress"
            case .complete: "Complete"
            case .needsReview: "Needs review"
            }
        }

        var actionTitle: String? {
            switch self {
            case .inProgress: "Mark Complete"
            case .complete: nil
            case .needsReview: "Reconfirm"
            }
        }
    }

    private var todaysFoodLogCompletion: FoodLogCompletion? {
        let today = calendar.startOfDay(for: .now)
        let calendarIdentifier = String(describing: calendar.identifier)
        return foodLogCompletions.first {
            $0.calendarIdentifier == calendarIdentifier
                && $0.timeZoneIdentifier == calendar.timeZone.identifier
                && $0.dayStart == today
        }
    }

    private var foodLogStatus: FoodLogStatus {
        guard let completion = todaysFoodLogCompletion else { return .inProgress }
        return completion.isStale ? .needsReview : .complete
    }

    private var foodLogStatusRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    foodLogLabel
                    foodLogStatusText
                    if let actionTitle = foodLogStatus.actionTitle {
                        foodLogActionButton(actionTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        foodLogLabel
                        Spacer(minLength: 4)
                        foodLogStatusText
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let actionTitle = foodLogStatus.actionTitle {
                            foodLogActionButton(actionTitle)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            foodLogLabel
                            Spacer(minLength: 8)
                            foodLogStatusText
                        }
                        if let actionTitle = foodLogStatus.actionTitle {
                            foodLogActionButton(actionTitle)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Food log")
        .accessibilityValue(foodLogStatus.title)
    }

    private var foodLogLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
            Text("Food log")
        }
        .font(.subheadline.weight(.medium))
        .fixedSize(horizontal: true, vertical: false)
    }

    private var foodLogStatusText: some View {
        Text(foodLogStatus.title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("food-log-status")
    }

    private func foodLogActionButton(_ title: String) -> some View {
        Button(action: requestTodayFoodLogCompletion) {
            Text(title)
                .padding(.vertical, 5)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minHeight: 44)
        .accessibilityIdentifier("mark-food-log-complete")
        .accessibilityLabel(title + " food log")
        .accessibilityHint("Attests that today’s food log is finished. Adding or editing food will require reconfirmation.")
    }

    private func requestTodayFoodLogCompletion() {
        if case .inProgress = foodLogStatus, todaysEntries.isEmpty {
            confirmingEmptyFoodLogCompletion = true
        } else {
            markTodayFoodLogComplete()
        }
    }

    private func markTodayFoodLogComplete() {
        do {
            guard let coordinator = mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            coordinator.synchronizeCalendar(calendar)
            switch foodLogStatus {
            case .needsReview:
                _ = try coordinator.reconfirmFoodLog(for: .now)
            case .inProgress:
                _ = try coordinator.markFoodLogComplete(for: .now)
            case .complete:
                return
            }
        } catch {
            AppLogger.persistence.error("Failed to attest food log: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Food log could not be marked complete. Please try again."
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
                    mirrorTodayToWidgetStore(preservePendingWidgetWater: false)
                }
            }
        )
    }

    private func adjustWater(by delta: Int) {
        let day = todaysWater ?? createTodayWaterDay()
        day.glasses = min(max(0, day.glasses + delta), 30)
        if delta > 0 {
            day.lastRecordedAt = .now
        }
        if saveChanges() {
            mirrorTodayToWidgetStore(preservePendingWidgetWater: false)
        }
    }

    private func prepareLocalData() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-adaptive-applied") {
            return
        }
        #endif
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

    private func prepareBulkMealSheet() async {
        guard mutationCoordinator != nil else {
            errorMessage = "Meal description could not be prepared. Direct food logging still works."
            return
        }
        let service = remoteFoodSearch ?? FoodSearchServiceFactory.make()
        if remoteFoodSearch == nil {
            remoteFoodSearch = service
            remoteSearchCoordinator = service.map {
                RemoteFoodSearchCoordinator(
                    service: $0,
                    languages: FoodSearchServiceFactory.preferredLanguages
                )
            }
        }
        let persistence = try? await BulkFoodPersistenceSession.applicationSession()
        let extractor = BulkFoodExtractorFactory.make()
        let matcher = BulkFoodMatcher(
            remoteService: service,
            learningStore: persistence?.learningStore,
            languages: FoodSearchServiceFactory.preferredLanguages
        )
        bulkMealController = BulkMealDraftController(
            selectedMeal: .suggestedForCurrentTime,
            extractor: extractor,
            matcher: matcher,
            learningStore: persistence?.learningStore,
            learningLease: persistence?.learningLease,
            draftStore: persistence?.draftStore,
            draftLease: persistence?.draftLease,
            allowRemoteMatching: !usesBulkFoodFixture
        )
    }

    private func bulkMealDidDismiss() {
        bulkMealController?.cancelWork()
        bulkMealController = nil
    }

    private func createCustomFoodForBulkReview(rowID: UUID, query: String) {
        guard let controller = bulkMealController else { return }
        beginBarcodeFlow(from: .bulkReview(rowID))
        newFoodName = query.trimmingCharacters(in: .whitespacesAndNewlines)
        foodToolsIntent = .customFood
        suspendedBulkMealController = controller
        Task { try? await controller.saveDraft() }
        bulkMealController = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard case .bulkReview(let activeRowID) = barcodeFlowOrigin,
                  activeRowID == rowID else { return }
            showingFoodTools = true
        }
    }

    private func confirmBulkMeal(_ inserts: [BulkPlateInsert], operationID: UUID) throws {
        guard let coordinator = mutationCoordinator else {
            throw PlanEvidenceMutationError.coordinatorUnavailable
        }
        coordinator.synchronizeCalendar(calendar)
        let insertedIDs = try coordinator.insertPlateBatch(
            inserts,
            expectedDay: .now,
            operationID: operationID
        )
        guard insertedIDs.count == inserts.count else {
            throw PlanEvidenceMutationError.invalidBulkBatch
        }
        mirrorTodayToWidgetStore()
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

        do {
            guard let coordinator = mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            coordinator.synchronizeCalendar(calendar)
            if let editingEntry {
                try coordinator.updatePlate(
                    stableID: editingEntry.stableID,
                    foodName: selectedFood.name,
                    calories: selectedCalories,
                    weightGrams: weightGrams,
                    quantity: quantity,
                    servingUnitRawValue: selectedFood.nutritionUnit.rawValue,
                    nutrients: selectedNutrients,
                    mealType: selectedMeal.rawValue,
                    date: editingEntry.date
                )
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
                try coordinator.insertPlate(entry)
            }
            mirrorTodayToWidgetStore()
            showingAddMeal = false
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error("Failed to save meal evidence: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your meal could not be saved. Please try again."
        }
    }

    private func deletePlate(_ entry: PlateEntry) {
        do {
            guard let coordinator = mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            coordinator.synchronizeCalendar(calendar)
            try coordinator.deletePlate(stableID: entry.stableID)
            mirrorTodayToWidgetStore()
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error("Failed to delete meal evidence: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your meal could not be deleted. Please try again."
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
            foodToolsSucceeded = true
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
        foodToolsSucceeded = false
        barcodeFlowOrigin = origin
    }

    private func showManualBarcodeTools() {
        beginBarcodeFlow(from: .today)
        foodToolsIntent = .barcode
        showingFoodTools = true
    }

    private func showCustomFoodTools() {
        beginBarcodeFlow(from: .today)
        foodToolsIntent = .customFood
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
        let foodWasSelected = barcodeLookupSucceeded || foodToolsSucceeded
        clearBarcodeFlow()

        switch (origin, foodWasSelected) {
        case (.today, true):
            prepareMealSheetForAdd()
        case (.mealEditor, _):
            showingAddMeal = true
        case (.bulkReview(let rowID), true):
            if let selectedFood {
                suspendedBulkMealController?.selectSavedFood(selectedFood, for: rowID)
            }
            restoreSuspendedBulkReview()
        case (.bulkReview, false):
            restoreSuspendedBulkReview()
        case (.today, false):
            break
        }
    }

    private func restoreSuspendedBulkReview() {
        guard let controller = suspendedBulkMealController else { return }
        suspendedBulkMealController = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard bulkMealController == nil else { return }
            bulkMealController = controller
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
            foodToolsIntent = .barcode
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"), barcodeToLookup == "99999999" {
            cancelBarcodeLookup()
            barcodeLookupFailure = .offline
            barcodeLookupFailureBarcode = barcodeToLookup
            Task { @MainActor in
                await Task.yield()
                guard barcode.filter(\.isNumber) == barcodeToLookup else { return }
                barcodeLookupFailure = .offline
                barcodeLookupFailureBarcode = barcodeToLookup
            }
            return
        }
        #endif
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
        foodToolsSucceeded = false
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

    private func mirrorTodayToWidgetStore(
        preservePendingWidgetWater: Bool = true
    ) {
        guard !isDesignReview else { return }

        let calories = todaysCalories
        let waterGlasses = todaysWater?.glasses ?? 0

        WidgetDailySummaryStore.save(
            calories: calories,
            waterGlasses: waterGlasses,
            lastWaterRecordedAt: todaysWater?.lastRecordedAt,
            calorieGoal: dailyCalorieGoal,
            waterGoal: waterGoal,
            preservePendingWidgetWater: preservePendingWidgetWater
        )
        rescheduleReminders()

        Task {
            await CaloriesLiveActivityManager.updateIfActive(
                calories: calories,
                waterGlasses: waterGlasses,
                calorieGoal: dailyCalorieGoal,
                waterGoal: waterGoal
            )
        }
    }

    private func startLiveActivity() {
        switch CaloriesLiveActivityManager.start(
            calories: todaysCalories,
            waterGlasses: todaysWater?.glasses ?? 0,
            calorieGoal: dailyCalorieGoal,
            waterGoal: waterGoal
        ) {
        case .started, .alreadyActive:
            isLiveActivityActive = true
        case .unavailable:
            liveActivityMessage = "Live Activities are unavailable or disabled in Settings."
        case .failed:
            liveActivityMessage = "Live Activity could not start. Please try again."
        }
    }

    private func stopLiveActivity() {
        Task {
            await CaloriesLiveActivityManager.stop()
            isLiveActivityActive = CaloriesLiveActivityManager.isActive
        }
    }

    private func rescheduleReminders() {
        let persistedEntries = (try? modelContext.fetch(FetchDescriptor<PlateEntry>())) ?? entries
        let persistedWaterDays = (try? modelContext.fetch(FetchDescriptor<WaterDay>())) ?? waterDays
        let persistedWeights = (try? modelContext.fetch(FetchDescriptor<WeightEntry>())) ?? []
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

        let weightRecords = persistedWeights.map { WeightReminderRecord(date: $0.date) }

        Task {
            await ReminderNotificationManager.shared.reschedule(
                meals: mealRecords,
                water: waterRecords,
                weights: weightRecords,
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
    .previewPlanEvidenceContainer(PreviewData.makeContainer())
    .environment(\.locale, Locale(identifier: "en_US"))
}
#endif
