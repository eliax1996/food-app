import SwiftData
import SwiftUI

private struct AutomaticSetupPresentation: Identifiable {
    let id = UUID()
    let record: CaloriePlanSetupRecord
}

struct ContentView: View {
    @Query private var profiles: [UserProfile]

    @State private var selectedTab = AppTab.counter
    @State private var selectedProgressMetric = HistoryMetric.calories
    @State private var addMealRequestID: UUID?
    @State private var waterAdjustmentRequest: WaterAdjustmentRequest?
    @State private var automaticSetupPresentation: AutomaticSetupPresentation?
    @State private var checkedAutomaticSetup = false

    var body: some View {
        TabView(selection: $selectedTab) {
            CalorieCounterView(
                addMealRequestID: $addMealRequestID,
                waterAdjustmentRequest: $waterAdjustmentRequest
            )
                .tabItem {
                    Label("Today", systemImage: "flame.fill")
                        .accessibilityIdentifier("today-tab")
                }
                .tag(AppTab.counter)

            WeightLogView(onViewProgress: {
                selectedProgressMetric = .weight
                selectedTab = .history
            })
                .tabItem {
                    Label("Weight", systemImage: "scalemass.fill")
                        .accessibilityIdentifier("weight-tab")
                }
                .tag(AppTab.weight)

            HistoryView(selectedMetric: $selectedProgressMetric)
                .tabItem {
                    Label("Progress", systemImage: "chart.xyaxis.line")
                        .accessibilityIdentifier("progress-tab")
                }
                .tag(AppTab.history)

            ConfigView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                        .accessibilityIdentifier("settings-tab")
                }
                .tag(AppTab.config)
        }
        .task {
            guard !checkedAutomaticSetup else { return }
            checkedAutomaticSetup = true
            let loadedRecord = CaloriePlanSetupStore.load(profileExists: !profiles.isEmpty)
            let record = CaloriePlanSetupStore.reconciledAfterAcceptedCalculation(
                loadedRecord,
                acceptedPlanDate: profiles.first?.storedCalculatedPlan?.acceptedAt
            )
            if record != loadedRecord {
                CaloriePlanSetupStore.save(record)
            }
            guard CaloriePlanSetupStore.shouldPresentAutomatically(
                record: record
            ) else { return }
            automaticSetupPresentation = AutomaticSetupPresentation(record: record)
        }
        .sheet(item: $automaticSetupPresentation) { presentation in
            CaloriePlanSetupView(
                profile: profiles.first,
                record: presentation.record
            ) {
                automaticSetupPresentation = nil
            }
        }
        .onOpenURL { url in
            guard url.scheme == "countcalories" else { return }
            selectedTab = .counter
            guard let action = AppDeepLinkAction(url: url) else { return }

            switch action {
            case .addMeal:
                addMealRequestID = UUID()
            case .adjustWater(let delta):
                waterAdjustmentRequest = WaterAdjustmentRequest(delta: delta)
            }
        }
    }
}

struct WaterAdjustmentRequest: Equatable {
    let id = UUID()
    let delta: Int
}

private enum AppTab: Hashable {
    case counter
    case weight
    case history
    case config
}

#if DEBUG
#Preview("Complete app") {
    ContentView()
        .previewPlanEvidenceContainer(PreviewData.makeContainer())
}

#Preview("Complete app — Small", traits: .fixedLayout(width: 375, height: 667)) {
    ContentView()
        .previewPlanEvidenceContainer(PreviewData.makeContainer())
}

#Preview("Complete app — Empty", traits: .fixedLayout(width: 375, height: 667)) {
    ContentView()
        .previewPlanEvidenceContainer(PreviewData.makeContainer(state: .empty))
}

#Preview("Complete app — Dense", traits: .fixedLayout(width: 430, height: 932)) {
    ContentView()
        .previewPlanEvidenceContainer(PreviewData.makeContainer(state: .longContent))
}

#Preview("Complete app — Over goal", traits: .fixedLayout(width: 430, height: 932)) {
    ContentView()
        .previewPlanEvidenceContainer(PreviewData.makeContainer(state: .exceeded))
}
#endif
