import Foundation
import Observation

nonisolated struct FoodSearchLocalCandidate: Equatable, Sendable {
    let barcode: String?

    init(barcode: String? = nil) {
        self.barcode = barcode
    }
}

@MainActor
@Observable
final class RemoteFoodSearchCoordinator {
    private let service: RemoteFoodSearchService
    private let languages: [String]
    private let debounce: @Sendable () async throws -> Void
    private var requestTask: Task<Void, Never>?
    private var normalizedQuery = ""
    private var revision = 0

    private(set) var foods: [FoodNutrition] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(
        service: RemoteFoodSearchService,
        languages: [String],
        debounce: @escaping @Sendable () async throws -> Void = {
            try await Task.sleep(for: .milliseconds(750))
        }
    ) {
        self.service = service
        self.languages = languages
        self.debounce = debounce
    }

    func update(query: String, localCandidates: [FoodSearchLocalCandidate]) {
        let normalized = FoodSearchQuery.normalize(query)
        if normalized != normalizedQuery {
            normalizedQuery = normalized
            foods = []
            errorMessage = nil
        }
        beginRequest()
        guard normalized.count >= 3 else { return }

        let requestRevision = revision
        let candidates = localCandidates
        let localBarcodes = localBarcodes(in: candidates)
        let service = service
        let languages = languages
        let debounce = debounce
        requestTask = Task { [weak self, service, languages, debounce] in
            guard let self else { return }
            do {
                let snapshot = try await service.snapshot(query: query, languages: languages)
                guard isCurrent(requestRevision, query: normalized) else { return }
                apply(snapshot, suppressing: localBarcodes)
                guard usefulFoodCount(with: candidates) < 5 else { return }

                try await debounce()
                try Task.checkCancellation()

                let recheckedSnapshot = try await service.snapshot(query: query, languages: languages)
                guard isCurrent(requestRevision, query: normalized) else { return }
                apply(recheckedSnapshot, suppressing: localBarcodes)
                guard usefulFoodCount(with: candidates) < 5 else { return }

                isLoading = true
                let result = try await service.load(query: query, languages: languages)
                guard isCurrent(requestRevision, query: normalized) else { return }
                apply(result.snapshot, suppressing: localBarcodes)
                isLoading = false
            } catch is CancellationError {
                finishCancellation(requestRevision)
            } catch {
                finish(error, revision: requestRevision)
            }
        }
    }

    func loadMore(query: String, localCandidates: [FoodSearchLocalCandidate]) {
        let normalized = FoodSearchQuery.normalize(query)
        guard normalized.count >= 3 else { return }
        if normalized != normalizedQuery {
            normalizedQuery = normalized
            foods = []
        }
        beginRequest()

        let requestRevision = revision
        let candidates = localCandidates
        let localBarcodes = localBarcodes(in: candidates)
        let service = service
        let languages = languages
        requestTask = Task { [weak self, service, languages] in
            guard let self else { return }
            do {
                let snapshot = try await service.snapshot(query: query, languages: languages)
                guard isCurrent(requestRevision, query: normalized) else { return }
                apply(snapshot, suppressing: localBarcodes)

                isLoading = true
                let result = try await service.load(
                    query: query,
                    languages: languages,
                    intent: .explicitLoadMore
                )
                guard isCurrent(requestRevision, query: normalized) else { return }
                apply(result.snapshot, suppressing: localBarcodes)
                isLoading = false
            } catch is CancellationError {
                finishCancellation(requestRevision)
            } catch {
                finish(error, revision: requestRevision)
            }
        }
    }

    func cancel() {
        revision &+= 1
        requestTask?.cancel()
        requestTask = nil
        isLoading = false
    }

    internal func waitForIdle() async {
        let task = requestTask
        await task?.value
    }

    private func beginRequest() {
        revision &+= 1
        requestTask?.cancel()
        requestTask = nil
        isLoading = false
        errorMessage = nil
    }

    private func isCurrent(_ requestRevision: Int, query: String) -> Bool {
        requestRevision == revision && query == normalizedQuery && !Task.isCancelled
    }

    private func finishCancellation(_ requestRevision: Int) {
        guard requestRevision == revision else { return }
        isLoading = false
    }

    private func finish(_ error: Error, revision requestRevision: Int) {
        guard requestRevision == revision, !Task.isCancelled else { return }
        isLoading = false
        errorMessage = error.localizedDescription
    }

    private func apply(_ snapshot: FoodSearchCacheSnapshot?, suppressing localBarcodes: Set<String>) {
        var seenBarcodes = Set<String>()
        foods = (snapshot?.orderedPages ?? []).flatMap(\.page.foods).filter { food in
            Self.isValidBarcode(food.barcode)
                && !localBarcodes.contains(food.barcode)
                && seenBarcodes.insert(food.barcode).inserted
        }
    }

    private func usefulFoodCount(with localCandidates: [FoodSearchLocalCandidate]) -> Int {
        var seenLocalBarcodes = Set<String>()
        let uniqueLocalCount = localCandidates.reduce(into: 0) { count, candidate in
            guard let barcode = candidate.barcode, Self.isValidBarcode(barcode) else {
                count += 1
                return
            }
            if seenLocalBarcodes.insert(barcode).inserted {
                count += 1
            }
        }
        return uniqueLocalCount + foods.count
    }

    private func localBarcodes(in candidates: [FoodSearchLocalCandidate]) -> Set<String> {
        Set(candidates.compactMap(\.barcode).filter(Self.isValidBarcode))
    }

    private static func isValidBarcode(_ barcode: String) -> Bool {
        guard (8...14).contains(barcode.utf8.count) else { return false }
        return barcode.utf8.allSatisfy { (48...57).contains($0) }
    }
}
