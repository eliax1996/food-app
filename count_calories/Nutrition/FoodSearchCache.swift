import Foundation
import os

nonisolated struct FoodSearchCacheKey: Hashable, Codable, Sendable {
    static let currentProjectionSchemaVersion = 2

    let normalizedQuery: String
    let languages: [String]
    let projectionSchemaVersion: Int

    init(
        query: String,
        languages: [String],
        projectionSchemaVersion: Int = Self.currentProjectionSchemaVersion
    ) {
        normalizedQuery = FoodSearchQuery.normalize(query)
        self.languages = languages
        self.projectionSchemaVersion = projectionSchemaVersion
    }

    init(
        normalizedQuery: String,
        languages: [String],
        projectionSchemaVersion: Int = Self.currentProjectionSchemaVersion
    ) {
        self.normalizedQuery = FoodSearchQuery.normalize(normalizedQuery)
        self.languages = languages
        self.projectionSchemaVersion = projectionSchemaVersion
    }
}

nonisolated struct FoodSearchCachedPage: Codable, Equatable, Sendable {
    let page: FoodSearchPage
    let fetchedAt: Date

    init(page: FoodSearchPage, fetchedAt: Date) {
        self.page = page
        self.fetchedAt = fetchedAt
    }
}

nonisolated struct FoodSearchCacheSnapshot: Codable, Equatable, Sendable {
    let key: FoodSearchCacheKey
    let pages: [Int: FoodSearchCachedPage]
    let generation: Int
    let terminalPage: Int?
    let terminalFetchedAt: Date?
    let lastAccess: Date

    var orderedPages: [FoodSearchCachedPage] {
        pages.keys.sorted().compactMap { pages[$0] }
    }
}

actor FoodSearchCache {
    nonisolated private static let logger = Logger(
        subsystem: "ch.elia.count-calories",
        category: "food-search.cache"
    )

    static let defaultMaximumQueries = 2_048
    static let defaultMaximumBytes = 32 * 1_024 * 1_024

    private struct Entry: Codable, Sendable {
        var pages: [Int: FoodSearchCachedPage]
        var generation: Int
        var terminalPage: Int?
        var terminalFetchedAt: Date?
        var lastAccess: Date

        func snapshot(for key: FoodSearchCacheKey) -> FoodSearchCacheSnapshot {
            FoodSearchCacheSnapshot(
                key: key,
                pages: pages,
                generation: generation,
                terminalPage: terminalPage,
                terminalFetchedAt: terminalFetchedAt,
                lastAccess: lastAccess
            )
        }
    }

    private let fileURL: URL
    private let maximumQueries: Int
    private let maximumBytes: Int
    private let now: @Sendable () -> Date
    private var entries: [FoodSearchCacheKey: Entry]

    init(
        fileURL: URL,
        maximumQueries: Int = FoodSearchCache.defaultMaximumQueries,
        maximumBytes: Int = FoodSearchCache.defaultMaximumBytes,
        now: @escaping @Sendable () -> Date = { .now }
    ) throws {
        self.fileURL = fileURL
        self.maximumQueries = max(1, maximumQueries)
        self.maximumBytes = max(1, maximumBytes)
        self.now = now
        do {
            entries = try Self.load(from: fileURL)
        } catch {
            entries = [:]
            try? FileManager.default.removeItem(at: fileURL)
            Self.logger.error("Food search cache corrupt; recovered empty cache")
        }
    }

    static func applicationCache(
        maximumQueries: Int = FoodSearchCache.defaultMaximumQueries,
        maximumBytes: Int = FoodSearchCache.defaultMaximumBytes
    ) throws -> FoodSearchCache {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "FoodSearchCache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try FoodSearchCache(
            fileURL: directory.appending(path: "open-food-facts-search.json"),
            maximumQueries: maximumQueries,
            maximumBytes: maximumBytes
        )
    }

    /// Returns every cached page, including stale pages. Read recency stays memory-only.
    func snapshot(for key: FoodSearchCacheKey) -> FoodSearchCacheSnapshot? {
        guard var entry = entries[key] else { return nil }
        entry.lastAccess = now()
        entries[key] = entry
        return entry.snapshot(for: key)
    }

    /// Stores one fetched page. A replacement only succeeds for expected generation.
    @discardableResult
    func store(
        _ page: FoodSearchPage,
        for key: FoodSearchCacheKey,
        fetchedAt: Date,
        expectedGeneration: Int? = nil,
        replacingPageOne: Bool = false
    ) throws -> FoodSearchCacheSnapshot? {
        let currentGeneration = entries[key]?.generation ?? 0
        if let expectedGeneration, expectedGeneration != currentGeneration {
            return nil
        }

        var entry: Entry
        if replacingPageOne {
            guard page.page == 1 else { return nil }
            entry = Entry(
                pages: [:],
                generation: currentGeneration + 1,
                terminalPage: nil,
                terminalFetchedAt: nil,
                lastAccess: now()
            )
        } else if let existing = entries[key] {
            entry = existing
            entry.lastAccess = now()
        } else {
            entry = Entry(
                pages: [:],
                generation: currentGeneration,
                terminalPage: nil,
                terminalFetchedAt: nil,
                lastAccess: now()
            )
        }

        entry.pages[page.page] = FoodSearchCachedPage(page: page, fetchedAt: fetchedAt)
        if page.isTerminal {
            entry.terminalPage = page.page
            entry.terminalFetchedAt = fetchedAt
        } else if entry.terminalPage == page.page {
            entry.terminalPage = nil
            entry.terminalFetchedAt = nil
        }
        entries[key] = entry
        let evictions = evictToFit()
        try persist()
        let bytes = encodedSize()
        Self.logger.info(
            "Stored food search cache; entries \(self.entries.count, privacy: .public), bytes \(bytes, privacy: .public)"
        )
        if evictions > 0 {
            Self.logger.notice(
                "Evicted \(evictions, privacy: .public) food search cache entries; entries \(self.entries.count, privacy: .public), bytes \(bytes, privacy: .public)"
            )
        }
        return entries[key]?.snapshot(for: key)
    }

    private static func load(from fileURL: URL) throws -> [FoodSearchCacheKey: Entry] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return [:] }
        return try JSONDecoder().decode([FoodSearchCacheKey: Entry].self, from: Data(contentsOf: fileURL))
    }

    private func evictToFit() -> Int {
        var evictions = 0
        while entries.count > maximumQueries || encodedSize() > maximumBytes {
            guard let key = leastRecentlyUsedKey() else { return evictions }
            entries.removeValue(forKey: key)
            evictions += 1
        }
        return evictions
    }

    private func leastRecentlyUsedKey() -> FoodSearchCacheKey? {
        entries.min { lhs, rhs in
            if lhs.value.lastAccess != rhs.value.lastAccess {
                return lhs.value.lastAccess < rhs.value.lastAccess
            }
            return stableKey(lhs.key) < stableKey(rhs.key)
        }?.key
    }

    private func stableKey(_ key: FoodSearchCacheKey) -> String {
        "\(key.projectionSchemaVersion)\u{0}\(key.normalizedQuery)\u{0}\(key.languages.joined(separator: "\u{0}"))"
    }

    private func persist() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }

    private func encodedSize() -> Int {
        (try? JSONEncoder().encode(entries).count) ?? .max
    }
}
