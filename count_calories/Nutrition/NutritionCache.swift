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
            Self.logger.error("Discarding corrupt nutrition cache: \(error.localizedDescription, privacy: .public)")
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                Self.logger.error("Failed to remove corrupt nutrition cache: \(error.localizedDescription, privacy: .public)")
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
        return try NutritionCache(fileURL: directory.appending(path: "open-food-facts.json"), maximumBytes: maximumBytes)
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
            Self.logger.error("Failed to persist nutrition cache access: \(error.localizedDescription, privacy: .public)")
        }
        Self.logger.debug("Nutrition cache hit for barcode length \(barcode.count, privacy: .public)")
        return entry.nutrition
    }

    func store(_ nutrition: FoodNutrition) throws {
        try store(nutrition, for: nutrition.barcode)
    }

    func store(_ nutrition: FoodNutrition, for barcode: String) throws {
        entries[barcode] = CachedNutrition(nutrition: nutrition, lastAccessed: .now)
        try evictToFit()
        try persist()
        Self.logger.info("Stored nutrition cache entry; entries: \(self.entries.count, privacy: .public), bytes: \(self.encodedSize(), privacy: .public)")
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
        if let cachedNutrition = await cache.nutrition(for: normalizedBarcode) {
            Self.logger.info("Nutrition lookup served from cache for barcode length \(normalizedBarcode.count, privacy: .public)")
            return .found(cachedNutrition)
        }

        Self.logger.info("Nutrition lookup requesting remote data for barcode length \(normalizedBarcode.count, privacy: .public)")
        let result = try await client.fetchNutrition(for: normalizedBarcode)
        switch result {
        case let .found(nutrition):
            try await cache.store(nutrition, for: normalizedBarcode)
        case .incompleteProduct:
            Self.logger.notice("Nutrition lookup found a product without usable calories for barcode length \(normalizedBarcode.count, privacy: .public)")
        case .notFound:
            Self.logger.notice("Nutrition lookup found no remote product for barcode length \(normalizedBarcode.count, privacy: .public)")
        }
        return result
    }
}
