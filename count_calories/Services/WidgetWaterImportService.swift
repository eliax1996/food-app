import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
enum WidgetWaterImportService {
    static func synchronize(
        in container: ModelContainer,
        calendar: Calendar = .current,
        now: Date = .now,
        synchronizeExternalSurfaces: ((ModelContext, Calendar) -> Void)? = nil,
        loadSummary: @MainActor () -> WidgetDailySummary? = { WidgetDailySummaryStore.load() },
        acknowledgeRevision: @MainActor (Int64) -> Bool = {
            WidgetDailySummaryStore.acknowledgeWaterRevision($0)
        }
    ) throws {
        let operation = AppLogger.begin(
            "widget.water_import",
            category: .integrations,
            source: "app_lifecycle"
        )
        let context = container.mainContext
        do {
            var importedValue = false
            for _ in 0..<3 {
                guard
                    let summary = loadSummary(),
                    calendar.isDate(summary.date, inSameDayAs: now),
                    summary.resolvedRevision > 0
                else {
                    if importedValue {
                        AppLogger.succeed(operation)
                    } else {
                        AppLogger.noop(operation, reason: "no_current_summary")
                    }
                    return
                }

                let days = try context.fetch(FetchDescriptor<WaterDay>())
                let day: WaterDay
                if let existing = days.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
                    day = existing
                } else {
                    day = WaterDay(date: now)
                    context.insert(day)
                }

                if day.glasses != summary.waterGlasses
                    || day.lastRecordedAt != summary.lastWaterRecordedAt {
                    let addedWater = summary.waterGlasses > day.glasses
                    day.glasses = min(max(0, summary.waterGlasses), 30)
                    day.lastRecordedAt = summary.lastWaterRecordedAt
                        ?? (addedWater ? now : day.lastRecordedAt)
                    try context.save()
                    importedValue = true
                }

                guard acknowledgeRevision(summary.resolvedRevision) else {
                    continue // New widget revision won; reread and import it before fan-out.
                }
                if let synchronizeExternalSurfaces {
                    synchronizeExternalSurfaces(context, calendar)
                } else {
                    TodayExternalSurfaceCoordinator.synchronize(
                        modelContext: context,
                        calendar: calendar
                    )
                }
                if importedValue {
                    AppLogger.succeed(operation)
                } else {
                    AppLogger.noop(operation, reason: "already_current")
                }
                return
            }
            AppLogger.partial(operation, failedComponent: "widget_acknowledgement_race")
        } catch {
            context.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            throw error
        }
    }
}

struct WidgetWaterImportModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    func body(content: Content) -> some View {
        content
            .onAppear(perform: synchronize)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                synchronize()
            }
    }

    private func synchronize() {
#if DEBUG || RELEASE_VALIDATION
        let arguments = ProcessInfo.processInfo.arguments
        guard !arguments.contains("-ui-testing"), !arguments.contains("-design-review") else {
            return
        }
#endif
        do {
            try WidgetWaterImportService.synchronize(in: modelContainer)
        } catch {
            // Service emits one correlated failure event with rollback state.
        }
    }
}
