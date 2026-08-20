import Observation
import SwiftUI
import os
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class BulkMealDraftController: Identifiable {
    enum Stage: Equatable {
        case describe
        case extracting
        case review
        case confirming
    }

    var stage: Stage = .describe
    var descriptionText = ""
    var selectedMeal: MealType {
        didSet {
            if oldValue != selectedMeal {
                clearCommitSnapshot()
            }
        }
    }
    var items: [BulkFoodReviewItem] = []
    var errorMessage: String?
    var availability: BulkFoodExtractionAvailability
    var showingCancelConfirmation = false
    var showingResumedDraft = false
    var isCheckingDraft = true
    var pendingDraftChoice: BulkFoodDraft?

    private(set) var draftID: UUID
    private(set) var operationID: UUID

    private let extractor: any BulkFoodExtracting
    private let matcher: BulkFoodMatcher
    private let learningStore: BulkFoodLearningStore?
    private let learningLease: BulkFoodLearningLease?
    private var draftStore: BulkFoodDraftStore?
    private var draftLease: BulkFoodDraftLease?
    private let allowRemoteMatching: Bool
    private var generation: Int64 = 0
    private var extractionTask: Task<Void, Never>?
    private var matchTasks: [UUID: Task<Void, Never>] = [:]
    private var commitInserts: [BulkPlateInsert]?
    private var commitDate: Date?
    private var committedLearningItems: [BulkFoodReviewItem]?
    private var hasCheckedDraft = false
    private var storedDraftID: UUID?

    init(
        selectedMeal: MealType,
        extractor: any BulkFoodExtracting,
        matcher: BulkFoodMatcher,
        learningStore: BulkFoodLearningStore?,
        learningLease: BulkFoodLearningLease?,
        draftStore: BulkFoodDraftStore?,
        draftLease: BulkFoodDraftLease?,
        locale: Locale = .current,
        draftID: UUID = UUID(),
        operationID: UUID = UUID(),
        allowRemoteMatching: Bool = true
    ) {
        self.selectedMeal = selectedMeal
        self.extractor = extractor
        self.matcher = matcher
        self.learningStore = learningStore
        self.learningLease = learningLease
        self.draftStore = draftStore
        self.draftLease = draftLease
        self.draftID = draftID
        self.operationID = operationID
        self.allowRemoteMatching = allowRemoteMatching
#if DEBUG || RELEASE_VALIDATION
        availability = ProcessInfo.processInfo.arguments.contains("-ui-testing-bulk-unavailable")
            ? .unavailable(.deviceNotEligible)
            : extractor.availability(for: locale)
#else
        availability = extractor.availability(for: locale)
#endif
    }

    var canExtract: Bool {
        guard case .available = availability else { return false }
        return (try? BulkFoodValidator.validateDescription(descriptionText)) != nil
    }

    var readyItems: [BulkFoodReviewItem] { items.filter(\.isReady) }

    var totalCalories: Int? {
        guard !items.isEmpty, items.allSatisfy(\.isReady) else { return nil }
        var total = 0
        for item in items {
            guard let calories = item.calories else { return nil }
            let added = total.addingReportingOverflow(calories)
            guard !added.overflow else { return nil }
            total = added.partialValue
        }
        return total
    }

    var blockerCount: Int { items.count(where: { !$0.isReady }) }

    var progressSummary: String {
        let matched = items.count(where: { $0.isReady })
        let searching = items.count(where: {
            $0.matchPhase == .searchingSaved || $0.matchPhase == .searchingRemote
        })
        let review = items.count - matched - searching
        return "Matched \(matched) of \(items.count) · Searching \(searching) · Review \(max(0, review))"
    }

    func refreshAvailability(locale: Locale = .current) {
        availability = extractor.availability(for: locale)
    }

    func checkForDraftIfNeeded() async {
        guard !hasCheckedDraft else { return }
        hasCheckedDraft = true
        defer { isCheckingDraft = false }
        if draftStore == nil, let store = try? await BulkFoodDraftStore.applicationStore() {
            draftStore = store
            draftLease = await store.acquireLease()
        }
#if DEBUG || RELEASE_VALIDATION
        let fixtureDraft = ProcessInfo.processInfo.arguments.contains("-ui-testing-bulk-draft")
            ? BulkFoodDraft(
                description: "100 g almond milk",
                mealType: MealType.suggestedForCurrentTime.rawValue,
                reviewItems: [],
                updatedAt: .now
            )
            : nil
#else
        let fixtureDraft: BulkFoodDraft? = nil
#endif
        let storedDraft = await draftStore?.load()
        guard let draft = fixtureDraft ?? storedDraft else { return }
        storedDraftID = draft.id
        pendingDraftChoice = draft
    }

    func startNewDraft() {
        cancelWork()
        draftID = UUID()
        operationID = UUID()
        descriptionText = ""
        items = []
        commitInserts = nil
        commitDate = nil
        committedLearningItems = nil
        stage = .describe
        showingResumedDraft = false
        pendingDraftChoice = nil
    }

    func resumePendingDraft(savedFoods: [Food]) {
        guard let draft = pendingDraftChoice else { return }
        draftID = draft.id
        operationID = draft.operationID
        storedDraftID = draft.id
        descriptionText = draft.description
        selectedMeal = MealType(rawValue: draft.mealType) ?? selectedMeal
        commitDate = draft.commitDate
        commitInserts = nil
        committedLearningItems = nil
        items = draft.reviewItems.map { snapshot in
            let restoredMatch = snapshot.selectedMatch.flatMap { match in
                Self.learningSelectionStillValid(match, savedFoods: savedFoods) ? match : nil
            }
            return BulkFoodReviewItem(
                id: snapshot.id,
                sourceQuery: snapshot.sourceQuery,
                query: snapshot.query,
                amount: snapshot.amount,
                unit: snapshot.unit,
                amountOrigin: snapshot.amountOrigin,
                selectedMatch: restoredMatch,
                candidates: restoredMatch.map { [$0] } ?? [],
                matchPhase: restoredMatch == nil ? .idle : .resolved
            )
        }
        pendingDraftChoice = nil
        showingResumedDraft = true
        if items.isEmpty {
            stage = .describe
        } else {
            stage = .review
            for item in items where !item.isReady {
                scheduleMatch(for: item.id, savedFoods: savedFoods, debounce: false)
            }
        }
    }

    func discardPendingDraft() async throws {
        try await clearDraft()
        startNewDraft()
    }

    func beginExtraction(savedFoods: [Food]) {
        guard stage != .extracting else { return }
        let description: String
        do {
            description = try BulkFoodValidator.validateDescription(descriptionText)
        } catch BulkFoodValidationError.emptyDescription {
            errorMessage = "Describe at least one food first."
            return
        } catch BulkFoodValidationError.descriptionTooLong {
            errorMessage = "Meal description must be 1,200 characters or fewer."
            return
        } catch {
            errorMessage = "Meal description could not be read."
            return
        }
        let operation = AppLogger.begin(
            "bulk.extract",
            category: .bulkFood,
            source: "description",
            count: description.count
        )
        guard case .available = availability else {
            AppLogger.noop(operation, reason: "manual_fallback")
            beginManualReview(savedFoods: savedFoods)
            return
        }
        cancelWork()
        generation &+= 1
        let requestGeneration = generation
        stage = .extracting
        extractionTask = Task { [weak self, extractor] in
            do {
                let extraction = try await extractor.extract(description: description, locale: .current)
                guard let self, !Task.isCancelled, self.generation == requestGeneration else {
                    AppLogger.cancel(operation, reason: "superseded")
                    return
                }
                AppLogger.succeed(operation, count: extraction.items.count)
                await self.apply(extraction, savedFoods: savedFoods, generation: requestGeneration)
            } catch is CancellationError {
                AppLogger.cancel(operation)
                guard let self, self.generation == requestGeneration else { return }
                self.stage = .describe
            } catch {
                AppLogger.fail(operation, error: error)
                guard let self, self.generation == requestGeneration else { return }
                self.stage = .describe
                self.errorMessage = Self.extractionMessage(error)
            }
        }
    }

    func beginManualReview(savedFoods: [Food]) {
        cancelWork()
        clearCommitSnapshot()
        generation &+= 1
        #if DEBUG || RELEASE_VALIDATION
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-bulk-food"),
           let food = savedFoods.first(where: { $0.name == "Almond Milk" }) {
            let match = BulkFoodMatch(
                identity: .savedFood(food.stableID),
                displayName: food.name,
                barcode: food.barcode,
                source: .saved,
                servingAmount: food.servingGrams,
                servingUnit: food.nutritionUnit,
                caloriesPerServing: food.calories,
                nutrientsPerServing: food.nutrientsPerServing
            )
            items = [BulkFoodReviewItem(
                sourceQuery: "",
                query: food.name,
                amount: 100,
                unit: .grams,
                amountOrigin: .defaultAmount,
                selectedMatch: match,
                candidates: [match],
                matchPhase: .resolved
            )]
            stage = .review
            return
        }
        #endif
        items = [BulkFoodReviewItem(
            sourceQuery: "",
            query: "",
            amount: 100,
            unit: .grams,
            amountOrigin: .defaultAmount,
            matchPhase: .idle
        )]
        stage = .review
    }

    func addManualItem(savedFoods: [Food]) {
        clearCommitSnapshot()
        guard items.count < BulkFoodLimits.maximumItems else { return }
        #if DEBUG || RELEASE_VALIDATION
        let fixtureQuery = ProcessInfo.processInfo.arguments.contains("-ui-testing-bulk-food")
            ? (savedFoods.first(where: { $0.name == "Almond Milk" })?.name ?? "")
            : ""
        #else
        let fixtureQuery = ""
        #endif
        var item = BulkFoodReviewItem(
            sourceQuery: "",
            query: fixtureQuery,
            amount: 100,
            unit: .grams,
            amountOrigin: .defaultAmount
        )
        #if DEBUG || RELEASE_VALIDATION
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-bulk-food"),
           let food = savedFoods.first(where: { $0.name == "Almond Milk" }) {
            // Keep fixture independent from keyboard and matcher scheduling.
            let match = BulkFoodMatch(
                identity: .savedFood(food.stableID),
                displayName: food.name,
                barcode: food.barcode,
                source: .saved,
                servingAmount: food.servingGrams,
                servingUnit: food.nutritionUnit,
                caloriesPerServing: food.calories,
                nutrientsPerServing: food.nutrientsPerServing
            )
            item.selectedMatch = match
            item.candidates = [match]
            item.matchPhase = .resolved
        }
        #endif
        items.append(item)
    }

    func updateQuery(for id: UUID, query: String, savedFoods: [Food]) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].query = String(query.prefix(BulkFoodLimits.maximumQueryCharacters))
        items[index].revision &+= 1
        items[index].selectedMatch = nil
        items[index].candidates = []
        items[index].matchPhase = .idle
        scheduleMatch(for: id, savedFoods: savedFoods, debounce: true)
    }

    func updateAmount(for id: UUID, amount: Double) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].amount = amount
        items[index].amountOrigin = .userEdited
    }

    func invalidateAmount(for id: UUID) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].amount = .nan
        items[index].amountOrigin = .userEdited
    }

    func acceptReviewAmount(for id: UUID) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].amountOrigin == .modelEstimate || items[index].amountOrigin == .defaultAmount else {
            return
        }
        items[index].amountOrigin = .acceptedEstimate
    }

    func updateUnit(for id: UUID, unit: NutritionUnit, savedFoods: [Food]) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].unit = unit
        items[index].revision &+= 1
        items[index].selectedMatch = nil
        items[index].candidates = []
        items[index].matchPhase = .idle
        scheduleMatch(for: id, savedFoods: savedFoods, debounce: false)
    }

    func select(_ match: BulkFoodMatch, for id: UUID) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }),
              match.servingUnit == items[index].unit else { return }
        items[index].selectedMatch = match
        items[index].matchPhase = .resolved
    }

    func retry(_ id: UUID, savedFoods: [Food]) {
        scheduleMatch(for: id, savedFoods: savedFoods, debounce: false)
    }

    func selectSavedFood(_ food: Food, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              food.nutritionUnit == items[index].unit else { return }
        let match = BulkFoodMatch(
            identity: .savedFood(food.stableID),
            displayName: food.name,
            barcode: food.barcode,
            source: .custom,
            servingAmount: food.servingGrams,
            servingUnit: food.nutritionUnit,
            caloriesPerServing: food.calories,
            nutrientsPerServing: food.nutrientsPerServing
        )
        clearCommitSnapshot()
        items[index].query = food.name
        items[index].selectedMatch = match
        items[index].candidates = [match]
        items[index].matchPhase = .resolved
    }

    func offerSavedFoods(for id: UUID, savedFoods: [Food]) {
        clearCommitSnapshot()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let matches = savedFoods
            .filter { $0.nutritionUnit == items[index].unit }
            .sorted { lhs, rhs in
                let order = lhs.name.localizedStandardCompare(rhs.name)
                return order == .orderedSame
                    ? lhs.stableID.uuidString < rhs.stableID.uuidString
                    : order == .orderedAscending
            }
            .prefix(20)
            .map { food in
                BulkFoodMatch(
                    identity: .savedFood(food.stableID),
                    displayName: food.name,
                    barcode: food.barcode,
                    source: .saved,
                    servingAmount: food.servingGrams,
                    servingUnit: food.nutritionUnit,
                    caloriesPerServing: food.calories,
                    nutrientsPerServing: food.nutrientsPerServing
                )
            }
        items[index].candidates = Array(matches)
        items[index].matchPhase = items[index].candidates.isEmpty ? .failed(.noMatches) : .chooseMatch
    }

    func remove(_ id: UUID) {
        clearCommitSnapshot()
        matchTasks[id]?.cancel()
        matchTasks.removeValue(forKey: id)
        items.removeAll { $0.id == id }
    }

    func prepareCommit(date: Date = .now) async throws -> [BulkPlateInsert] {
        let inserts = try makeInserts(date: date)
        guard draftStore != nil, draftLease != nil else {
            clearCommitSnapshot()
            throw BulkFoodPersistenceError.unavailable
        }
        do {
            try await saveDraft()
            return inserts
        } catch {
            clearCommitSnapshot()
            throw error
        }
    }

    private func makeInserts(date: Date) throws -> [BulkPlateInsert] {
        if let commitInserts { return commitInserts }
        guard !items.isEmpty, items.allSatisfy(\.isReady) else {
            throw PlanEvidenceMutationError.invalidBulkBatch
        }
        let resolvedCommitDate = commitDate ?? date
        commitDate = resolvedCommitDate
        let inserts = try items.map { item in
            guard let match = item.selectedMatch else {
                throw PlanEvidenceMutationError.invalidBulkBatch
            }
            return BulkPlateInsert(
                id: BulkPlateInsert.stableID(operationID: operationID, sourceItemID: item.id),
                sourceItemID: item.id,
                match: match,
                amount: item.amount,
                unit: item.unit,
                mealType: selectedMeal.rawValue,
                date: resolvedCommitDate
            )
        }
        commitInserts = inserts
        committedLearningItems = items
        return inserts
    }

    func retainSuccessfulChoices() async throws {
        guard let committedLearningItems else {
            throw PlanEvidenceMutationError.invalidBulkBatch
        }
        var firstError: Error?
        if let learningStore, let learningLease {
            do {
                for item in committedLearningItems {
                    guard let selection = item.selectedMatch else { continue }
                    let knowledge: BulkAmountKnowledge = switch item.amountOrigin {
                    case .explicitDescription: .explicitDescription
                    case .modelEstimate, .defaultAmount, .acceptedEstimate: .acceptedEstimate
                    case .retainedCorrection, .userEdited: .userEdited
                    }
                    _ = try await learningStore.confirm(
                        source: item.sourceQuery.isEmpty ? item.query : item.sourceQuery,
                        confirmedQuery: item.query,
                        amount: item.amount,
                        unit: item.unit,
                        amountKnowledge: knowledge,
                        selection: selection,
                        lease: learningLease
                    )
                }
                try await learningStore.flushRecency(lease: learningLease)
            } catch {
                firstError = error
            }
        }
        if let draftStore {
            do {
                try await draftStore.clearIfMatching(storedDraftID ?? draftID)
                draftLease = await draftStore.acquireLease()
                storedDraftID = nil
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
    }

    func saveDraft() async throws {
        let operation = AppLogger.begin(
            "bulk.draft_save",
            category: .bulkFood,
            source: "bulk_review",
            count: items.count
        )
        guard let draftStore, let draftLease else {
            let error = BulkFoodPersistenceError.unavailable
            AppLogger.fail(operation, error: error)
            throw error
        }
        let draft = BulkFoodDraft(
            id: draftID,
            description: descriptionText,
            mealType: selectedMeal.rawValue,
            reviewItems: items.map(\.snapshot),
            operationID: operationID,
            commitDate: commitDate,
            updatedAt: .now
        )
        do {
            try await draftStore.save(draft, lease: draftLease)
            storedDraftID = draftID
            AppLogger.succeed(operation, count: items.count)
        } catch {
            AppLogger.fail(operation, error: error)
            throw error
        }
    }

    func discardDraft() async throws {
        let operation = AppLogger.begin(
            "bulk.draft_discard",
            category: .bulkFood,
            source: "bulk_review"
        )
        do {
            try await clearDraft()
            AppLogger.succeed(operation)
        } catch {
            AppLogger.fail(operation, error: error)
            throw error
        }
    }

    private func clearDraft() async throws {
        guard let draftStore, let draftLease else { throw BulkFoodPersistenceError.unavailable }
        try await draftStore.clear(lease: draftLease)
        self.draftLease = await draftStore.acquireLease()
        storedDraftID = nil
    }

    private func clearCommitSnapshot() {
        commitInserts = nil
        commitDate = nil
        committedLearningItems = nil
    }

    func cancelWork() {
        extractionTask?.cancel()
        extractionTask = nil
        generation &+= 1
        for task in matchTasks.values { task.cancel() }
        matchTasks = [:]
    }

    private func apply(
        _ extraction: BulkFoodExtraction,
        savedFoods: [Food],
        generation requestGeneration: Int64
    ) async {
        var reviewItems: [BulkFoodReviewItem] = []
        for extracted in extraction.items {
            var item = BulkFoodReviewItem(
                id: extracted.id,
                sourceQuery: extracted.sourceQuery,
                query: extracted.query,
                amount: extracted.amount,
                unit: extracted.unit,
                amountOrigin: extracted.amountOrigin,
                matchPhase: .searchingSaved
            )
            if let learned = await learningStore?.record(
                for: extracted.sourceQuery,
                unit: extracted.unit,
                touch: false
            ),
               learned.selectionSnapshot.isValid,
               learned.selectionSnapshot.servingUnit == extracted.unit,
               Self.learningSelectionStillValid(learned.selectionSnapshot, savedFoods: savedFoods) {
                _ = await learningStore?.record(
                    for: extracted.sourceQuery,
                    unit: extracted.unit,
                    touch: true
                )
                item.query = learned.confirmedQuery
                item.amount = learned.amount
                item.amountOrigin = BulkAmountOrigin.retainedOrigin(for: learned.amountKnowledge)
                let remembered = learned.selectionSnapshot.replacingSource(.remembered)
                item.selectedMatch = remembered
                item.candidates = [remembered]
                item.matchPhase = .resolved
            }
            reviewItems.append(item)
        }
        guard generation == requestGeneration else { return }
        items = reviewItems
        stage = .review
        for item in items where !item.isReady {
            scheduleMatch(for: item.id, savedFoods: savedFoods, debounce: false)
        }
    }

    private func scheduleMatch(for id: UUID, savedFoods: [Food], debounce: Bool) {
        matchTasks[id]?.cancel()
        guard let item = items.first(where: { $0.id == id }),
              (try? BulkFoodValidator.validateQuery(item.query)) != nil else { return }
        let request = BulkFoodMatchRequest(
            draftID: draftID,
            generation: generation,
            itemID: item.id,
            revision: item.revision,
            query: item.query,
            unit: item.unit
        )
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].matchPhase = .searchingSaved
        }
        let saved = savedCandidates(savedFoods)
        let allowRemote = allowRemoteMatching
        let learningStore = self.learningStore
        matchTasks[id] = Task { [weak self, matcher] in
            if debounce {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            let learned: BulkFoodLearningRecord? = if let learningStore {
                await learningStore.record(for: request.query, unit: request.unit, touch: false)
            } else {
                nil
            }
            let validLearned = learned.flatMap { record in
                Self.learningSelectionStillValid(record.selectionSnapshot, savedFoods: savedFoods)
                    ? record
                    : nil
            }
            let result = await matcher.match(
                request: request,
                savedCandidates: saved,
                learnedRecord: validLearned,
                allowRemote: allowRemote
            )
            guard let self, !Task.isCancelled,
                  self.generation == result.request.generation,
                  let index = self.items.firstIndex(where: {
                      $0.id == result.request.itemID && $0.revision == result.request.revision
                  }) else { return }
            self.items[index].candidates = result.candidates
            if let automatic = result.automaticSelection {
                self.items[index].selectedMatch = automatic
                self.items[index].matchPhase = .resolved
                if automatic.source == .remembered {
                    _ = await learningStore?.record(
                        for: request.query,
                        unit: request.unit,
                        touch: true
                    )
                }
            } else if let failure = result.failure, result.candidates.isEmpty {
                self.items[index].matchPhase = .failed(failure)
            } else {
                self.items[index].matchPhase = .chooseMatch
            }
            self.matchTasks.removeValue(forKey: id)
        }
    }

    private static func learningSelectionStillValid(
        _ selection: BulkFoodMatch,
        savedFoods: [Food]
    ) -> Bool {
        switch selection.identity {
        case .barcode(let barcode):
            // Remembered barcode nutrition must resolve to current saved data before auto-use.
            if let current = savedFoods.first(where: { $0.barcode == barcode }) {
                return selection.displayName == current.name
                    && selection.servingAmount.bitPattern == current.servingGrams.bitPattern
                    && selection.servingUnit == current.nutritionUnit
                    && selection.caloriesPerServing == current.calories
                    && selection.nutrientsPerServing == current.nutrientsPerServing
            }
            return false
        case .savedFood(let id):
            return savedFoods.contains {
                $0.stableID == id
                    && $0.name == selection.displayName
                    && $0.barcode == selection.barcode
                    && $0.servingGrams.bitPattern == selection.servingAmount.bitPattern
                    && $0.nutritionUnit == selection.servingUnit
                    && $0.calories == selection.caloriesPerServing
                    && $0.nutrientsPerServing == selection.nutrientsPerServing
            }
        }
    }

    private func savedCandidates(_ foods: [Food]) -> [BulkFoodSavedCandidate] {
        foods.map { food in
            BulkFoodSavedCandidate(match: BulkFoodMatch(
                identity: .savedFood(food.stableID),
                displayName: food.name,
                barcode: food.barcode,
                source: .saved,
                servingAmount: food.servingGrams,
                servingUnit: food.nutritionUnit,
                caloriesPerServing: food.calories,
                nutrientsPerServing: food.nutrientsPerServing
            ))
        }
    }

    private static func extractionMessage(_ error: Error) -> String {
        switch error as? BulkFoodExtractionFailure {
        case .emptyInput: "Describe at least one food first."
        case .inputTooLong: "Meal description must be 1,200 characters or fewer."
        case .refused, .safetyGuardrail:
            "This description couldn’t be structured. Edit it or add rows manually."
        case .contextLimit:
            "This description is too complex for one pass. Shorten it or add rows manually."
        case .resourcesUnavailable, .unavailable:
            "Apple’s on-device model isn’t ready. Try later or add rows manually."
        case .cancelled: "Meal structuring was canceled."
        case .invalidOutput, .unknown, nil:
            "Foods couldn’t be structured. Edit the description or add rows manually."
        }
    }
}

struct BulkMealLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let foods: [Food]
    @Bindable var controller: BulkMealDraftController
    let onCreateCustomFood: (UUID, String) -> Void
    let onConfirm: ([BulkPlateInsert], UUID) throws -> Void

    @State private var dictation = MealDictationController()
    @State private var showingDiscardAlert = false
    @State private var showingPendingDraftDiscardConfirmation = false
    @State private var pendingResultItemID: UUID?
    @State private var amountTexts: [UUID: String] = [:]
    @State private var dictationBaseText = ""
    @State private var dictationLogOperation: AppLogOperation?
    @State private var isCommitting = false
    @FocusState private var descriptionFocused: Bool
    @FocusState private var amountFieldFocused: Bool

    private struct BulkAmountAdjustment: Identifiable {
        let title: String
        let delta: Double
        let identifier: String

        var id: String { identifier }
    }

    private let amountAdjustments = [
        BulkAmountAdjustment(title: "−10", delta: -10, identifier: "decrease-10"),
        BulkAmountAdjustment(title: "−1", delta: -1, identifier: "decrease-1"),
        BulkAmountAdjustment(title: "+1", delta: 1, identifier: "increase-1"),
        BulkAmountAdjustment(title: "+10", delta: 10, identifier: "increase-10")
    ]

    var body: some View {
        NavigationStack {
            Group {
                if controller.isCheckingDraft {
                    ProgressView("Checking saved draft")
                        .accessibilityIdentifier("bulk-meal-draft-checking")
                } else if let draft = controller.pendingDraftChoice {
                    draftChoice(draft)
                } else {
                    switch controller.stage {
                    case .describe:
                        describeForm
                    case .extracting:
                        extractingView
                    case .review, .confirming:
                        reviewForm
                    }
                }
            }
            .navigationTitle(controller.pendingDraftChoice != nil ? "Saved meal draft" : (controller.stage == .review ? "Review \(controller.items.count) Foods" : "Describe meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        descriptionFocused = false
                        amountFieldFocused = false
                    }
                    .accessibilityIdentifier("bulk-meal-keyboard-done")
                }
            }
            .alert("Could not complete action", isPresented: Binding(
                get: { controller.errorMessage != nil },
                set: { if !$0 { controller.errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(controller.errorMessage ?? "Unknown error")
            }
            .confirmationDialog("Discard saved draft?", isPresented: $showingPendingDraftDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard Draft", role: .destructive) {
                    Task {
                        do {
                            try await controller.discardPendingDraft()
                            scheduleDescriptionFocus()
                        } catch {
                            controller.errorMessage = "Saved draft could not be discarded. It is still available to resume."
                        }
                    }
                }
                .accessibilityIdentifier("bulk-meal-confirm-discard-draft")
                Button("Keep Draft", role: .cancel) {}
            } message: {
                Text("This removes saved description and review. This cannot be undone.")
            }
            .alert("Cancel meal description?", isPresented: $showingDiscardAlert) {
                Button("Keep Draft") {
                    Task {
                        do {
                            try await controller.saveDraft()
                            dismiss()
                        } catch {
                            controller.errorMessage = "Draft could not be saved. Keep reviewing or try again."
                        }
                    }
                }
                Button("Discard Draft", role: .destructive) {
                    Task {
                        do {
                            try await controller.discardDraft()
                            dismiss()
                        } catch {
                            controller.errorMessage = "Draft could not be discarded. Keep reviewing or try again."
                        }
                    }
                }
                Button("Keep Reviewing", role: .cancel) {}
            } message: {
                Text("No food has been logged yet. Keep this editable draft or discard it.")
            }
            .confirmationDialog(
                "Choose a food",
                isPresented: Binding(
                    get: { pendingResultItemID != nil },
                    set: { if !$0 { pendingResultItemID = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let id = pendingResultItemID,
                   let item = controller.items.first(where: { $0.id == id }) {
                    ForEach(item.candidates) { candidate in
                        Button(candidateChoiceTitle(candidate)) {
                            controller.select(candidate, for: id)
                            pendingResultItemID = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { pendingResultItemID = nil }
            }
        }
        .task {
            await controller.checkForDraftIfNeeded()
            scheduleDescriptionFocus()
        }
        .onChange(of: controller.pendingDraftChoice?.id) { _, _ in
            scheduleDescriptionFocus()
        }
        .onChange(of: controller.stage) { oldStage, newStage in
            guard oldStage == .extracting, newStage == .review else { return }
            announce("Meal structured. Review \(controller.items.count) foods.")
        }
        .onChange(of: controller.items.map(\.id)) { _, ids in
            let retainedIDs = Set(ids)
            amountTexts = amountTexts.filter { retainedIDs.contains($0.key) }
        }
        .onChange(of: controller.blockerCount) { _, blockers in
            guard controller.stage == .review else { return }
            announce(blockers == 0
                ? "All foods are ready to log."
                : "\(blockers) food \(blockers == 1 ? "needs" : "need") review.")
        }
        .onChange(of: dictation.state) { _, newState in
            applyDictation(new: newState)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await dictation.refreshPermissionStatus() }
                return
            }
            if controller.stage == .review {
                Task { try? await controller.saveDraft() }
            }
            if dictation.hasActiveRequest {
                cancelDictationLog(reason: "scene_inactive")
                Task { await dictation.cancel() }
            }
        }
        .onDisappear {
            controller.cancelWork()
            cancelDictationLog(reason: "view_dismissed")
            Task { await dictation.cancel() }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(
            controller.isCheckingDraft
                || controller.pendingDraftChoice != nil
                || !controller.descriptionText.isEmpty
                || controller.stage == .extracting
                || controller.stage == .review
                || controller.stage == .confirming
        )
        .disabled(isCommitting)
        .accessibilityIdentifier("bulk-meal-editor")
    }

    private func draftChoice(_ draft: BulkFoodDraft) -> some View {
        ContentUnavailableView {
            Label("Saved draft", systemImage: "doc.text")
        } description: {
            Text(draft.description.isEmpty ? "Saved review is ready to continue." : draft.description)
        } actions: {
            VStack(spacing: 12) {
                Button("Resume Draft") {
                    controller.resumePendingDraft(savedFoods: foods)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("bulk-meal-resume-draft")

                Button("Start New") {
                    controller.startNewDraft()
                    scheduleDescriptionFocus()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("bulk-meal-start-new")

                Button("Discard Draft", role: .destructive) {
                    showingPendingDraftDiscardConfirmation = true
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("bulk-meal-discard-draft")
            }
        }
        .padding()
    }

    private var describeForm: some View {
        Form {
            Section("Meal") {
                mealPicker
                if controller.showingResumedDraft {
                    Label("Saved draft restored", systemImage: "arrow.counterclockwise")
                        .accessibilityIdentifier("bulk-meal-restored-draft")
                }
            }

            Section {
                TextEditor(text: $controller.descriptionText)
                    .frame(minHeight: 130)
                    .focused($descriptionFocused)
                    .accessibilityLabel("Meal description")
                    .accessibilityHint("Describe foods and amounts in one paragraph.")
                    .accessibilityIdentifier("bulk-meal-description")
                    .onChange(of: controller.descriptionText) { _, value in
                        if value.count > BulkFoodLimits.maximumDescriptionCharacters {
                            controller.descriptionText = String(value.prefix(BulkFoodLimits.maximumDescriptionCharacters))
                        }
                    }

                HStack {
                    if dictation.isSupported {
                        Button(action: toggleDictation) {
                            Label(dictationButtonTitle, systemImage: dictation.isListening ? "stop.circle.fill" : "mic.fill")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(minHeight: 44)
                        }
                        .disabled(!dictation.canToggle)
                        .accessibilityIdentifier("bulk-meal-dictate")
                    }
                    Spacer()
                    Text("\(controller.descriptionText.count)/\(BulkFoodLimits.maximumDescriptionCharacters)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let dictationStatusText {
                    Label(dictationStatusText, systemImage: dictationStatusSymbol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(dictationAccessibilityStatus)
                        .accessibilityIdentifier("bulk-meal-dictation-status")
                }

                if dictation.needsMicrophoneSettings {
                    Button("Open Microphone Settings", action: openMicrophoneSettings)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("bulk-meal-open-microphone-settings")
                }
            } header: {
                Text("What did you eat?")
            } footer: {
                Text("Example: 200 g chicken, 150 g rice, broccoli, and 250 ml oat milk.")
            }

            Section {
                if case .available = controller.availability {
                    Button {
                        descriptionFocused = false
                        Task {
                            if dictation.isListening {
                                await dictation.stop()
                            } else if dictation.hasActiveRequest {
                                await dictation.cancel()
                            }
                            controller.beginExtraction(savedFoods: foods)
                        }
                    } label: {
                        Label("Find Foods", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(controller.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("bulk-meal-find-foods")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meal descriptions unavailable", systemImage: "apple.intelligence")
                            .font(.headline)
                        Text(availabilityMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("bulk-meal-availability-message")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }

                Button("Add Rows Manually") {
                    controller.beginManualReview(savedFoods: foods)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("bulk-meal-manual")
            } footer: {
                Text("Description is processed on this device. Food search sends each food query—not your full description—to Open Food Facts.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var extractingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Structuring meal on device…")
                .font(.headline)
            Text("No food is logged until you review and confirm every row.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Cancel") {
                controller.cancelWork()
                controller.stage = .describe
            }
            .frame(minHeight: 44)
        }
        .padding(32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bulk-meal-extracting")
    }

    private var reviewForm: some View {
        Form {
            Section {
                mealPicker
                if controller.showingResumedDraft {
                    Label("Saved draft restored", systemImage: "arrow.counterclockwise")
                        .accessibilityIdentifier("bulk-meal-restored-draft")
                }
                Text("AI structured your description. Nutrition comes from selected food records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(controller.progressSummary)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("bulk-meal-progress")
            }

            ForEach(controller.items) { item in
                Section {
                    reviewRow(item)
                } header: {
                    Text("Food \((controller.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1)")
                }
            }

            Section {
                Button {
                    controller.addManualItem(savedFoods: foods)
                } label: {
                    Label("Add another food", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(controller.items.count >= BulkFoodLimits.maximumItems)
                .accessibilityIdentifier("bulk-meal-add-row")
            }

            Section {
                confirmBar
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func reviewRow(_ item: BulkFoodReviewItem) -> some View {
        TextField("Food query", text: Binding(
            get: { controller.items.first(where: { $0.id == item.id })?.query ?? "" },
            set: { controller.updateQuery(for: item.id, query: $0, savedFoods: foods) }
        ))
        .frame(minHeight: 44)
        .textInputAutocapitalization(.words)
        .accessibilityLabel("Food query for \(item.query)")
        .accessibilityIdentifier("bulk-food-query-\(item.id.uuidString)")

        LabeledContent(item.unit == .milliliters ? "Volume" : "Amount") {
            HStack {
                TextField("Amount", text: amountTextBinding(for: item))
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("bulk-food-amount-\(item.id.uuidString)")
                .focused($amountFieldFocused)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("Amount for \(item.query)")
                .frame(minWidth: 78, minHeight: 44)

                Picker("Unit", selection: Binding(
                    get: { controller.items.first(where: { $0.id == item.id })?.unit ?? .grams },
                    set: { controller.updateUnit(for: item.id, unit: $0, savedFoods: foods) }
                )) {
                    Text("g").tag(NutritionUnit.grams)
                    Text("ml").tag(NutritionUnit.milliliters)
                }
                .labelsHidden()
                .fixedSize()
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
        }

        Text(item.amountOrigin.reviewTitle)
            .font(.caption.weight(.medium))
            .foregroundStyle(item.amountOrigin == .modelEstimate ? .primary : .secondary)
            .accessibilityIdentifier("bulk-food-amount-origin-\(item.id.uuidString)")

        amountAdjustmentControls(for: item)

        if item.amountOrigin == .modelEstimate || item.amountOrigin == .defaultAmount {
            let isEstimate = item.amountOrigin == .modelEstimate
            Button {
                controller.acceptReviewAmount(for: item.id)
            } label: {
                Text(isEstimate ? "Use Estimated Amount" : "Use Default Amount")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Use \(isEstimate ? "estimated" : "default") amount for \(item.query)")
            .accessibilityIdentifier("bulk-food-\(isEstimate ? "accept-estimate" : "accept-default")-\(item.id.uuidString)")
        }

        matchPresentation(item)

        Button(role: .destructive) {
            controller.remove(item.id)
        } label: {
            Text("Remove Food")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityLabel("Remove \(item.query)")
        .accessibilityIdentifier("bulk-food-remove-\(item.id.uuidString)")
    }

    private func amountTextBinding(for item: BulkFoodReviewItem) -> Binding<String> {
        Binding(
            get: {
                amountTexts[item.id]
                    ?? item.amount.formatted(.number.precision(.fractionLength(0...2)))
            },
            set: { text in
                amountTexts[item.id] = text
                guard let amount = parsedAmount(text) else {
                    controller.invalidateAmount(for: item.id)
                    return
                }
                controller.updateAmount(for: item.id, amount: amount)
            }
        )
    }

    private func parsedAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.isLenient = false
        guard let amount = formatter.number(from: trimmed)?.doubleValue,
              (try? BulkFoodValidator.validateAmount(amount)) != nil else { return nil }
        return amount
    }

    @ViewBuilder
    private func amountAdjustmentControls(for item: BulkFoodReviewItem) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(amountAdjustments) { adjustment in
                    amountAdjustmentButton(adjustment, for: item)
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(amountAdjustments) { adjustment in
                    amountAdjustmentButton(adjustment, for: item)
                }
            }
        }
    }

    private func amountAdjustmentButton(
        _ adjustment: BulkAmountAdjustment,
        for item: BulkFoodReviewItem
    ) -> some View {
        let result = FoodAmountAdjustment.result(for: item.amount, delta: adjustment.delta).flatMap { value in
            (try? BulkFoodValidator.validateAmount(value)) == nil ? nil : value
        }
        let noun = item.unit == .milliliters ? "volume" : "amount"
        let unit = item.unit == .milliliters ? "milliliters" : "grams"
        let action = adjustment.delta < 0 ? "Decrease" : "Increase"
        let magnitude = abs(adjustment.delta).formatted(.number.precision(.fractionLength(0...2)))
        let current = item.amount.formatted(.number.precision(.fractionLength(0...2)))

        return Button {
            guard let result else { return }
            amountTexts[item.id] = result.formatted(.number.precision(.fractionLength(0...2)))
            controller.updateAmount(for: item.id, amount: result)
        } label: {
            Text(adjustment.title)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, minHeight: 44)
        .disabled(result == nil)
        .accessibilityLabel("\(action) \(noun) by \(magnitude) \(unit)")
        .accessibilityValue("Current \(current) \(unit)")
        .accessibilityHint("Marks amount as edited.")
        .accessibilityIdentifier("bulk-food-amount-\(adjustment.identifier)-\(item.id.uuidString)")
    }

    @ViewBuilder
    private func matchPresentation(_ item: BulkFoodReviewItem) -> some View {
        switch item.matchPhase {
        case .idle:
            if item.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Enter a food query", systemImage: "pencil")
                    .foregroundStyle(.secondary)
            } else {
                Button("Find Matches") { controller.retry(item.id, savedFoods: foods) }
            }
        case .searchingSaved, .searchingRemote:
            HStack(spacing: 8) {
                ProgressView()
                Text("Searching food records")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("bulk-food-searching-\(item.id.uuidString)")
        case .resolved:
            if let match = item.selectedMatch, let calories = item.calories {
                Button {
                    pendingResultItemID = item.id
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.displayName)
                            .foregroundStyle(.primary)
                        Text("\(calories) kcal · \(match.source.reviewTitle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(matchServingBasis(match))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Selected food, \(match.displayName)")
                .accessibilityValue("\(calories) calories, \(match.source.reviewTitle)")
            }
        case .chooseMatch:
            Button {
                pendingResultItemID = item.id
            } label: {
                Label("Review \(item.candidates.count) Matches", systemImage: "list.bullet")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("bulk-food-choose-\(item.id.uuidString)")
        case .failed(let failure):
            VStack(alignment: .leading, spacing: 8) {
                Label(matchFailureMessage(failure), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Retry") { controller.retry(item.id, savedFoods: foods) }
                        .frame(minHeight: 44)
                    Button("Choose Saved Food") {
                        controller.offerSavedFoods(for: item.id, savedFoods: foods)
                        pendingResultItemID = item.id
                    }
                    .frame(minHeight: 44)
                }
                Button("Create Custom Food") {
                    onCreateCustomFood(item.id, item.query)
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("bulk-food-create-custom-\(item.id.uuidString)")
                Text("Change the query above, choose or create a saved food, retry, or remove this row.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("bulk-food-failure-\(item.id.uuidString)")
        }
    }

    private func matchServingBasis(_ match: BulkFoodMatch) -> String {
        let amount = match.servingAmount.formatted(.number.precision(.fractionLength(0...2)))
        return "\(match.caloriesPerServing) kcal per \(amount) \(match.servingUnit.rawValue)"
    }

    private func candidateChoiceTitle(_ match: BulkFoodMatch) -> String {
        "\(match.displayName) · \(matchServingBasis(match)) · \(match.source.reviewTitle)"
    }

    private var mealPicker: some View {
        Picker("Meal", selection: $controller.selectedMeal) {
            ForEach(MealType.allCases) { meal in
                Text(meal.rawValue).tag(meal)
            }
        }
        .accessibilityIdentifier("bulk-meal-type")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if controller.descriptionText.isEmpty && controller.items.isEmpty {
                    dismiss()
                } else {
                    showingDiscardAlert = true
                }
            } label: {
                Text("Cancel")
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("bulk-meal-cancel")
        }
    }

    private var confirmBar: some View {
        VStack(spacing: 6) {
            Button(action: confirm) {
                let total = controller.totalCalories ?? 0
                Text("Log \(controller.items.count) Foods · \(total) kcal")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(controller.totalCalories == nil || isCommitting)
            .accessibilityIdentifier("bulk-meal-confirm")
            .accessibilityHint(controller.blockerCount == 0
                ? "Logs every reviewed food in one transaction."
                : "Resolve \(controller.blockerCount) food rows before logging.")

            if controller.blockerCount > 0 {
                Text("Resolve \(controller.blockerCount) \(controller.blockerCount == 1 ? "food" : "foods") to continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func confirm() {
        guard !isCommitting else { return }
        isCommitting = true
        let operation = AppLogger.begin(
            "bulk.review_confirm",
            category: .bulkFood,
            source: "bulk_review",
            count: controller.items.count,
            id: controller.operationID
        )
        Task { @MainActor in
            do {
                let inserts = try await controller.prepareCommit()
                try onConfirm(inserts, controller.operationID)
                let total = inserts.compactMap { $0.match.calories(for: $0.amount) }.reduce(0, +)
                announce("Logged \(inserts.count) foods, \(total) calories.")
                let cleanupSucceeded: Bool
                do {
                    try await controller.retainSuccessfulChoices()
                    cleanupSucceeded = true
                } catch {
                    cleanupSucceeded = false
                }
                if cleanupSucceeded {
                    AppLogger.succeed(operation, count: inserts.count)
                } else {
                    AppLogger.partial(operation, failedComponent: "learning_or_draft_cleanup")
                }
                dismiss()
            } catch {
                AppLogger.fail(operation, error: error, rollback: "succeeded")
                isCommitting = false
                controller.errorMessage = "Your foods could not be logged. Nothing was added. Please try again."
            }
        }
    }

    private func announce(_ message: String) {
#if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
#endif
    }

    private func scheduleDescriptionFocus() {
        guard !controller.isCheckingDraft,
              controller.pendingDraftChoice == nil,
              controller.stage == .describe,
              !controller.showingResumedDraft else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !controller.isCheckingDraft,
                  controller.pendingDraftChoice == nil,
                  controller.stage == .describe,
                  !controller.showingResumedDraft else { return }
            descriptionFocused = true
        }
    }

    private func toggleDictation() {
        guard dictation.canToggle else { return }
        descriptionFocused = false
        Task {
            if dictation.isListening {
                await dictation.stop()
            } else {
                dictationBaseText = controller.descriptionText
                dictationLogOperation = AppLogger.begin(
                    "dictation.capture",
                    category: .bulkFood,
                    source: "bulk_description"
                )
                await dictation.start()
            }
        }
    }

    private func cancelDictationLog(reason: String) {
        guard let operation = dictationLogOperation else { return }
        AppLogger.cancel(operation, reason: reason)
        dictationLogOperation = nil
    }

    private func openMicrophoneSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func applyDictation(new: MealDictationState) {
        let transcript: String
        switch new {
        case .listening(let finalized, _):
            transcript = finalized.trimmingCharacters(in: .whitespacesAndNewlines)
        case .failed(let failure):
            if let operation = dictationLogOperation {
                AppLogger.fail(operation, error: failure)
                dictationLogOperation = nil
            }
            transcript = dictation.currentFinalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .idle:
            if let operation = dictationLogOperation {
                AppLogger.succeed(operation)
                dictationLogOperation = nil
            }
            return
        case .requestingPermission, .preparingAssets, .finishing:
            return
        }
        guard !transcript.isEmpty else { return }
        controller.descriptionText = [dictationBaseText, transcript]
            .filter { !$0.isEmpty }
            .joined(separator: dictationBaseText.isEmpty ? "" : " ")
    }

    private var dictationButtonTitle: String {
        switch dictation.state {
        case .listening: "Stop Dictation"
        case .requestingPermission, .preparingAssets, .finishing: "Preparing…"
        case .failed: "Try Dictation Again"
        case .idle: "Dictate"
        }
    }

    private var dictationStatusText: String? {
        switch dictation.state {
        case .idle: nil
        case .requestingPermission: "Waiting for microphone access"
        case .preparingAssets: "Preparing on-device speech"
        case .listening(_, let volatile): volatile.isEmpty ? "Listening…" : volatile
        case .finishing: "Finishing dictation…"
        case .failed(let failure): dictationFailureMessage(failure)
        }
    }

    private var dictationAccessibilityStatus: String {
        switch dictation.state {
        case .listening: "Listening. Dictated text remains editable."
        default: dictationStatusText ?? ""
        }
    }

    private var dictationStatusSymbol: String {
        switch dictation.state {
        case .failed: "exclamationmark.circle"
        case .listening: "waveform"
        default: "hourglass"
        }
    }

    private var availabilityMessage: String {
        guard case .unavailable(let reason) = controller.availability else { return "" }
        return switch reason {
        case .operatingSystem, .deviceNotEligible:
            "Meal descriptions need Apple Intelligence on a supported device. You can add review rows manually."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings, or add rows manually."
        case .modelNotReady:
            "Apple’s on-device model is still preparing. Try later or add rows manually."
        case .unsupportedLocale:
            "Meal descriptions aren’t available for this language yet. Add rows manually."
        case .unknown:
            "Apple’s on-device model is unavailable. Add rows manually."
        }
    }

    private func matchFailureMessage(_ failure: BulkFoodMatchFailure) -> String {
        switch failure {
        case .invalidQuery: "Enter a valid food query."
        case .noMatches: "No food record matched. Change the query or retry."
        case .offline: "No connection for more matches. Saved foods still work."
        case .rateLimited: "Food search is paused. Wait a moment, then retry."
        case .unavailable: "Open Food Facts is unavailable. Saved foods still work."
        case .cancelled: "Search was canceled."
        }
    }

    private func dictationFailureMessage(_ failure: MealDictationFailure) -> String {
        switch failure {
        case .permissionDenied: "Microphone access is off. Type your meal instead."
        case .unsupportedLocale: "Dictation isn’t available for this language. Type your meal instead."
        case .assetsUnavailable: "On-device speech isn’t ready. Type your meal or try later."
        case .operatingSystem: "On-device dictation needs iOS 26. Type your meal instead."
        case .noInputDevice: "No microphone is available. Type your meal instead."
        case .interrupted: "Dictation was interrupted. Your text is still editable."
        case .resourcesUnavailable, .unknown: "Dictation stopped. Type your meal or try again."
        }
    }
}
