import Foundation
import os

protocol FoodNutritionCaching: Sendable {
    func nutrition(for barcode: String) async -> FoodNutrition?
    func store(_ nutrition: FoodNutrition) async throws
    func store(_ nutrition: FoodNutrition, for barcode: String) async throws
}

actor NutritionCache: FoodNutritionCaching {
    nonisolated private static let logger = Logger(subsystem: "ch.elia.count-calories", category: "nutrition.cache")

    private struct CachedNutrition: Codable {
        var nutrition: FoodNutrition
        var lastAccessed: Date
    }

    private let fileURL: URL
    private let maximumBytes: Int
    private var entries: [String: CachedNutrition]

    init(fileURL: URL, maximumBytes: Int = 20 * 1_024 * 1_024) throws {
        self.fileURL = fileURL
        self.maximumBytes = max(1, maximumBytes)
        do {
            entries = try Self.load(from: fileURL)
        } catch {
            entries = [:]
            Self.logger.error("event=cache_recovery cache=nutrition outcome=discarded error_category=decode_or_io")
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                Self.logger.error("event=cache_recovery cache=nutrition outcome=remove_failed error_category=io")
            }
        }
    }

    static func applicationCache(maximumBytes: Int = 20 * 1_024 * 1_024) throws -> NutritionCache {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "NutritionCache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try NutritionCache(
            fileURL: directory.appending(path: "open-food-facts-nutrients-v2.json"),
            maximumBytes: maximumBytes
        )
    }

    func nutrition(for barcode: String) -> FoodNutrition? {
        guard var entry = entries[barcode] else {
            Self.logger.debug("Nutrition cache miss for barcode length \(barcode.count, privacy: .public)")
            return nil
        }
        entry.lastAccessed = .now
        entries[barcode] = entry
        do {
            try persist()
        } catch {
            Self.logger.error("event=cache_touch cache=nutrition outcome=write_failed error_category=io")
        }
        Self.logger.debug("Nutrition cache hit for barcode length \(barcode.count, privacy: .public)")
        return entry.nutrition
    }

    func store(_ nutrition: FoodNutrition) throws {
        try store(nutrition, for: nutrition.barcode)
    }

    func store(_ nutrition: FoodNutrition, for barcode: String) throws {
        let operationID = UUID().uuidString
        let parentID = NutritionOperationContext.parentIDText
        Self.logger.info(
            "event=operation_start operation=nutrition.cache_write operation_id=\(operationID, privacy: .public) parent_id=\(parentID, privacy: .public) source=nutrition_lookup"
        )
        let previousEntries = entries
        do {
            entries[barcode] = CachedNutrition(nutrition: nutrition, lastAccessed: .now)
            try evictToFit()
            try persist()
            Self.logger.info(
                "event=operation_success operation=nutrition.cache_write operation_id=\(operationID, privacy: .public) parent_id=\(parentID, privacy: .public) source=nutrition_lookup entries=\(self.entries.count, privacy: .public) bytes=\(self.encodedSize(), privacy: .public)"
            )
        } catch {
            entries = previousEntries
            Self.logger.error(
                "event=operation_failure operation=nutrition.cache_write operation_id=\(operationID, privacy: .public) parent_id=\(parentID, privacy: .public) source=nutrition_lookup error_category=storage"
            )
            throw error
        }
    }

    private static func load(from fileURL: URL) throws -> [String: CachedNutrition] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return [:] }
        return try JSONDecoder().decode([String: CachedNutrition].self, from: Data(contentsOf: fileURL))
    }

    private func evictToFit() throws {
        var evictions = 0
        while encodedSize() > maximumBytes, let oldest = entries.min(by: { $0.value.lastAccessed < $1.value.lastAccessed }) {
            entries.removeValue(forKey: oldest.key)
            evictions += 1
        }
        if evictions > 0 {
            Self.logger.notice("Evicted \(evictions, privacy: .public) nutrition cache entries; entries: \(self.entries.count, privacy: .public), bytes: \(self.encodedSize(), privacy: .public)")
        }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }

    private func encodedSize() -> Int {
        (try? JSONEncoder().encode(entries).count) ?? .max
    }
}

struct NutritionLookupService: Sendable {
    private static let logger = Logger(subsystem: "ch.elia.count-calories", category: "nutrition.lookup")
    private let client: any FoodNutritionFetching
    private let cache: any FoodNutritionCaching

    init(client: any FoodNutritionFetching, cache: any FoodNutritionCaching) {
        self.client = client
        self.cache = cache
    }

    func lookup(barcode: String) async throws -> FoodNutritionFetchResult {
        let normalizedBarcode = barcode.filter(\.isNumber)
        let operationID = UUID()
        let operationIDText = operationID.uuidString
        Self.logger.info(
            "event=operation_start operation=nutrition.lookup operation_id=\(operationIDText, privacy: .public) parent_id=none source=app barcode_length=\(normalizedBarcode.count, privacy: .public)"
        )
        return try await NutritionOperationContext.$parentOperationID.withValue(operationID) {
            if let cachedNutrition = await cache.nutrition(for: normalizedBarcode) {
                Self.logger.info(
                    "event=operation_success operation=nutrition.lookup operation_id=\(operationIDText, privacy: .public) parent_id=none source=cache barcode_length=\(normalizedBarcode.count, privacy: .public)"
                )
                return .found(cachedNutrition)
            }

            do {
                let result = try await client.fetchNutrition(for: normalizedBarcode)
                switch result {
                case let .found(nutrition):
                    try await cache.store(nutrition, for: normalizedBarcode)
                    Self.logger.info(
                        "event=operation_success operation=nutrition.lookup operation_id=\(operationIDText, privacy: .public) parent_id=none source=remote barcode_length=\(normalizedBarcode.count, privacy: .public)"
                    )
                case .incompleteProduct:
                    Self.logger.notice(
                        "event=operation_noop operation=nutrition.lookup operation_id=\(operationIDText, privacy: .public) parent_id=none source=remote outcome=incomplete barcode_length=\(normalizedBarcode.count, privacy: .public)"
                    )
                case .notFound:
                    Self.logger.notice(
                        "event=operation_noop operation=nutrition.lookup operation_id=\(operationIDText, privacy: .public) parent_id=none source=remote outcome=not_found barcode_length=\(normalizedBarcode.count, privacy: .public)"
                    )
                }
                return result
            } catch {
                Self.logger.error(
                    "event=operation_failure operation=nutrition.lookup operation_id=\(operationIDText, privacy: .public) parent_id=none source=remote error_category=lookup"
                )
                throw error
            }
        }
    }
}
