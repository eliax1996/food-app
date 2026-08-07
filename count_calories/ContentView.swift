import SwiftUI
import SwiftData
import Charts
import Playgrounds
import ActivityKit
import os

private let persistenceLogger = Logger(subsystem: "ch.elia.count-calories", category: "persistence")

@main
struct MyApp: App {
    private let usesInMemoryStore = ProcessInfo.processInfo.arguments.contains("-ui-testing")

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: [Food.self, PlateEntry.self, WaterDay.self, WeightEntry.self, UserProfile.self],
            inMemory: usesInMemoryStore
        )
    }
}

@MainActor
private enum CaloriesLiveActivityManager {
    static func update(
        calories: Int,
        waterGlasses: Int,
        calorieGoal: Int,
        waterGoal: Int
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = CaloriesActivityAttributes.ContentState(
            calories: max(0, calories),
            waterGlasses: max(0, waterGlasses)
        )
        let content = ActivityContent(
            state: state,
            staleDate: Calendar.current.date(byAdding: .hour, value: 8, to: .now)
        )

        if let activity = Activity<CaloriesActivityAttributes>.activities.first {
            await activity.update(content)
            return
        }

        let attributes = CaloriesActivityAttributes(
            calorieGoal: calorieGoal,
            waterGoal: waterGoal
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }
}

@Model
final class Food {
    var name: String
    var calories: Int
    var servingGrams: Double
    var servingUnitRawValue: String?
    var barcode: String?

    init(
        name: String,
        calories: Int,
        servingGrams: Double,
        servingUnit: NutritionUnit = .grams,
        barcode: String? = nil
    ) {
        self.name = name
        self.calories = calories
        self.servingGrams = servingGrams
        servingUnitRawValue = servingUnit.rawValue
        self.barcode = barcode
    }
}

@Model
final class PlateEntry {
    var foodName: String
    var calories: Int
    var weightGrams: Double
    var quantity: Int
    var portionCount: Double?
    var servingUnitRawValue: String?
    var date: Date
    var mealType: String?

    init(
        foodName: String,
        calories: Int,
        weightGrams: Double,
        quantity: Double,
        servingUnit: NutritionUnit = .grams,
        mealType: String? = nil,
        date: Date = .now
    ) {
        self.foodName = foodName
        self.calories = calories
        self.weightGrams = weightGrams
        self.quantity = max(1, Int(quantity.rounded()))
        portionCount = quantity
        servingUnitRawValue = servingUnit.rawValue
        self.mealType = mealType
        self.date = date
    }
}

private extension Food {
    var nutritionUnit: NutritionUnit {
        NutritionUnit(rawValue: servingUnitRawValue ?? "") ?? .grams
    }
}

private extension PlateEntry {
    var portionQuantity: Double {
        portionCount ?? Double(quantity)
    }

    var nutritionUnit: NutritionUnit {
        NutritionUnit(rawValue: servingUnitRawValue ?? "") ?? .grams
    }
}

@Model
final class WaterDay {
    var date: Date
    var glasses: Int
    var lastRecordedAt: Date?

    init(date: Date, glasses: Int = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.glasses = glasses
        lastRecordedAt = glasses > 0 ? date : nil
    }
}

@Model
final class WeightEntry {
    var date: Date
    var kilograms: Double

    init(date: Date = .now, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}

@Model
final class UserProfile {
    var currentWeight: Double
    var targetWeight: Double
    var age: Int
    var dailyCalorieGoal: Int
    var targetDate: Date

    init(currentWeight: Double = 70, targetWeight: Double = 68, age: Int = 30, dailyCalorieGoal: Int = 1700, targetDate: Date = .now.addingTimeInterval(60 * 60 * 24 * 90)) {
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.age = age
        self.dailyCalorieGoal = dailyCalorieGoal
        self.targetDate = targetDate
    }
}

private enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    static var suggestedForCurrentTime: MealType {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        case 16..<21:
            return .dinner
        default:
            return .snack
        }
    }
}

private let exampleFoodSeeds: [(name: String, calories: Int, servingGrams: Double)] = [
    ("Apple", 52, 100),
    ("Banana", 89, 100),
    ("Orange", 47, 100),
    ("Strawberries", 32, 100),
    ("Blueberries", 57, 100),
    ("Grapes", 69, 100),
    ("Watermelon", 30, 100),
    ("Pineapple", 50, 100),
    ("Mango", 60, 100),
    ("Pear", 57, 100),
    ("Peach", 39, 100),
    ("Kiwi", 61, 100),
    ("Avocado", 160, 100),
    ("Tomato", 18, 100),
    ("Cucumber", 15, 100),
    ("Carrot", 41, 100),
    ("Broccoli", 34, 100),
    ("Spinach", 23, 100),
    ("Kale", 49, 100),
    ("Lettuce", 15, 100),
    ("Bell Pepper", 31, 100),
    ("Onion", 40, 100),
    ("Potato", 77, 100),
    ("Sweet Potato", 86, 100),
    ("Corn", 96, 100),
    ("Green Peas", 81, 100),
    ("Green Beans", 31, 100),
    ("Mushrooms", 22, 100),
    ("Zucchini", 17, 100),
    ("Eggplant", 25, 100),
    ("Cauliflower", 25, 100),
    ("Asparagus", 20, 100),
    ("Celery", 16, 100),
    ("Chicken Breast", 165, 100),
    ("Turkey Breast", 135, 100),
    ("Lean Beef", 250, 100),
    ("Pork Tenderloin", 143, 100),
    ("Salmon", 208, 100),
    ("Tuna", 132, 100),
    ("Cod", 82, 100),
    ("Shrimp", 99, 100),
    ("Eggs", 155, 100),
    ("Egg Whites", 52, 100),
    ("Greek Yogurt", 59, 100),
    ("Plain Yogurt", 61, 100),
    ("Cottage Cheese", 98, 100),
    ("Cheddar Cheese", 403, 100),
    ("Mozzarella", 280, 100),
    ("Milk", 42, 100),
    ("Almond Milk", 15, 100),
    ("Tofu", 76, 100),
    ("Tempeh", 193, 100),
    ("Lentils", 116, 100),
    ("Chickpeas", 164, 100),
    ("Black Beans", 132, 100),
    ("Kidney Beans", 127, 100),
    ("Edamame", 121, 100),
    ("Rice", 130, 100),
    ("Brown Rice", 111, 100),
    ("Quinoa", 120, 100),
    ("Oats", 389, 100),
    ("Pasta", 131, 100),
    ("Whole Wheat Pasta", 124, 100),
    ("Bread", 265, 100),
    ("Whole Wheat Bread", 247, 100),
    ("Bagel", 250, 100),
    ("Tortilla", 218, 100),
    ("Couscous", 112, 100),
    ("Barley", 123, 100),
    ("Granola", 471, 100),
    ("Cereal", 379, 100),
    ("Almonds", 579, 100),
    ("Walnuts", 654, 100),
    ("Cashews", 553, 100),
    ("Peanuts", 567, 100),
    ("Peanut Butter", 588, 100),
    ("Chia Seeds", 486, 100),
    ("Flax Seeds", 534, 100),
    ("Olive Oil", 884, 100),
    ("Butter", 717, 100),
    ("Hummus", 166, 100),
    ("Salsa", 36, 100),
    ("Mayonnaise", 680, 100),
    ("Ketchup", 112, 100),
    ("Dark Chocolate", 546, 100),
    ("Honey", 304, 100),
    ("Jam", 278, 100),
    ("Protein Powder", 400, 100),
    ("Crackers", 502, 100),
    ("Popcorn", 387, 100),
    ("Pretzels", 380, 100),
    ("Pizza", 266, 100),
    ("Burger", 295, 100),
    ("French Fries", 312, 100),
    ("Sushi", 143, 100),
    ("Soup", 50, 100),
    ("Chili", 101, 100),
    ("Pancakes", 227, 100),
    ("Waffles", 291, 100),
    ("Ice Cream", 207, 100)
]

struct ContentView: View {
    @State private var selectedTab = AppTab.counter
    @State private var addMealRequestID: UUID?
    @State private var waterAdjustmentRequest: WaterAdjustmentRequest?

    var body: some View {
        TabView(selection: $selectedTab) {
            CalorieCounterView(
                addMealRequestID: $addMealRequestID,
                waterAdjustmentRequest: $waterAdjustmentRequest
            )
                .tabItem {
                    Label("Counter", systemImage: "flame.fill")
                }
                .tag(AppTab.counter)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.history)

            ConfigView()
                .tabItem {
                    Label("Config", systemImage: "gearshape.fill")
                }
                .tag(AppTab.config)
        }
        .onOpenURL { url in
            guard url.scheme == "countcalories" else { return }
            selectedTab = .counter

            switch url.host {
            case "add-food":
                addMealRequestID = UUID()
            case "water":
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let delta = components?.queryItems?
                    .first(where: { $0.name == "delta" })?
                    .value
                    .flatMap(Int.init) ?? 0
                guard delta != 0 else { return }
                waterAdjustmentRequest = WaterAdjustmentRequest(delta: delta)
            default:
                break
            }
        }
    }
}

private struct WaterAdjustmentRequest: Equatable {
    let id = UUID()
    let delta: Int
}

private enum AppTab: Hashable {
    case counter
    case history
    case config
}

private struct CalorieCounterView: View {
    private let defaultCalorieGoal = 1700
    private let waterGoal = 8

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var showingFoodFilter = false
    @State private var weightGrams = 100.0
    @State private var quantity = 1.0
    @State private var newFoodName = ""
    @State private var newFoodCalories = 120
    @State private var newFoodServingGrams = 100.0
    @State private var barcode = ""
    @State private var pendingScannedBarcode: String?
    @State private var isLookingUpBarcode = false
    @State private var showingBarcodeScanner = false
    @State private var errorMessage: String?

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

    private var selectedCalories: Int {
        guard let selectedFood else { return 0 }
        let caloriesPerUnit = Double(selectedFood.calories) / selectedFood.servingGrams
        return Int((caloriesPerUnit * weightGrams * quantity).rounded())
    }

    private var selectedAmountUnit: NutritionUnit {
        selectedFood?.nutritionUnit ?? .grams
    }

    private var amountSliderUpperBound: Double {
        max(selectedAmountUnit == .milliliters ? 1_000 : 500, weightGrams)
    }

    private var filteredFoods: [Food] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return foods }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var visibleFilteredFoods: [Food] {
        Array(filteredFoods.prefix(5))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DailyProgressHeader(
                        calories: todaysCalories,
                        calorieGoal: dailyCalorieGoal,
                        waterGlasses: todaysWater?.glasses ?? 0,
                        waterGoal: waterGoal
                    )
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Water") {
                    Stepper("Glasses today: \(todaysWater?.glasses ?? 0)", value: waterBinding, in: 0...30)
                }

                Section("Meals") {
                    Button {
                        prepareMealSheetForAdd()
                    } label: {
                        Label("Add meal", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("add-meal")

                    if todaysEntries.isEmpty {
                        ContentUnavailableView("No meals yet", systemImage: "fork.knife.circle")
                    } else {
                        ForEach(todaysEntries) { entry in
                            MealEntryRow(entry: entry)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deletePlate(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        prepareMealSheetForEdit(entry)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }

                Section("New food") {
                    TextField("Name", text: $newFoodName)
                    TextField("Calories", value: $newFoodCalories, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Serving size in grams", value: $newFoodServingGrams, format: .number)
                        .keyboardType(.decimalPad)
                    Button("Save food", action: addFood)
                        .disabled(newFoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newFoodCalories <= 0 || newFoodServingGrams <= 0)
                }

                Section("Barcode lookup") {
                    HStack {
                        TextField("Barcode", text: $barcode)
                            .keyboardType(.numberPad)

                        Button {
                            Task { await lookupBarcode(barcode) }
                        } label: {
                            Label("Look up barcode", systemImage: "magnifyingglass")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(barcode.filter(\.isNumber).count < 8 || isLookingUpBarcode)

                        Button {
                            pendingScannedBarcode = nil
                            showingBarcodeScanner = true
                        } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                        }
                        .disabled(isLookingUpBarcode)
                    }

                    if isLookingUpBarcode {
                        ProgressView("Looking up product")
                    }
                }
            }
            .navigationTitle("Calories")
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
            .sheet(isPresented: $showingAddMeal) {
                addMealSheet
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

    private var addMealSheet: some View {
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
                            ForEach(visibleFilteredFoods) { food in
                                Button {
                                    selectFood(food)
                                } label: {
                                    FoodSelectionRow(food: food, isSelected: selectedFood.map { $0 === food } ?? false)
                                }
                            }
                        }
                    }
                }

                Section("Amount") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selectedAmountUnit == .milliliters ? "Volume" : "Weight")
                            Spacer()
                            TextField(
                                selectedAmountUnit == .milliliters ? "Milliliters" : "Grams",
                                value: $weightGrams,
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 84)
                            Text(selectedAmountUnit.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $weightGrams, in: 1...amountSliderUpperBound, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField(
                                "Quantity",
                                value: $quantity,
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
                                    get: { min(max(quantity, 0.25), 4) },
                                    set: { quantity = $0 }
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
                    Label("\(selectedCalories) kcal", systemImage: "fork.knife")
                }
            }
            .navigationTitle(editingEntry == nil ? "Add \(selectedMeal.rawValue)" : "Edit \(selectedMeal.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddMeal = false
                        resetMealSheet()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: savePlate)
                        .disabled(selectedFood == nil || weightGrams <= 0 || quantity <= 0)
                        .accessibilityIdentifier("save-meal")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear(perform: resetMealSheet)
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
        let day = WaterDay(date: .now)
        modelContext.insert(day)
        return day
    }

    private func prepareMealSheetForAdd() {
        editingEntry = nil
        selectedMeal = MealType.suggestedForCurrentTime
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

    private func selectFood(_ food: Food) {
        selectedFood = food
        weightGrams = food.servingGrams
        showingFoodFilter = false
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
        showingFoodFilter = false
        quantity = 1
        weightGrams = 100
    }

    private func addFood() {
        let food = Food(
            name: newFoodName.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: newFoodCalories,
            servingGrams: newFoodServingGrams
        )
        modelContext.insert(food)
        if saveChanges() {
            selectedFood = food
            newFoodName = ""
            newFoodCalories = 120
            newFoodServingGrams = 100
        }
    }

    private func lookupScannedBarcode() {
        guard let scannedBarcode = pendingScannedBarcode else { return }
        pendingScannedBarcode = nil
        Task { await lookupBarcode(scannedBarcode) }
    }

    private func lookupBarcode(_ barcodeToLookup: String) async {
        isLookingUpBarcode = true
        defer { isLookingUpBarcode = false }

        do {
            let service = NutritionLookupService(
                client: OpenFoodFactsClient(),
                cache: try NutritionCache.applicationCache()
            )
            guard let nutrition = try await service.nutrition(for: barcodeToLookup.filter(\.isNumber)) else {
                errorMessage = "No product was found for that barcode."
                return
            }
            guard let calories = nutrition.caloriesPer100Grams, calories > 0 else {
                errorMessage = "This product does not provide calories per 100 g or ml."
                return
            }

            let servingAmount = nutrition.servingAmount ?? 100
            let servingUnit = nutrition.resolvedServingUnit
            let servingCalories = Int((calories * servingAmount / 100).rounded())
            let food = foods.first { $0.barcode == nutrition.barcode }
                ?? foods.first { $0.name.localizedCaseInsensitiveCompare(nutrition.name) == .orderedSame }
                ?? Food(
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
                persistenceLogger.error("Failed to save barcode food: \(error.localizedDescription, privacy: .public)")
                errorMessage = "Your food could not be saved. Please try again."
                return
            }
            selectedFood = food
            barcode = ""
            prepareMealSheetForAdd()
        } catch {
            errorMessage = "The product lookup failed. Check your connection and try again."
        }
    }

    private func synchronizeWaterFromWidgetStore() {
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
            persistenceLogger.error("Failed to save calorie data: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your changes could not be saved. Please try again."
            return false
        }
    }
}

private struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]

    @State private var selectedMetric = HistoryMetric.calories
    @State private var currentWeight = 70.0
    @State private var showingWeightPicker = false
    @State private var draftWeightKilograms = 70
    @State private var draftWeightTenths = 0
    @State private var errorMessage: String?

    private var profile: UserProfile? {
        profiles.first
    }

    private var todaysWeight: WeightEntry? {
        weights.first { Calendar.current.isDateInToday($0.date) }
    }

    private var draftWeight: Double {
        Double(draftWeightKilograms) + Double(draftWeightTenths) / 10
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(HistoryMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(selectedMetric.rawValue) {
                    if selectedMetric == .calories {
                        HistogramChart(
                            items: dailyCalories.map {
                                HistogramItem(
                                    label: $0.date.formatted(.dateTime.month(.abbreviated).day()),
                                    value: Double($0.calories)
                                )
                            },
                            unit: "kcal",
                            tint: .orange
                        )
                    } else {
                        HistogramChart(
                            items: weights.prefix(14).reversed().map { entry in
                                HistogramItem(
                                    label: entry.date.formatted(.dateTime.month(.abbreviated).day()),
                                    value: entry.kilograms
                                )
                            },
                            unit: "kg",
                            tint: .blue
                        )
                    }
                }

                Section("Record weight") {
                    Button {
                        prepareWeightPicker()
                        showingWeightPicker = true
                    } label: {
                        HStack {
                            Text("Current weight")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(currentWeight, format: .number.precision(.fractionLength(1))) kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                currentWeight = todaysWeight?.kilograms ?? weights.first?.kilograms ?? profile?.currentWeight ?? 70
            }
            .sheet(isPresented: $showingWeightPicker) {
                weightPickerSheet
            }
            .alert("Could not save weight", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var weightPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("\(draftWeight, format: .number.precision(.fractionLength(1))) kg")
                    .font(.title.bold())
                    .contentTransition(.numericText())

                HStack(spacing: 0) {
                    Picker("Kilograms", selection: $draftWeightKilograms) {
                        ForEach(30...250, id: \.self) { kilograms in
                            Text("\(kilograms)").tag(kilograms)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Tenths", selection: $draftWeightTenths) {
                        ForEach(0...9, id: \.self) { tenth in
                            Text(".\(tenth)").tag(tenth)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("kg")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 180)
            }
            .padding()
            .navigationTitle("Current weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingWeightPicker = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        recordWeight(draftWeight)
                        showingWeightPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    private var dailyCalories: [(date: Date, calories: Int)] {
        let grouped = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }

        return grouped
            .map { date, dayEntries in
                (date: date, calories: dayEntries.reduce(0) { $0 + $1.calories })
            }
            .sorted { $0.date < $1.date }
            .suffix(14)
    }

    private func prepareWeightPicker() {
        let roundedWeight = (currentWeight * 10).rounded() / 10
        draftWeightKilograms = Int(roundedWeight)
        draftWeightTenths = Int((roundedWeight * 10).rounded()) % 10
    }

    private func recordWeight(_ kilograms: Double) {
        currentWeight = kilograms

        if let todaysWeight {
            todaysWeight.kilograms = kilograms
            todaysWeight.date = .now
        } else {
            modelContext.insert(WeightEntry(kilograms: kilograms))
        }

        profile?.currentWeight = kilograms
        do {
            try modelContext.save()
        } catch {
            persistenceLogger.error("Failed to save weight: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your weight could not be saved. Please try again."
        }
    }
}

private struct ConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]

    @AppStorage(ReminderPreferenceKey.breakfast) private var breakfastReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.lunch) private var lunchReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.snack) private var snackReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.dinner) private var dinnerReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.water) private var waterReminderEnabled = false

    @State private var currentWeight = 70.0
    @State private var targetWeight = 68.0
    @State private var age = 30
    @State private var dailyGoal = 1700
    @State private var targetDate = Date.now.addingTimeInterval(60 * 60 * 24 * 90)
    @State private var notificationAuthorizationState = ReminderAuthorizationState.notDetermined
    @State private var errorMessage: String?

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Body") {
                    HStack {
                        TextField("Weight", value: $currentWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Age: \(age)", value: $age, in: 1...120)
                }

                Section("Goal") {
                    HStack {
                        TextField("Target weight", value: $targetWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Daily goal: \(dailyGoal) kcal", value: $dailyGoal, in: 800...5000, step: 50)
                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                }

                Section {
                    reminderToggle(
                        "Breakfast",
                        detail: "9:00 AM when not logged",
                        isOn: $breakfastReminderEnabled,
                        identifier: "breakfast-reminder-toggle"
                    )
                    reminderToggle(
                        "Lunch",
                        detail: "1:00 PM when not logged",
                        isOn: $lunchReminderEnabled,
                        identifier: "lunch-reminder-toggle"
                    )
                    reminderToggle(
                        "Snack",
                        detail: "4:00 PM when not logged",
                        isOn: $snackReminderEnabled,
                        identifier: "snack-reminder-toggle"
                    )
                    reminderToggle(
                        "Dinner",
                        detail: "8:00 PM when not logged",
                        isOn: $dinnerReminderEnabled,
                        identifier: "dinner-reminder-toggle"
                    )
                } header: {
                    Text("Food reminders")
                } footer: {
                    Text("Each reminder is removed for that day as soon as you register its meal.")
                }

                Section {
                    reminderToggle(
                        "Water",
                        detail: "After 2 hours without a glass",
                        isOn: $waterReminderEnabled,
                        identifier: "water-reminder-toggle"
                    )
                } header: {
                    Text("Water reminders")
                } footer: {
                    Text("Water reminders run from 8:00 AM to 10:00 PM and stop after 8 glasses.")
                }

                if notificationAuthorizationState == .denied,
                   let systemSettingsURL = ReminderNotificationManager.systemSettingsURL {
                    Section {
                        Button {
                            openURL(systemSettingsURL)
                        } label: {
                            Label("Open notification settings", systemImage: "bell.slash.fill")
                        }
                    } header: {
                        Text("Notification access")
                    } footer: {
                        Text("Enabled reminders cannot arrive until notifications are allowed in Settings.")
                    }
                }

                Section {
                    Button("Save configuration", action: saveConfiguration)
                        .disabled(currentWeight <= 0 || targetWeight <= 0 || age <= 0 || dailyGoal <= 0)
                }
            }
            .navigationTitle("Config")
            .onAppear {
                loadProfile()
                synchronizeReminders(requestAuthorization: false)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                synchronizeReminders(requestAuthorization: false)
            }
            .onChange(of: breakfastReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: lunchReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: snackReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: dinnerReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: waterReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
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

    private func reminderToggle(
        _ title: String,
        detail: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func synchronizeReminders(requestAuthorization: Bool) {
        let mealRecords = entries.map {
            MealReminderRecord(mealType: $0.mealType, date: $0.date)
        }
        let waterRecords = waterDays.map {
            WaterReminderRecord(
                date: $0.date,
                glasses: $0.glasses,
                lastRecordedAt: $0.lastRecordedAt
            )
        }

        Task {
            if requestAuthorization {
                do {
                    _ = try await ReminderNotificationManager.shared.requestAuthorizationIfNeeded()
                } catch {
                    persistenceLogger.error(
                        "Failed to request notification authorization: \(error.localizedDescription, privacy: .public)"
                    )
                    errorMessage = "Notification access could not be requested. Please try again."
                }
            }

            notificationAuthorizationState = await ReminderNotificationManager.shared.authorizationState()
            await ReminderNotificationManager.shared.reschedule(
                meals: mealRecords,
                water: waterRecords,
                preferences: .stored()
            )
        }
    }

    private func loadProfile() {
        let currentProfile = profile ?? createProfile()
        currentWeight = currentProfile.currentWeight
        targetWeight = currentProfile.targetWeight
        age = currentProfile.age
        dailyGoal = currentProfile.dailyCalorieGoal
        targetDate = currentProfile.targetDate
    }

    private func createProfile() -> UserProfile {
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        saveChanges()
        return newProfile
    }

    private func saveConfiguration() {
        let currentProfile = profile ?? createProfile()
        currentProfile.currentWeight = currentWeight
        currentProfile.targetWeight = targetWeight
        currentProfile.age = age
        currentProfile.dailyCalorieGoal = dailyGoal
        currentProfile.targetDate = targetDate
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            persistenceLogger.error("Failed to save configuration: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your configuration could not be saved. Please try again."
        }
    }
}

private enum HistoryMetric: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case weight = "Weight"

    var id: String { rawValue }
}

private struct DailyProgressHeader: View {
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

private struct FoodSelectionRow: View {
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

private struct MealEntryRow: View {
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

private struct HistogramItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private struct HistogramChart: View {
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

#Preview {
    ContentView()
        .modelContainer(for: [Food.self, PlateEntry.self, WaterDay.self, WeightEntry.self, UserProfile.self], inMemory: true)
}

#Playground {
    _ = 1 + 2
}
