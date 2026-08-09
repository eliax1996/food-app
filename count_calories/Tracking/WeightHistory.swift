import Foundation

nonisolated enum WeightHistoryError: Error, Equatable {
    case invalidWeight
    case invalidTimestamp
    case futureTimestamp
    case sequenceOverflow
}

nonisolated struct WeightHistorySection: Equatable, Sendable {
    let date: Date
    let entries: [WeightProgressPoint]
}

nonisolated enum WeightHistory {
    static func isValidWeight(_ kilograms: Double) -> Bool {
        kilograms.isFinite && kilograms > 0
    }

    static func validatedWeight(_ kilograms: Double) throws -> Double {
        guard isValidWeight(kilograms) else {
            throw WeightHistoryError.invalidWeight
        }
        return kilograms
    }

    /// Combines displayed local components. New ambiguous wall times resolve to first occurrence.
    /// Existing entries retain original instant if displayed date and time are unchanged.
    static func combinedTimestamp(
        date: Date,
        time: Date,
        originalTimestamp: Date? = nil,
        calendar: Calendar = .current,
        now: Date = .now
    ) throws -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
        var components = dateComponents
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond

        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute else {
            throw WeightHistoryError.invalidTimestamp
        }

        if let originalTimestamp,
           visibleComponents(of: originalTimestamp, calendar: calendar) == VisibleDateTime(
               year: year,
               month: month,
               day: day,
               hour: hour,
               minute: minute
           ) {
            guard originalTimestamp <= now else {
                throw WeightHistoryError.futureTimestamp
            }
            return originalTimestamp
        }

        var dayComponents = DateComponents()
        dayComponents.calendar = calendar
        dayComponents.timeZone = calendar.timeZone
        dayComponents.year = year
        dayComponents.month = month
        dayComponents.day = day
        guard let localDay = calendar.date(from: dayComponents) else {
            throw WeightHistoryError.invalidTimestamp
        }

        var matching = DateComponents()
        matching.hour = hour
        matching.minute = minute
        matching.second = components.second ?? 0
        matching.nanosecond = components.nanosecond ?? 0
        // `.first` is deliberate: new repeated fall-back wall times use first occurrence.
        guard let timestamp = calendar.nextDate(
            after: localDay.addingTimeInterval(-1),
            matching: matching,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            throw WeightHistoryError.invalidTimestamp
        }

        guard visibleComponents(of: timestamp, calendar: calendar) == VisibleDateTime(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ) else {
            throw WeightHistoryError.invalidTimestamp
        }
        guard timestamp <= now else {
            throw WeightHistoryError.futureTimestamp
        }
        return timestamp
    }

    static func sortedOldestFirst(_ entries: [WeightProgressPoint]) -> [WeightProgressPoint] {
        entries.enumerated().sorted { first, second in
            isOlder(first.element, than: second.element, hostlessOffsets: (first.offset, second.offset))
        }.map(\.element)
    }

    static func isNewer(
        date leftDate: Date,
        sequence leftSequence: Int64,
        stableID leftStableID: UUID,
        than rightDate: Date,
        sequence rightSequence: Int64,
        stableID rightStableID: UUID
    ) -> Bool {
        isOlder(
            WeightProgressPoint(date: rightDate, kilograms: 1, stableID: rightStableID, sequence: rightSequence),
            than: WeightProgressPoint(date: leftDate, kilograms: 1, stableID: leftStableID, sequence: leftSequence),
            hostlessOffsets: (0, 0)
        )
    }

    static func localDaySections(
        for entries: [WeightProgressPoint],
        calendar: Calendar = .current
    ) -> [WeightHistorySection] {
        let validEntries = entries.filter { isValidWeight($0.kilograms) }
        let groups = Dictionary(grouping: validEntries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return groups
            .map { day, entries in
                WeightHistorySection(
                    date: day,
                    entries: sortedOldestFirst(entries).reversed()
                )
            }
            .sorted { $0.date > $1.date }
    }

    static func latestValidMeasurement(
        from entries: [WeightProgressPoint],
        now: Date = .now
    ) -> WeightProgressPoint? {
        sortedOldestFirst(
            entries.filter { isValidWeight($0.kilograms) && $0.date <= now }
        ).last
    }

    private static func isOlder(
        _ left: WeightProgressPoint,
        than right: WeightProgressPoint,
        hostlessOffsets: (Int, Int)
    ) -> Bool {
        if left.date != right.date {
            return left.date < right.date
        }

        switch (left.stableID, right.stableID) {
        case let (leftID?, rightID?):
            let leftSequence = left.sequence ?? 0
            let rightSequence = right.sequence ?? 0
            if leftSequence != rightSequence {
                return leftSequence < rightSequence
            }
            return leftID.uuidString < rightID.uuidString
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            // Compatibility only: hostless callers have no persisted tie-breaker.
            return hostlessOffsets.0 < hostlessOffsets.1
        }
    }

    private static func visibleComponents(of date: Date, calendar: Calendar) -> VisibleDateTime {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return VisibleDateTime(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }

    private struct VisibleDateTime: Equatable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
    }
}
