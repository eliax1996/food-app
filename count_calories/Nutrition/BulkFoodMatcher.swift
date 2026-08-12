import Foundation

nonisolated struct BulkFoodSavedCandidate: Equatable, Sendable {
    let match: BulkFoodMatch
    let priorUseCount: Int
    let lastUsedAt: Date?

    init(match: BulkFoodMatch, priorUseCount: Int = 0, lastUsedAt: Date? = nil) {
        self.match = match
        self.priorUseCount = priorUseCount
        self.lastUsedAt = lastUsedAt
    }
}

nonisolated struct BulkFoodMatchRequest: Equatable, Sendable {
    let draftID: UUID
    let generation: Int64
    let itemID: UUID
    let revision: Int64
    let query: String
    let unit: NutritionUnit
}

nonisolated struct BulkFoodMatchResult: Equatable, Sendable {
    let request: BulkFoodMatchRequest
    let candidates: [BulkFoodMatch]
    let automaticSelection: BulkFoodMatch?
    let failure: BulkFoodMatchFailure?
}

actor BulkFoodMatcher {
    private let remoteService: RemoteFoodSearchService?
    private let learningStore: BulkFoodLearningStore?
    private let languages: [String]
    private let maximumRemoteConcurrency: Int
    private var remoteStarts = 0

    init(
        remoteService: RemoteFoodSearchService?,
        learningStore: BulkFoodLearningStore?,
        languages: [String],
        maximumRemoteConcurrency: Int = 3
    ) {
        self.remoteService = remoteService
        self.learningStore = learningStore
        self.languages = languages
        self.maximumRemoteConcurrency = max(1, maximumRemoteConcurrency)
    }

    func match(
        request: BulkFoodMatchRequest,
        savedCandidates: [BulkFoodSavedCandidate],
        learnedRecord: BulkFoodLearningRecord? = nil,
        allowRemote: Bool = true
    ) async -> BulkFoodMatchResult {
        guard !Task.isCancelled else {
            return result(request, candidates: [], failure: .cancelled)
        }
        guard let query = try? BulkFoodValidator.validateQuery(request.query) else {
            return result(request, candidates: [], failure: .invalidQuery)
        }

        var candidates: [BulkFoodCandidate] = savedCandidates
            .filter { Self.isRelevant($0.match.displayName, to: query) }
            .map {
                BulkFoodCandidate(
                    match: $0.match,
                    priorUseCount: $0.priorUseCount,
                    lastUsedAt: $0.lastUsedAt
                )
            }
        let learned: BulkFoodLearningRecord?
        if let learnedRecord {
            learned = learnedRecord
        } else if let learningStore {
            learned = await learningStore.record(for: query, unit: request.unit, touch: false)
        } else {
            learned = nil
        }
        if let learned,
           learned.selectionSnapshot.isValid,
           learned.selectionSnapshot.servingUnit == request.unit,
           let verifiedRemembered = Self.verifiedRememberedMatch(
               learned.selectionSnapshot,
               savedCandidates: savedCandidates
           ) {
            candidates.append(BulkFoodCandidate(
                match: verifiedRemembered,
                priorUseCount: learned.useCount,
                lastUsedAt: learned.lastUsedAt
            ))
        }

        if let remoteService, FoodSearchQuery.normalize(query).count >= 3 {
            do {
                let cached = try await remoteService.snapshot(query: query, languages: languages)
                candidates.append(contentsOf: candidateFoods(from: cached, source: .cache, unit: request.unit))
                let ranked = BulkFoodCandidateRanker.ranked(
                    query: query,
                    unit: request.unit,
                    candidates: candidates
                )
                let hasAutomaticSelection = BulkFoodCandidateRanker.automaticSelection(
                    query: query,
                    unit: request.unit,
                    candidates: ranked
                ) != nil
                if allowRemote, !hasAutomaticSelection, ranked.count < 5 {
                    try await acquireRemotePermit()
                    defer { releaseRemotePermit() }
                    try Task.checkCancellation()
                    let loaded = try await remoteService.load(query: query, languages: languages)
                    candidates.append(contentsOf: candidateFoods(
                        from: loaded.snapshot,
                        source: .openFoodFacts,
                        unit: request.unit
                    ))
                }
            } catch is CancellationError {
                return result(request, candidates: candidates, failure: .cancelled)
            } catch {
                let failure = Self.classify(error)
                let ranked = BulkFoodCandidateRanker.ranked(
                    query: query,
                    unit: request.unit,
                    candidates: candidates
                )
                return result(request, rankedCandidates: ranked, failure: failure)
            }
        }

        let ranked = BulkFoodCandidateRanker.ranked(
            query: query,
            unit: request.unit,
            candidates: candidates
        )
        return result(
            request,
            rankedCandidates: ranked,
            failure: ranked.isEmpty ? .noMatches : nil
        )
    }

    private func result(
        _ request: BulkFoodMatchRequest,
        candidates: [BulkFoodCandidate],
        failure: BulkFoodMatchFailure
    ) -> BulkFoodMatchResult {
        let ranked = BulkFoodCandidateRanker.ranked(
            query: request.query,
            unit: request.unit,
            candidates: candidates
        )
        return result(request, rankedCandidates: ranked, failure: failure)
    }

    private func result(
        _ request: BulkFoodMatchRequest,
        rankedCandidates: [BulkFoodCandidate],
        failure: BulkFoodMatchFailure?
    ) -> BulkFoodMatchResult {
        BulkFoodMatchResult(
            request: request,
            candidates: rankedCandidates.map(\.match),
            automaticSelection: BulkFoodCandidateRanker.automaticSelection(
                query: request.query,
                unit: request.unit,
                candidates: rankedCandidates
            ),
            failure: failure
        )
    }

    private func candidateFoods(
        from snapshot: FoodSearchCacheSnapshot?,
        source: BulkFoodMatchSource,
        unit: NutritionUnit
    ) -> [BulkFoodCandidate] {
        (snapshot?.orderedPages ?? []).flatMap(\.page.foods).compactMap { food in
            guard food.defaultAmount.unit == unit,
                  let match = BulkFoodMatch.from(food, source: source) else { return nil }
            return BulkFoodCandidate(match: match)
        }
    }

    private func acquireRemotePermit() async throws {
        while remoteStarts >= maximumRemoteConcurrency {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(25))
        }
        try Task.checkCancellation()
        remoteStarts += 1
    }

    private func releaseRemotePermit() {
        remoteStarts = max(0, remoteStarts - 1)
    }

    private static func verifiedRememberedMatch(
        _ snapshot: BulkFoodMatch,
        savedCandidates: [BulkFoodSavedCandidate]
    ) -> BulkFoodMatch? {
        let current: BulkFoodMatch? = switch snapshot.identity {
        case .savedFood(let id):
            savedCandidates.first { $0.match.identity == .savedFood(id) }?.match
        case .barcode(let barcode):
            savedCandidates.first { $0.match.barcode == barcode }?.match
        }
        guard let current,
              current.displayName == snapshot.displayName,
              current.barcode == snapshot.barcode,
              current.servingAmount.bitPattern == snapshot.servingAmount.bitPattern,
              current.servingUnit == snapshot.servingUnit,
              current.caloriesPerServing == snapshot.caloriesPerServing,
              current.nutrientsPerServing == snapshot.nutrientsPerServing else { return nil }
        return current.replacingSource(.remembered)
    }

    private static func isRelevant(_ name: String, to query: String) -> Bool {
        let normalizedName = BulkFoodText.normalizedKey(name)
        let normalizedQuery = BulkFoodText.normalizedKey(query)
        guard !normalizedName.isEmpty, !normalizedQuery.isEmpty else { return false }
        if normalizedName.contains(normalizedQuery) || normalizedQuery.contains(normalizedName) {
            return true
        }
        let nameTokens = BulkFoodText.tokens(name)
        return BulkFoodText.tokens(query).allSatisfy { queryToken in
            nameTokens.contains { nameToken in
                nameToken.hasPrefix(queryToken) || queryToken.hasPrefix(nameToken)
            }
        }
    }

    private static func classify(_ error: Error) -> BulkFoodMatchFailure {
        if error is FoodSearchRateLimitError { return .rateLimited }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed:
                return .offline
            default:
                return .unavailable
            }
        }
        return .unavailable
    }

}
