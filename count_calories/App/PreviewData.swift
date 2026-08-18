#if DEBUG
import Foundation
import SwiftData
import SwiftUI

enum DesignReviewState: String, CaseIterable {
    case normal
    case empty
    case nearTarget
    case exceeded
    case longContent
    case nutritionPartial
    case nutritionImbalanced
    case customNutrition
    case adaptiveCollecting
    case adaptiveProposal
    case adaptiveApplied

    static var current: DesignReviewState {
        let rawValue = ProcessInfo.processInfo.environment["DESIGN_REVIEW_STATE"] ?? "normal"
        return DesignReviewState(rawValue: rawValue) ?? .normal
    }
}

@MainActor
enum PreviewData {
    private static var coordinators: [ObjectIdentifier: PlanEvidenceMutationCoordinator] = [:]

    static func makeContainer(state: DesignReviewState = .normal) -> ModelContainer {
        let schema = Schema([
            Food.self,
            PlateEntry.self,
            FoodLogCompletion.self,
            BulkFoodBatchOperation.self,
            WaterDay.self,
            WeightEntry.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let coordinator = PlanEvidenceMutationCoordinator(modelContainer: container)
            coordinators[ObjectIdentifier(container)] = coordinator
            try seed(container.mainContext, state: state, coordinator: coordinator)
            return container
        } catch {
            fatalError("Could not create preview data: \(error)")
        }
    }

    static func coordinator(for container: ModelContainer) -> PlanEvidenceMutationCoordinator {
        if let coordinator = coordinators[ObjectIdentifier(container)] {
            return coordinator
        }
        let coordinator = PlanEvidenceMutationCoordinator(modelContainer: container)
        coordinators[ObjectIdentifier(container)] = coordinator
        return coordinator
    }

    static func seed(
        _ context: ModelContext,
        state: DesignReviewState = .normal,
        coordinator: PlanEvidenceMutationCoordinator
    ) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        switch state {
        case .adaptiveCollecting:
            try seedAdaptiveCollecting(context, coordinator: coordinator, now: .now, calendar: calendar)
            return
        case .adaptiveProposal:
            try seedAdaptiveProposal(context, coordinator: coordinator, now: .now, calendar: calendar)
            return
        case .adaptiveApplied:
            try seedAdaptiveProposal(
                context,
                coordinator: coordinator,
                now: .now,
                calendar: calendar,
                applyProposal: true
            )
            return
        default:
            break
        }

        let foods = [
            Food(
                name: "Almond Milk",
                calories: 15,
                servingGrams: 100,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 0.3,
                    proteinGrams: 0.6,
                    fatGrams: 1.1,
                    fiberGrams: 0.2
                )
            ),
            Food(
                name: "Oatmeal with Blueberries",
                calories: 360,
                servingGrams: 280,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 62,
                    proteinGrams: 12,
                    fatGrams: 7,
                    fiberGrams: 9
                )
            ),
            Food(
                name: "Grilled Chicken & Quinoa Bowl",
                calories: 540,
                servingGrams: 420,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 55,
                    proteinGrams: 48,
                    fatGrams: 17,
                    fiberGrams: 10
                )
            ),
            Food(
                name: "Greek Yogurt & Honey",
                calories: 180,
                servingGrams: 200,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 25,
                    proteinGrams: 20,
                    fatGrams: 5,
                    fiberGrams: 0
                )
            ),
            Food(
                name: "Salmon, Roasted Potatoes & Greens",
                calories: 520,
                servingGrams: 460,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 45,
                    proteinGrams: 38,
                    fatGrams: 22,
                    fiberGrams: 8
                )
            ),
            Food(
                name: "Dark Chocolate",
                calories: 120,
                servingGrams: 22,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 10,
                    proteinGrams: 2,
                    fatGrams: 9,
                    fiberGrams: 2
                )
            ),
            Food(
                name: "Whole Grain Sourdough Toast with Avocado and Poached Eggs",
                calories: 430,
                servingGrams: 310,
                nutrientsPerServing: FoodNutrients(
                    carbohydratesGrams: 35,
                    proteinGrams: 20,
                    fatGrams: 24,
                    fiberGrams: 10
                )
            )
        ]
        foods.forEach(context.insert)

        context.insert(UserProfile(
            currentWeight: 70.2,
            targetWeight: 68,
            age: 30,
            dailyCalorieGoal: 1_700,
            targetDate: calendar.date(byAdding: .day, value: 90, to: today) ?? .now
        ))

        guard state != .empty else {
            try context.save()
            return
        }

        func mealDate(hour: Int, dayOffset: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
        }

        func nutrientsForMeal(_ name: String, calories: Int) -> FoodNutrients {
            if state == .nutritionImbalanced {
                switch name {
                case "Oatmeal with Blueberries":
                    return FoodNutrients(
                        carbohydratesGrams: 40,
                        proteinGrams: 3,
                        fatGrams: 20,
                        fiberGrams: 4
                    )
                case "Grilled Chicken & Quinoa Bowl":
                    return FoodNutrients(
                        carbohydratesGrams: 35,
                        proteinGrams: 5,
                        fatGrams: 20,
                        fiberGrams: 3
                    )
                case "Greek Yogurt & Honey":
                    return FoodNutrients(
                        carbohydratesGrams: 25,
                        proteinGrams: 2,
                        fatGrams: 10,
                        fiberGrams: 1
                    )
                default:
                    break
                }
            }
            if state == .nutritionPartial, name == "Greek Yogurt & Honey" {
                return FoodNutrients(proteinGrams: 20, fatGrams: 5)
            }
            guard let food = foods.first(where: { $0.name == name }), food.calories > 0 else {
                return .empty
            }
            return food.nutrientsPerServing.scaled(by: Double(calories) / Double(food.calories))
        }

        func addTodayMeal(
            _ name: String,
            calories: Int,
            amount: Double,
            mealType: MealType,
            hour: Int
        ) {
            context.insert(PlateEntry(
                foodName: name,
                calories: calories,
                weightGrams: amount,
                quantity: 1,
                nutrients: nutrientsForMeal(name, calories: calories),
                mealType: mealType.rawValue,
                date: mealDate(hour: hour)
            ))
        }

        if state == .customNutrition {
            context.insert(PlateEntry(
                foodName: "Fixture Bowl",
                calories: 120,
                weightGrams: 100,
                quantity: 1,
                nutrients: FoodNutrients(
                    carbohydratesGrams: 15,
                    proteinGrams: 10,
                    fatGrams: 2,
                    fiberGrams: 4
                ),
                mealType: MealType.snack.rawValue,
                date: mealDate(hour: 12)
            ))
            try context.save()
            return
        }

        addTodayMeal(
            "Oatmeal with Blueberries",
            calories: 360,
            amount: 280,
            mealType: .breakfast,
            hour: 8
        )
        addTodayMeal(
            "Grilled Chicken & Quinoa Bowl",
            calories: 540,
            amount: 420,
            mealType: .lunch,
            hour: 13
        )
        addTodayMeal(
            "Greek Yogurt & Honey",
            calories: 180,
            amount: 200,
            mealType: .dinner,
            hour: 19
        )

        if state == .nearTarget || state == .exceeded {
            addTodayMeal(
                "Salmon, Roasted Potatoes & Greens",
                calories: state == .exceeded ? 720 : 520,
                amount: 460,
                mealType: .dinner,
                hour: 19
            )
        }

        if state == .exceeded {
            addTodayMeal(
                "Dark Chocolate",
                calories: 120,
                amount: 22,
                mealType: .snack,
                hour: 21
            )
        }

        if state == .longContent {
            addTodayMeal(
                "Whole Grain Sourdough Toast with Avocado and Poached Eggs",
                calories: 430,
                amount: 310,
                mealType: .breakfast,
                hour: 9
            )
            for index in 0..<8 {
                addTodayMeal(
                    "Greek Yogurt & Honey",
                    calories: 90 + index * 5,
                    amount: 100 + Double(index) * 10,
                    mealType: index.isMultiple(of: 2) ? .snack : .lunch,
                    hour: 10 + index
                )
            }
        }

        let historicalCalories = [1_610, 1_745, 1_530, 1_680, 1_820, 1_590, 1_705, 1_655, 1_480, 1_760, 1_625, 1_690, 1_550]
        for (index, calories) in historicalCalories.enumerated() {
            let dayOffset = -(index + 1)
            let historicalMeals: [(String, Int, Double, MealType, Int)] = [
                ("Oatmeal with Blueberries", calories * 3 / 10, 280, .breakfast, 8),
                ("Grilled Chicken & Quinoa Bowl", calories * 4 / 10, 420, .lunch, 13),
                ("Greek Yogurt & Honey", calories - calories * 3 / 10 - calories * 4 / 10, 200, .dinner, 19)
            ]
            for meal in historicalMeals {
                context.insert(PlateEntry(
                    foodName: meal.0,
                    calories: meal.1,
                    weightGrams: meal.2,
                    quantity: 1,
                    nutrients: nutrientsForMeal(meal.0, calories: meal.1),
                    mealType: meal.3.rawValue,
                    date: mealDate(hour: meal.4, dayOffset: dayOffset)
                ))
            }
            context.insert(WeightEntry(
                date: mealDate(hour: 8, dayOffset: dayOffset),
                kilograms: 70.9 - Double(index) * 0.06
            ))
        }

        context.insert(WaterDay(date: .now, glasses: state == .exceeded ? 8 : 5))
        context.insert(WeightEntry(kilograms: 70.2))
        try context.save()
    }

    static func seedAdaptiveProposal(
        _ context: ModelContext,
        coordinator: PlanEvidenceMutationCoordinator,
        now: Date = .now,
        calendar: Calendar = .current,
        applyProposal: Bool = false
    ) throws {
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(byAdding: .day, value: -42, to: today) else {
            throw CocoaError(.coderInvalidValue)
        }
        let plan = try adaptiveFixturePlan(now: firstDay, calendar: calendar)
        let profile = try coordinator.acceptCalculatedPlan(
            plan,
            measurementSystem: .metric,
            acceptedAt: firstDay
        )
        _ = try coordinator.enableAdaptiveCheckIns(
            supportedScopeConfirmed: true,
            enabledAt: firstDay
        )

        for offset in 0..<42 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let mealDate = calendar.date(byAdding: .hour, value: 12, to: day),
                  let weightDate = calendar.date(byAdding: .hour, value: 8, to: day) else {
                throw CocoaError(.coderInvalidValue)
            }
            let plate = PlateEntry(
                foodName: "Complete fixture day",
                calories: 2_100,
                weightGrams: 1,
                quantity: 1,
                mealType: MealType.dinner.rawValue,
                date: mealDate
            )
            context.insert(plate)
            context.insert(FoodLogCompletion(
                components: calendar.dateComponents([.era, .year, .month, .day], from: day),
                calendarIdentifier: String(describing: calendar.identifier),
                timeZoneIdentifier: calendar.timeZone.identifier,
                dayStart: day,
                attestedAt: day,
                attestedCalories: plate.calories,
                canonicalPlateSnapshotData: try AdaptivePlanPersistenceCoding.encodePlateSnapshot([
                    PlateEvidenceSnapshot(
                        stableID: plate.stableID,
                        dateBitPattern: plate.date.timeIntervalSinceReferenceDate.bitPattern,
                        calories: plate.calories
                    )
                ])
            ))
            context.insert(WeightEntry(
                date: weightDate,
                kilograms: 75 - Double(offset) * 0.01,
                sequence: Int64(offset + 1)
            ))
        }
        try context.save()

        let result = try coordinator.evaluate(
            expectedPlanRevisionID: profile.currentPlanRevisionID,
            expectedEvidenceRevision: profile.evidenceRevision
        )
        guard case .pending(let proposal) = result else {
            throw CocoaError(.coderInvalidValue)
        }
        if applyProposal {
            _ = try coordinator.applyPendingProposal(
                id: proposal.id,
                expectedPlanRevisionID: proposal.expectedPlanRevisionID,
                expectedEvidenceRevision: proposal.expectedEvidenceRevision,
                expectedEvidenceSignature: proposal.evidenceSignature
            )
            context.rollback()
            guard try context.fetch(FetchDescriptor<UserProfile>()).first?.planGoalSource == .adapted else {
                throw CocoaError(.coderInvalidValue)
            }
        }
    }

    private static func seedAdaptiveCollecting(
        _ context: ModelContext,
        coordinator: PlanEvidenceMutationCoordinator,
        now: Date,
        calendar: Calendar
    ) throws {
        let plan = try adaptiveFixturePlan(now: now, calendar: calendar)
        _ = try coordinator.acceptCalculatedPlan(
            plan,
            measurementSystem: .metric,
            acceptedAt: now
        )
        _ = try coordinator.enableAdaptiveCheckIns(supportedScopeConfirmed: true)
    }

    private static func adaptiveFixturePlan(
        now: Date,
        calendar: Calendar
    ) throws -> CalculatedCaloriePlan {
        let input = CaloriePlanInput(
            goalMode: .lose,
            currentWeightKilograms: 75,
            targetWeightKilograms: 70,
            age: 30,
            heightCentimeters: 170,
            equation: .female,
            activityLevel: .moderate,
            paceBasis: .weeklyRate,
            weeklyRateKilograms: 0.25,
            targetDate: nil
        )
        guard case .recommendation(let plan) = CalculatedCaloriePlanCalculator.evaluate(
            input,
            now: now,
            calendar: calendar
        ) else {
            throw CocoaError(.coderInvalidValue)
        }
        return plan
    }
}

extension View {
    @MainActor
    func previewPlanEvidenceContainer(_ container: ModelContainer) -> some View {
        modelContainer(container)
            .environment(
                \.planEvidenceMutationCoordinator,
                PreviewData.coordinator(for: container)
            )
    }
}
#endif
