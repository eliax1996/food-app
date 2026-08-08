#if DEBUG
import Foundation
import SwiftData

enum DesignReviewState: String, CaseIterable {
    case normal
    case empty
    case nearTarget
    case exceeded
    case longContent

    static var current: DesignReviewState {
        let rawValue = ProcessInfo.processInfo.environment["DESIGN_REVIEW_STATE"] ?? "normal"
        return DesignReviewState(rawValue: rawValue) ?? .normal
    }
}

@MainActor
enum PreviewData {
    static func makeContainer(state: DesignReviewState = .normal) -> ModelContainer {
        let schema = Schema([
            Food.self,
            PlateEntry.self,
            WaterDay.self,
            WeightEntry.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            try seed(container.mainContext, state: state)
            return container
        } catch {
            fatalError("Could not create preview data: \(error)")
        }
    }

    static func seed(
        _ context: ModelContext,
        state: DesignReviewState = .normal
    ) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let foods = [
            Food(name: "Almond Milk", calories: 15, servingGrams: 100),
            Food(name: "Oatmeal with Blueberries", calories: 360, servingGrams: 280),
            Food(name: "Grilled Chicken & Quinoa Bowl", calories: 540, servingGrams: 420),
            Food(name: "Greek Yogurt & Honey", calories: 180, servingGrams: 200),
            Food(name: "Salmon, Roasted Potatoes & Greens", calories: 520, servingGrams: 460),
            Food(name: "Dark Chocolate", calories: 120, servingGrams: 22),
            Food(
                name: "Whole Grain Sourdough Toast with Avocado and Poached Eggs",
                calories: 430,
                servingGrams: 310
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
                mealType: mealType.rawValue,
                date: mealDate(hour: hour)
            ))
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
            mealType: .snack,
            hour: 16
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
            context.insert(PlateEntry(
                foodName: "Recorded meals",
                calories: calories,
                weightGrams: 1,
                quantity: 1,
                mealType: MealType.dinner.rawValue,
                date: mealDate(hour: 19, dayOffset: dayOffset)
            ))
            context.insert(WeightEntry(
                date: mealDate(hour: 8, dayOffset: dayOffset),
                kilograms: 70.9 - Double(index) * 0.06
            ))
        }

        context.insert(WaterDay(date: .now, glasses: state == .exceeded ? 8 : 5))
        context.insert(WeightEntry(kilograms: 70.2))
        try context.save()
    }
}
#endif
