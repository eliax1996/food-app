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
        synchronizeExternalSurfaces: ((ModelContext, Calendar) -> Void)? = nil
    ) throws {
        let context = container.mainContext
        guard
            let summary = WidgetDailySummaryStore.load(),
            calendar.isDate(summary.date, inSameDayAs: now)
        else {
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

        guard
            day.glasses != summary.waterGlasses
                || day.lastRecordedAt != summary.lastWaterRecordedAt
        else {
            WidgetDailySummaryStore.acknowledgeWaterRevision(summary.resolvedRevision)
            return
        }

        let addedWater = summary.waterGlasses > day.glasses
        day.glasses = min(max(0, summary.waterGlasses), 30)
        day.lastRecordedAt = summary.lastWaterRecordedAt
            ?? (addedWater ? now : day.lastRecordedAt)
        try context.save()
        WidgetDailySummaryStore.acknowledgeWaterRevision(summary.resolvedRevision)
        if let synchronizeExternalSurfaces {
            synchronizeExternalSurfaces(context, calendar)
        } else {
            TodayExternalSurfaceCoordinator.synchronize(
                modelContext: context,
                calendar: calendar
            )
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
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard !arguments.contains("-ui-testing"), !arguments.contains("-design-review") else {
            return
        }
#endif
        do {
            try WidgetWaterImportService.synchronize(in: modelContainer)
        } catch {
            AppLogger.persistence.error(
                "Failed to import widget water: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
