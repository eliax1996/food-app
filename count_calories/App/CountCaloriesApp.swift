import SwiftData
import SwiftUI

@main
struct CountCaloriesApp: App {
    private let arguments = ProcessInfo.processInfo.arguments

    private var usesInMemoryStore: Bool {
        arguments.contains("-ui-testing") || arguments.contains("-design-review")
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if arguments.contains("-design-review") {
                DesignReviewRoot()
            } else if arguments.contains("-ui-testing") {
                UITestingRoot()
            } else {
                ContentView()
            }
#else
            ContentView()
#endif
        }
        .modelContainer(
            for: [Food.self, PlateEntry.self, WaterDay.self, WeightEntry.self, UserProfile.self],
            inMemory: usesInMemoryStore
        )
    }
}

#if DEBUG
private struct UITestingRoot: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady = false

    var body: some View {
        Group {
            if isReady {
                ContentView()
            } else {
                ProgressView("Preparing test data")
                    .task {
                        do {
                            try resetStore()
                            isReady = true
                        } catch {
                            assertionFailure("Could not reset UI-test data: \(error)")
                        }
                    }
            }
        }
    }

    private func resetStore() throws {
        for entry in try modelContext.fetch(FetchDescriptor<PlateEntry>()) {
            modelContext.delete(entry)
        }
        for food in try modelContext.fetch(FetchDescriptor<Food>()) {
            modelContext.delete(food)
        }
        for day in try modelContext.fetch(FetchDescriptor<WaterDay>()) {
            modelContext.delete(day)
        }
        for entry in try modelContext.fetch(FetchDescriptor<WeightEntry>()) {
            modelContext.delete(entry)
        }
        for profile in try modelContext.fetch(FetchDescriptor<UserProfile>()) {
            modelContext.delete(profile)
        }
        try modelContext.save()
    }
}

private struct DesignReviewRoot: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady = false

    private var dynamicTypeSize: DynamicTypeSize {
        switch ProcessInfo.processInfo.environment["DESIGN_REVIEW_DYNAMIC_TYPE"] {
        case "accessibility1": .accessibility1
        case "accessibility2": .accessibility2
        case "accessibility3": .accessibility3
        case "accessibility4": .accessibility4
        case "accessibility5": .accessibility5
        case "normal", nil: .large
        default: .large
        }
    }

    private var colorScheme: ColorScheme? {
        switch ProcessInfo.processInfo.environment["DESIGN_REVIEW_APPEARANCE"] {
        case "light": .light
        case "dark": .dark
        case "system", nil: nil
        default: nil
        }
    }

    var body: some View {
        Group {
            if isReady {
                ContentView()
            } else {
                ProgressView("Preparing review data")
                    .task {
                        do {
                            try PreviewData.seed(
                                modelContext,
                                state: DesignReviewState.current
                            )
                            isReady = true
                        } catch {
                            assertionFailure("Could not seed design-review data: \(error)")
                        }
                    }
            }
        }
        .dynamicTypeSize(dynamicTypeSize)
        .preferredColorScheme(colorScheme)
    }
}
#endif
