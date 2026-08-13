import Combine
import SwiftData
import SwiftUI
import os

@MainActor
final class AppPersistence: ObservableObject {
    struct Ready {
        let modelContainer: ModelContainer
        let mutationCoordinator: PlanEvidenceMutationCoordinator
    }

    @Published private(set) var ready: Ready?
    @Published private(set) var hasError = false

    private let makeContainer: () throws -> ModelContainer

    init(makeContainer: @escaping () throws -> ModelContainer) {
        self.makeContainer = makeContainer
        retry()
    }

    func retry() {
        do {
            let container = try makeContainer()
            ready = Ready(
                modelContainer: container,
                mutationCoordinator: PlanEvidenceMutationCoordinator(modelContainer: container)
            )
            hasError = false
        } catch {
            ready = nil
            hasError = true
            AppLogger.persistence.error(
                "Failed to open persistent store: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

@main
struct CountCaloriesApp: App {
    private let arguments: [String]
    @StateObject private var persistence: AppPersistence

    @MainActor
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        self.arguments = arguments
#if DEBUG
        let usesInMemoryStore = arguments.contains("-ui-testing") || arguments.contains("-design-review")
#else
        let usesInMemoryStore = false
#endif
        let schema = Schema([
            Food.self,
            PlateEntry.self,
            FoodLogCompletion.self,
            BulkFoodBatchOperation.self,
            WaterDay.self,
            WeightEntry.self,
            UserProfile.self
        ])
        _persistence = StateObject(wrappedValue: AppPersistence {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: usesInMemoryStore
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        })
    }

    var body: some Scene {
        WindowGroup {
            if let ready = persistence.ready {
                Group {
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
                .modelContainer(ready.modelContainer)
                .environment(\.planEvidenceMutationCoordinator, ready.mutationCoordinator)
                .modifier(WidgetWaterImportModifier(modelContainer: ready.modelContainer))
            } else {
                ContentUnavailableView {
                    Label("Saved data unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Count Calories couldn’t open its saved data. Nothing was deleted. Try again after storage becomes available.")
                } actions: {
                    Button("Try Again", action: persistence.retry)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("retry-persistent-store")
                }
                .accessibilityIdentifier("persistent-store-error")
            }
        }
    }
}

#if DEBUG
private struct UITestingRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
    @State private var contentModelContext: ModelContext?
    @State private var preparationError: String?
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
            } else if let preparationError {
                ContentUnavailableView(
                    "Test data failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(preparationError)
                )
                .accessibilityIdentifier("ui-test-preparation-error")
            } else {
                ProgressView("Preparing test data")
                    .accessibilityIdentifier("ui-test-preparing")
                    .task {
                        do {
                            guard let mutationCoordinator else {
                                throw PlanEvidenceMutationError.coordinatorUnavailable
                            }
                            let fixtureContext = mutationCoordinator.testingModelContext
                            try await resetStore(in: fixtureContext)
                            let seededFixture = try seedAdaptiveFixtureIfRequested(
                                in: fixtureContext,
                                coordinator: mutationCoordinator
                            )
                            if !seededFixture {
                                try seedDefaultProfileIfNeeded(in: fixtureContext)
                            }
                            let contentContext = ModelContext(modelContext.container)
                            if ProcessInfo.processInfo.arguments.contains("-ui-testing-adaptive-applied") {
                                try mutationCoordinator.ensureAppliedFixtureVisibleForTesting()
                                contentContext.rollback()
                                guard try contentContext.fetch(FetchDescriptor<UserProfile>()).first?.planGoalSource == .adapted else {
                                    throw CocoaError(.coderInvalidValue)
                                }
                            }
                            contentModelContext = contentContext
                            isReady = true
                        } catch {
                            preparationError = String(describing: error)
                            assertionFailure("Could not reset UI-test data: \(error)")
                        }
                    }
            }
        }
        .environment(\.modelContext, contentModelContext ?? modelContext)
    }

    private func seedAdaptiveFixtureIfRequested(
        in context: ModelContext,
        coordinator: PlanEvidenceMutationCoordinator
    ) throws -> Bool {
        let process = ProcessInfo.processInfo
        let fixture = process.environment["UI_TEST_ADAPTIVE_FIXTURE"]
        let seeded: Bool
        if fixture == "proposal" || process.arguments.contains("-ui-testing-adaptive-proposal") {
            try seedAdaptiveProposalFixture(in: context, coordinator: coordinator)
            seeded = true
        } else if fixture == "partial-cap" || process.arguments.contains("-ui-testing-adaptive-partial-cap") {
            try seedAdaptiveProposalFixture(in: context, coordinator: coordinator)
            try coordinator.configurePartialCapProposalForTesting(usedCalories: 120)
            seeded = true
        } else if fixture == "applied" || process.arguments.contains("-ui-testing-adaptive-applied") {
            try PreviewData.seedAdaptiveProposal(
                context,
                coordinator: coordinator,
                applyProposal: true
            )
            seeded = true
        } else if fixture == "collecting" || process.arguments.contains("-ui-testing-adaptive-collecting") {
            try PreviewData.seed(
                context,
                state: .adaptiveCollecting,
                coordinator: coordinator
            )
            seeded = true
        } else if fixture == "manual" || process.arguments.contains("-ui-testing-adaptive-manual") {
            context.insert(UserProfile(dailyCalorieGoal: 1_700, planGoalSource: .manual))
            try context.save()
            seeded = true
        } else if fixture == "unknown" || process.arguments.contains("-ui-testing-adaptive-unknown") {
            context.insert(UserProfile(
                dailyCalorieGoal: 1_700,
                rawPlanGoalSource: "future-source"
            ))
            try context.save()
            seeded = true
        } else {
            seeded = false
        }
        context.rollback()
        return seeded
    }

    private func seedAdaptiveProposalFixture(
        in context: ModelContext,
        coordinator: PlanEvidenceMutationCoordinator
    ) throws {
        try PreviewData.seedAdaptiveProposal(context, coordinator: coordinator)
    }

    private func seedDefaultProfileIfNeeded(in context: ModelContext) throws {
        let arguments = ProcessInfo.processInfo.arguments
        let calculatedSetupIsVisible = arguments.contains("-ui-testing-calculated-setup")
            || arguments.contains("-ui-testing-calculated-pace")
            || arguments.contains("-ui-testing-calculated-review")
        if !calculatedSetupIsVisible {
            context.insert(UserProfile())
            try context.save()
        }
    }

    private func resetStore(in context: ModelContext) async throws {
        context.rollback()
        for completion in try context.fetch(FetchDescriptor<FoodLogCompletion>()) {
            context.delete(completion)
        }
        for operation in try context.fetch(FetchDescriptor<BulkFoodBatchOperation>()) {
            context.delete(operation)
        }
        let learningStore = try await BulkFoodLearningStore.applicationStore()
        try await learningStore.clear()
        let draftStore = try await BulkFoodDraftStore.applicationStore()
        let draftLease = await draftStore.acquireLease()
        try await draftStore.clear(lease: draftLease)
        for entry in try context.fetch(FetchDescriptor<PlateEntry>()) {
            context.delete(entry)
        }
        for food in try context.fetch(FetchDescriptor<Food>()) {
            context.delete(food)
        }
        for day in try context.fetch(FetchDescriptor<WaterDay>()) {
            context.delete(day)
        }
        for entry in try context.fetch(FetchDescriptor<WeightEntry>()) {
            context.delete(entry)
        }
        for profile in try context.fetch(FetchDescriptor<UserProfile>()) {
            context.delete(profile)
        }
        try context.save()

        if ProcessInfo.processInfo.arguments.contains("-ui-testing-bulk-draft") {
            let replacementLease = await draftStore.acquireLease()
            try await draftStore.save(
                BulkFoodDraft(
                    description: "100 g almond milk",
                    mealType: MealType.suggestedForCurrentTime.rawValue,
                    reviewItems: [BulkFoodReviewItemSnapshot(
                        id: UUID(),
                        sourceQuery: "almond milk",
                        query: "Almond Milk",
                        amount: 100,
                        unit: .grams,
                        amountOrigin: .explicitDescription,
                        selectedMatch: nil
                    )],
                    updatedAt: .now
                ),
                lease: replacementLease
            )
        }

        ReminderPreferences().store()
        CaloriePlanSetupStore.save(CaloriePlanSetupRecord(
            status: .skipped,
            draft: CaloriePlanSetupDraft()
        ))
    }
}

private struct DesignReviewRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
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
                            guard let mutationCoordinator else {
                                throw PlanEvidenceMutationError.coordinatorUnavailable
                            }
                            try PreviewData.seed(
                                modelContext,
                                state: DesignReviewState.current,
                                coordinator: mutationCoordinator
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
