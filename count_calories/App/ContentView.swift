import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = AppTab.counter
    @State private var addMealRequestID: UUID?
    @State private var waterAdjustmentRequest: WaterAdjustmentRequest?

    var body: some View {
        TabView(selection: $selectedTab) {
            CalorieCounterView(
                addMealRequestID: $addMealRequestID,
                waterAdjustmentRequest: $waterAdjustmentRequest
            )
                .tabItem {
                    Label("Counter", systemImage: "flame.fill")
                }
                .tag(AppTab.counter)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.history)

            ConfigView()
                .tabItem {
                    Label("Config", systemImage: "gearshape.fill")
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
    case history
    case config
}

#if DEBUG
#Preview("Complete app") {
    ContentView()
        .modelContainer(PreviewData.makeContainer())
}
#endif
