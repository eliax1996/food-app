#if DEBUG
import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static func makeContainer() -> ModelContainer {
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
            try seed(container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview data: \(error)")
        }
    }

    private static func seed(_ context: ModelContext) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let almondMilk = Food(name: "Almond Milk", calories: 15, servingGrams: 100)
        let apple = Food(name: "Apple", calories: 52, servingGrams: 100)
        context.insert(almondMilk)
        context.insert(apple)

        context.insert(PlateEntry(
            foodName: almondMilk.name,
            calories: 15,
            weightGrams: 100,
            quantity: 1,
            mealType: MealType.breakfast.rawValue,
            date: calendar.date(byAdding: .hour, value: 8, to: today) ?? today
        ))
        context.insert(PlateEntry(
            foodName: apple.name,
            calories: 78,
            weightGrams: 150,
            quantity: 1,
            mealType: MealType.snack.rawValue,
            date: calendar.date(byAdding: .hour, value: 15, to: today) ?? today
        ))

        for dayOffset in 1...6 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            context.insert(PlateEntry(
                foodName: "Preview meals",
                calories: 1_250 + dayOffset * 55,
                weightGrams: 100,
                quantity: 1,
                mealType: MealType.dinner.rawValue,
                date: date
            ))
            context.insert(WeightEntry(date: date, kilograms: 70.8 - Double(dayOffset) * 0.1))
        }

        context.insert(WaterDay(date: .now, glasses: 3))
        context.insert(WeightEntry(kilograms: 70.2))
        context.insert(UserProfile(
            currentWeight: 70.2,
            targetWeight: 68,
            age: 30,
            dailyCalorieGoal: 1_700
        ))
        try context.save()
    }
}
#endif
