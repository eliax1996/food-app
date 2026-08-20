import Foundation
import os

nonisolated enum FoodSearchLoadIntent: Sendable {
    case automatic
    case explicitLoadMore
}

nonisolated struct RemoteFoodSearchResult: Sendable {
    /// Current cache state after this call. Includes stale pages when no fetch was needed.
    let snapshot: FoodSearchCacheSnapshot?

    init(snapshot: FoodSearchCacheSnapshot?) {
        self.snapshot = snapshot
    }
}

nonisolated struct FoodSearchRateLimitError: LocalizedError, Equatable, Sendable {
    let retryAfter: TimeInterval
    let retryAt: Date

    var errorDescription: String? {
        "Food search is locally rate limited until \(retryAt.formatted())."
    }
}

actor RemoteFoodSearchService {
    nonisolated private static let logger = Logger(
        subsystem: "ch.elia.count-calories",
        category: "food-search.service"
    )

    static let positiveTTL: TimeInterval = 30 * 24 * 60 * 60
    static let terminalTTL: TimeInterval = 90 * 24 * 60 * 60
    static let maximumStarts = 10
    static let rateLimitWindow: TimeInterval = 60

    private struct FetchPlan: Sendable {
        let page: Int
        let generation: Int
        let replacingPageOne: Bool
    }

    private struct FlightKey: Hashable, Sendable {
        let cacheKey: FoodSearchCacheKey
        let page: Int
        let generation: Int
        let replacingPageOne: Bool
    }

    private struct Flight: Sendable {
        let id: UUID
        let task: Task<FoodSearchPage, Error>
        var waiters: [UUID: CheckedContinuation<FoodSearchPage, Error>]
    }

    private let fetcher: any FoodSearchFetching
    private let cache: FoodSearchCache
    private let pageSize: Int
    private let projectionSchemaVersion: Int
    private let now: @Sendable () -> Date
    private var requestStarts: [Date] = []
    private var flights: [FlightKey: Flight] = [:]
#if DEBUG || RELEASE_VALIDATION
    private var waiterCounts: [FlightKey: Int] = [:]
#endif

    init(
        fetcher: any FoodSearchFetching,
        cache: FoodSearchCache,
        pageSize: Int = 5,
        projectionSchemaVersion: Int = FoodSearchCacheKey.currentProjectionSchemaVersion,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.pageSize = pageSize
        self.projectionSchemaVersion = projectionSchemaVersion
        self.now = now
    }

    /// Validates and normalizes input, then returns cached pages without starting a network request.
    func snapshot(
        query: String,
        languages: [String]
    ) async throws -> FoodSearchCacheSnapshot? {
        try validate(query: query, languages: languages)
        let key = FoodSearchCacheKey(
            query: query,
            languages: languages,
            projectionSchemaVersion: projectionSchemaVersion
        )
        let snapshot = await cache.snapshot(for: key)
        if snapshot == nil {
            Self.logger.info("Food search cache-only miss; query length \(key.normalizedQuery.count, privacy: .public)")
        } else {
            Self.logger.info("Food search cache-only hit; query length \(key.normalizedQuery.count, privacy: .public)")
        }
        return snapshot
    }

    func load(
        query: String,
        languages: [String],
        intent: FoodSearchLoadIntent = .automatic
    ) async throws -> RemoteFoodSearchResult {
        let operationID = UUID()
        let operationIDText = operationID.uuidString
        Self.logger.info(
            "event=operation_start operation=food_search.load operation_id=\(operationIDText, privacy: .public) parent_id=none source=app query_length=\(query.count, privacy: .public)"
        )
        do {
            let result = try await NutritionOperationContext.$parentOperationID.withValue(operationID) {
                try validate(query: query, languages: languages)
                let key = FoodSearchCacheKey(
                    query: query,
                    languages: languages,
                    projectionSchemaVersion: projectionSchemaVersion
                )
                let cachedSnapshot = await cache.snapshot(for: key)
                guard let plan = fetchPlan(for: cachedSnapshot, at: now(), intent: intent) else {
                    return RemoteFoodSearchResult(snapshot: cachedSnapshot)
                }

                let page = try await remotePage(
                    query: query,
                    languages: languages,
                    key: key,
                    plan: plan
                )
                // Completion can win cancellation race. Never let cancelled waiter persist a page.
                try Task.checkCancellation()
                let storedSnapshot = try await cache.store(
                    page,
                    for: key,
                    fetchedAt: now(),
                    expectedGeneration: plan.generation,
                    replacingPageOne: plan.replacingPageOne
                )
                // Another coalesced waiter can store first. Never return pre-fetch cache state.
                let finalSnapshot: FoodSearchCacheSnapshot?
                if let storedSnapshot {
                    finalSnapshot = storedSnapshot
                } else {
                    finalSnapshot = await cache.snapshot(for: key)
                }
                return RemoteFoodSearchResult(snapshot: finalSnapshot)
            }
            let resultCount = result.snapshot?.orderedPages.reduce(0) {
                $0 + $1.page.foods.count
            } ?? 0
            Self.logger.info(
                "event=operation_success operation=food_search.load operation_id=\(operationIDText, privacy: .public) parent_id=none source=app result_count=\(resultCount, privacy: .public)"
            )
            return result
        } catch is CancellationError {
            Self.logger.info(
                "event=operation_cancelled operation=food_search.load operation_id=\(operationIDText, privacy: .public) parent_id=none source=app"
            )
            throw CancellationError()
        } catch {
            Self.logger.error(
                "event=operation_failure operation=food_search.load operation_id=\(operationIDText, privacy: .public) parent_id=none source=app error_category=search"
            )
            throw error
        }
    }

    func search(
        query: String,
        languages: [String],
        intent: FoodSearchLoadIntent = .automatic
    ) async throws -> RemoteFoodSearchResult {
        try await load(query: query, languages: languages, intent: intent)
    }

    private func validate(query: String, languages: [String]) throws {
        guard !FoodSearchQuery.normalize(query).isEmpty else { throw FoodSearchError.invalidQuery }
        guard pageSize >= 1 else { throw FoodSearchError.invalidPageSize }
        guard !languages.isEmpty, languages.allSatisfy({ !$0.isEmpty }) else {
            throw FoodSearchError.invalidLanguages
        }
    }

    private func fetchPlan(
        for snapshot: FoodSearchCacheSnapshot?,
        at date: Date,
        intent: FoodSearchLoadIntent
    ) -> FetchPlan? {
        let generation = snapshot?.generation ?? 0
        guard let snapshot else {
            return FetchPlan(page: 1, generation: generation, replacingPageOne: true)
        }

        let terminalIsFresh = snapshot.terminalFetchedAt.map {
            date.timeIntervalSince($0) < Self.terminalTTL
        } ?? false
        let hasStalePositivePage = snapshot.pages.values.contains {
            $0.page.rawHitCount > 0 && date.timeIntervalSince($0.fetchedAt) >= Self.positiveTTL
        }

        switch intent {
        case .automatic:
            if snapshot.terminalPage != nil, terminalIsFresh, !hasStalePositivePage {
                return nil
            }
            if snapshot.terminalPage != nil || snapshot.pages.isEmpty || hasStalePositivePage {
                return FetchPlan(page: 1, generation: generation, replacingPageOne: true)
            }
        case .explicitLoadMore:
            if snapshot.terminalPage != nil || snapshot.pages.isEmpty {
                return FetchPlan(page: 1, generation: generation, replacingPageOne: true)
            }
        }

        var page = 1
        while snapshot.pages[page] != nil {
            page += 1
        }
        return FetchPlan(page: page, generation: generation, replacingPageOne: false)
    }

    private func remotePage(
        query: String,
        languages: [String],
        key: FoodSearchCacheKey,
        plan: FetchPlan
    ) async throws -> FoodSearchPage {
        let flightKey = FlightKey(
            cacheKey: key,
            page: plan.page,
            generation: plan.generation,
            replacingPageOne: plan.replacingPageOne
        )
        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                registerWaiter(
                    id: waiterID,
                    continuation: continuation,
                    for: flightKey,
                    query: query,
                    languages: languages,
                    key: key,
                    plan: plan
                )
            }
        } onCancel: {
            Task { [weak self] in
                await self?.cancelWaiter(id: waiterID, for: flightKey)
            }
        }
    }

    private func registerWaiter(
        id: UUID,
        continuation: CheckedContinuation<FoodSearchPage, Error>,
        for flightKey: FlightKey,
        query: String,
        languages: [String],
        key: FoodSearchCacheKey,
        plan: FetchPlan
    ) {
        guard !Task.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
        }

        if var flight = flights[flightKey] {
            let parentID = NutritionOperationContext.parentIDText
            Self.logger.info(
                "event=operation_join operation=food_search.remote operation_id=\(flight.id.uuidString, privacy: .public) parent_id=\(parentID, privacy: .public) source=search query_length=\(key.normalizedQuery.count, privacy: .public) page=\(plan.page, privacy: .public)"
            )
            flight.waiters[id] = continuation
            flights[flightKey] = flight
#if DEBUG || RELEASE_VALIDATION
            waiterCounts[flightKey] = flight.waiters.count
#endif
            return
        }

        do {
            var flight = try makeFlight(
                for: flightKey,
                query: query,
                languages: languages,
                key: key,
                plan: plan
            )
            flight.waiters[id] = continuation
            flights[flightKey] = flight
#if DEBUG || RELEASE_VALIDATION
            waiterCounts[flightKey] = flight.waiters.count
#endif
        } catch {
            continuation.resume(throwing: error)
        }
    }

    private func makeFlight(
        for flightKey: FlightKey,
        query: String,
        languages: [String],
        key: FoodSearchCacheKey,
        plan: FetchPlan
    ) throws -> Flight {
        let requestDate = now()
        requestStarts.removeAll { requestDate.timeIntervalSince($0) >= Self.rateLimitWindow }
        if requestStarts.count >= Self.maximumStarts, let oldest = requestStarts.min() {
            let retryAt = oldest.addingTimeInterval(Self.rateLimitWindow)
            Self.logger.notice(
                "Food search locally rate limited; query length \(key.normalizedQuery.count, privacy: .public), page \(plan.page, privacy: .public)"
            )
            throw FoodSearchRateLimitError(
                retryAfter: max(0, retryAt.timeIntervalSince(requestDate)),
                retryAt: retryAt
            )
        }
        requestStarts.append(requestDate)

        let queryLength = key.normalizedQuery.count
        let page = plan.page
        let logger = Self.logger
        let id = UUID()
        let parentID = NutritionOperationContext.parentIDText
        logger.info(
            "event=operation_start operation=food_search.remote operation_id=\(id.uuidString, privacy: .public) parent_id=\(parentID, privacy: .public) source=search query_length=\(queryLength, privacy: .public) page=\(page, privacy: .public)"
        )
        let task = Task<FoodSearchPage, Error> { [fetcher, pageSize] in
            do {
                let response = try await NutritionOperationContext.$parentOperationID.withValue(id) {
                    try await fetcher.search(
                        query: query,
                        page: page,
                        pageSize: pageSize,
                        languages: languages
                    )
                }
                logger.info(
                    "event=operation_success operation=food_search.remote operation_id=\(id.uuidString, privacy: .public) parent_id=\(parentID, privacy: .public) source=search query_length=\(queryLength, privacy: .public) page=\(page, privacy: .public) result_count=\(response.foods.count, privacy: .public)"
                )
                return response
            } catch {
                logger.error(
                    "event=operation_failure operation=food_search.remote operation_id=\(id.uuidString, privacy: .public) parent_id=\(parentID, privacy: .public) source=search query_length=\(queryLength, privacy: .public) page=\(page, privacy: .public) error_category=remote"
                )
                throw error
            }
        }
        Task { [weak self, task] in
            let result: Result<FoodSearchPage, Error>
            do {
                result = .success(try await task.value)
            } catch {
                result = .failure(error)
            }
            await self?.completeFlight(flightKey, id: id, result: result)
        }
        return Flight(id: id, task: task, waiters: [:])
    }

#if DEBUG || RELEASE_VALIDATION
    func testingWaiterCount(query: String, languages: [String]) -> Int {
        let cacheKey = FoodSearchCacheKey(
            query: query,
            languages: languages,
            projectionSchemaVersion: projectionSchemaVersion
        )
        return waiterCounts.first(where: { $0.key.cacheKey == cacheKey })?.value ?? 0
    }
#endif

    private func cancelWaiter(id: UUID, for key: FlightKey) {
        guard var flight = flights[key], let continuation = flight.waiters.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CancellationError())
        guard flight.waiters.isEmpty else {
            flights[key] = flight
#if DEBUG || RELEASE_VALIDATION
            waiterCounts[key] = flight.waiters.count
#endif
            return
        }
        flights.removeValue(forKey: key)
#if DEBUG || RELEASE_VALIDATION
        waiterCounts.removeValue(forKey: key)
#endif
        flight.task.cancel()
    }

    private func completeFlight(
        _ key: FlightKey,
        id: UUID,
        result: Result<FoodSearchPage, Error>
    ) {
        guard let flight = flights[key], flight.id == id else { return }
        flights.removeValue(forKey: key)
#if DEBUG || RELEASE_VALIDATION
        waiterCounts.removeValue(forKey: key)
#endif
        flight.waiters.values.forEach { $0.resume(with: result) }
    }
}
