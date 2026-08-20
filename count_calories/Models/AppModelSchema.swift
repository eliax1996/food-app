import SwiftData

@MainActor
enum AppModelSchema {
    static func make() -> Schema {
        Schema([
            Food.self,
            PlateEntry.self,
            FoodLogCompletion.self,
            BulkFoodBatchOperation.self,
            WaterDay.self,
            WeightEntry.self,
            UserProfile.self,
            AppMigrationState.self,
            HistoricalPlateDeletionOperation.self
        ])
    }
}
