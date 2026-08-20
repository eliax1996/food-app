import Foundation

nonisolated enum NutritionOperationContext {
    @TaskLocal static var parentOperationID: UUID?

    static var parentIDText: String {
        parentOperationID?.uuidString ?? "none"
    }
}
