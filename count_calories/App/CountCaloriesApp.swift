import SwiftData
import SwiftUI

@main
struct CountCaloriesApp: App {
    private let arguments = ProcessInfo.processInfo.arguments

    private var usesInMemoryStore: Bool {
#if DEBUG
        arguments.contains("-ui-testing") || arguments.contains("-design-review")
#else
        false
#endif
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if arguments.contains("-ui-testing") {
                UITestingRoot()
            } else if arguments.contains("-design-review") {
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
private struct UITestingRoot: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady = false
    @State private var showingCalculatedSetup = ProcessInfo.processInfo.arguments.contains(
        "-ui-testing-calculated-setup"
    ) || ProcessInfo.processInfo.arguments.contains(
        "-ui-testing-calculated-pace"
    ) || ProcessInfo.processInfo.arguments.contains(
        "-ui-testing-calculated-review"
    )

    private var calculatedSetupRecord: CaloriePlanSetupRecord {
        var draft = CaloriePlanSetupDraft()
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-calculated-pace")
            || ProcessInfo.processInfo.arguments.contains("-ui-testing-calculated-review") {
            draft.step = ProcessInfo.processInfo.arguments.contains("-ui-testing-calculated-review")
                ? .review
                : .pace
            draft.goalMode = .lose
            draft.heightCentimeters = 170
            draft.equation = .female
            draft.activityLevel = .moderate
            draft.eligibilityConfirmed = true
        }
        return CaloriePlanSetupRecord(status: .inProgress, draft: draft)
    }

    var body: some View {
        Group {
            if isReady, showingCalculatedSetup {
                CaloriePlanSetupView(
                    profile: nil,
                    record: calculatedSetupRecord
                ) {
                    showingCalculatedSetup = false
                }
            } else if isReady {
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
        ReminderPreferences().store()
        CaloriePlanSetupStore.save(CaloriePlanSetupRecord(
            status: .skipped,
            draft: CaloriePlanSetupDraft()
        ))
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
