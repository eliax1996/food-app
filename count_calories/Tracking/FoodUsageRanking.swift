import Foundation

nonisolated struct FoodUsageEvent: Equatable, Sendable {
    let foodName: String
    let date: Date
}

nonisolated enum FoodUsageRanking {
    static func recentNames(
        from events: [FoodUsageEvent],
        now: Date = .now,
        limit: Int = 5
    ) -> [String] {
        guard limit > 0 else { return [] }
        var seen = Set<String>()
        return events
            .filter { validEvent($0, now: now) }
            .sorted(by: eventOrder)
            .compactMap { event in
                let key = normalizedName(event.foodName)
                guard seen.insert(key).inserted else { return nil }
                return event.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .prefix(limit)
            .map { $0 }
    }

    static func unambiguousNames(
        _ rankedNames: [String],
        among savedFoodNames: [String]
    ) -> [String] {
        let counts = Dictionary(grouping: savedFoodNames.filter {
            !normalizedName($0).isEmpty
        }, by: normalizedName).mapValues { $0.count }
        return rankedNames.filter { counts[normalizedName($0)] == 1 }
    }

    static func frequentNames(
        from events: [FoodUsageEvent],
        now: Date = .now,
        excluding excludedNames: [String] = [],
        limit: Int = 5
    ) -> [String] {
        guard limit > 0 else { return [] }
        let excluded = Set(excludedNames.map(normalizedName))
        var aggregates: [String: (displayName: String, count: Int, latest: Date)] = [:]
        for event in events.filter({ validEvent($0, now: now) }) {
            let key = normalizedName(event.foodName)
            guard !excluded.contains(key) else { continue }
            let displayName = event.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let current = aggregates[key] {
                aggregates[key] = (
                    displayName: event.date > current.latest ? displayName : current.displayName,
                    count: current.count + 1,
                    latest: max(current.latest, event.date)
                )
            } else {
                aggregates[key] = (displayName, 1, event.date)
            }
        }

        return aggregates
            .map { (key: $0.key, value: $0.value) }
            .sorted { left, right in
                if left.value.count != right.value.count {
                    return left.value.count > right.value.count
                }
                if left.value.latest != right.value.latest {
                    return left.value.latest > right.value.latest
                }
                return left.key < right.key
            }
            .prefix(limit)
            .map(\.value.displayName)
    }

    private static func validEvent(_ event: FoodUsageEvent, now: Date) -> Bool {
        event.date.timeIntervalSinceReferenceDate.isFinite
            && now.timeIntervalSinceReferenceDate.isFinite
            && event.date <= now
            && !normalizedName(event.foodName).isEmpty
    }

    private static func eventOrder(_ left: FoodUsageEvent, _ right: FoodUsageEvent) -> Bool {
        if left.date != right.date { return left.date > right.date }
        return normalizedName(left.foodName) < normalizedName(right.foodName)
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
