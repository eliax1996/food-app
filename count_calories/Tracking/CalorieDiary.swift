import Foundation
#if SWIFT_PACKAGE
import CaloriesCore
#endif

nonisolated public struct CalorieDiaryRecord: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let mealType: String?
    public let foodName: String
    public let calories: Int
    public let loggedAmount: Double
    public let portionCount: Double
    public let unitRawValue: String
    public let carbohydratesGrams: Double?
    public let proteinGrams: Double?
    public let fatGrams: Double?
    public let fiberGrams: Double?
    public let modifiedAt: Date
    public let loggedSnapshotKindRawValue: String?
    public let loggedCalorieDensity: Double?
    public let hasSupportedStoredUnit: Bool

    public var isKnownItemSnapshot: Bool {
        loggedSnapshotKindRawValue == "item"
    }

    public var canEditOrCopy: Bool {
        isKnownItemSnapshot
            && id.uuidString != "00000000-0000-0000-0000-000000000000"
            && hasSupportedStoredUnit
            && FoodCaloriePolicy.isValid(calories)
            && loggedAmount.isFinite
            && loggedAmount > 0
            && FoodAmountAdjustment.isValidPortionCount(portionCount)
            && date.timeIntervalSinceReferenceDate.isFinite
            && modifiedAt.timeIntervalSinceReferenceDate.isFinite
            && MealType(rawValue: mealType ?? "") != nil
            && [carbohydratesGrams, proteinGrams, fatGrams, fiberGrams]
                .allSatisfy { value in
                    guard let value else { return true }
                    return value.isFinite && value >= 0
                }
    }

    public init(
        id: UUID,
        date: Date,
        mealType: String?,
        foodName: String,
        calories: Int,
        loggedAmount: Double,
        portionCount: Double,
        unitRawValue: String?,
        carbohydratesGrams: Double? = nil,
        proteinGrams: Double? = nil,
        fatGrams: Double? = nil,
        fiberGrams: Double? = nil,
        modifiedAt: Date? = nil,
        loggedSnapshotKindRawValue: String? = nil,
        loggedCalorieDensity: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.foodName = foodName
        self.calories = calories
        self.loggedAmount = loggedAmount
        self.portionCount = portionCount
        hasSupportedStoredUnit = unitRawValue == "g" || unitRawValue == "ml"
        self.unitRawValue = unitRawValue == "ml" ? "ml" : "g"
        self.carbohydratesGrams = carbohydratesGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.modifiedAt = modifiedAt ?? date
        self.loggedSnapshotKindRawValue = loggedSnapshotKindRawValue
        self.loggedCalorieDensity = loggedCalorieDensity
    }
}

nonisolated public struct CalorieDiaryMealGroup: Equatable, Identifiable, Sendable {
    public let mealType: String
    public let records: [CalorieDiaryRecord]
    public let calorieTotal: FoodCalorieTotal

    public var id: String { mealType }
}

nonisolated public struct CalorieDiaryDay: Equatable, Identifiable, Sendable {
    public let date: Date
    public let mealGroups: [CalorieDiaryMealGroup]
    public let calorieTotal: FoodCalorieTotal

    public var id: Date { date }
    public var entryCount: Int { mealGroups.reduce(0) { $0 + $1.records.count } }
}

nonisolated public enum CalorieDiary {
    public static let orderedMealTypes = ["Breakfast", "Lunch", "Dinner", "Snack", "Unknown meal"]

    public static func days(
        from records: [CalorieDiaryRecord],
        calendar: Calendar = .current
    ) -> [CalorieDiaryDay] {
        let validRecords = records.filter { $0.date.timeIntervalSinceReferenceDate.isFinite }
        let groupedByDay = Dictionary(grouping: validRecords) {
            calendar.startOfDay(for: $0.date)
        }

        return groupedByDay.map { day, dayRecords in
            let groupedByMeal = Dictionary(grouping: dayRecords) { normalizedMealType($0.mealType) }
            let mealGroups = orderedMealTypes.compactMap { mealType -> CalorieDiaryMealGroup? in
                guard let records = groupedByMeal[mealType], !records.isEmpty else { return nil }
                let sorted = records.sorted(by: recordOrder)
                return CalorieDiaryMealGroup(
                    mealType: mealType,
                    records: sorted,
                    calorieTotal: FoodCaloriePolicy.assessedTotal(sorted.map(\.calories))
                )
            }
            return CalorieDiaryDay(
                date: day,
                mealGroups: mealGroups,
                calorieTotal: FoodCaloriePolicy.assessedTotal(dayRecords.map(\.calories))
            )
        }
        .sorted { $0.date > $1.date }
    }

    public static func adjacentDays(
        to selectedDate: Date,
        in days: [CalorieDiaryDay]
    ) -> (previous: CalorieDiaryDay?, next: CalorieDiaryDay?) {
        let ordered = days.sorted { $0.date < $1.date }
        guard let index = ordered.firstIndex(where: { $0.date == selectedDate }) else {
            return (nil, nil)
        }
        let previous = index > ordered.startIndex ? ordered[ordered.index(before: index)] : nil
        let nextIndex = ordered.index(after: index)
        let next = nextIndex < ordered.endIndex ? ordered[nextIndex] : nil
        return (previous, next)
    }

    private static func normalizedMealType(_ rawValue: String?) -> String {
        guard let rawValue,
              MealType(rawValue: rawValue) != nil else {
            return "Unknown meal"
        }
        return rawValue
    }

    private static func recordOrder(_ left: CalorieDiaryRecord, _ right: CalorieDiaryRecord) -> Bool {
        if left.date != right.date { return left.date < right.date }
        return left.id.uuidString < right.id.uuidString
    }
}
