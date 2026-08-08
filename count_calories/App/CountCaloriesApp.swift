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
