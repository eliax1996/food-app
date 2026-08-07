import SwiftUI
import SwiftData

@main
struct CountCaloriesApp: App {
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
