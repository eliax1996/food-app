import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = AppTab.counter
    @State private var selectedProgressMetric = HistoryMetric.calories
    @State private var addMealRequestID: UUID?
    @State private var waterAdjustmentRequest: WaterAdjustmentRequest?

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
        .modelContainer(PreviewData.makeContainer())
}
#endif
