import Foundation

nonisolated enum BulkFoodLimits {
    static let maximumDescriptionCharacters = 1_200
    static let maximumItems = 12
    static let maximumQueryCharacters = 80
    static let minimumAmount = 0.01
    static let maximumAmount = 5_000.0
    static let maximumLearningRecords = 256
    static let maximumLearningBytes = 1 * 1_024 * 1_024
    static let draftLifetime: TimeInterval = 7 * 24 * 60 * 60
}

nonisolated enum BulkAmountOrigin: String, Codable, Equatable, Sendable {
    case explicitDescription
    case modelEstimate
    case defaultAmount
    case acceptedEstimate
    case retainedCorrection
    case userEdited

    var reviewTitle: String {
        switch self {
        case .explicitDescription: "From description"
        case .modelEstimate: "Estimated — review"
        case .defaultAmount: "Default — review"
        case .acceptedEstimate: "Estimate accepted"
        case .retainedCorrection: "Remembered"
        case .userEdited: "Edited"
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .modelEstimate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func retainedOrigin(for knowledge: BulkAmountKnowledge) -> BulkAmountOrigin {
        switch knowledge {
        case .acceptedEstimate: .acceptedEstimate
        case .explicitDescription: .explicitDescription
        case .userEdited: .retainedCorrection
        }
    }
}

nonisolated struct BulkFoodExtractedItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sourceQuery: String
    var query: String
    var amount: Double
    var unit: NutritionUnit
    var amountOrigin: BulkAmountOrigin

    init(
        id: UUID = UUID(),
        sourceQuery: String? = nil,
        query: String,
        amount: Double,
        unit: NutritionUnit,
        amountOrigin: BulkAmountOrigin
    ) {
        self.id = id
        self.sourceQuery = sourceQuery ?? query
        self.query = query
        self.amount = amount
        self.unit = unit
        self.amountOrigin = amountOrigin
    }
}

nonisolated struct BulkFoodExtraction: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let items: [BulkFoodExtractedItem]

    init(schemaVersion: Int = Self.schemaVersion, items: [BulkFoodExtractedItem]) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

nonisolated enum BulkFoodPersistenceError: Error, Equatable, Sendable {
    case unavailable
    case staleLease
}

nonisolated enum BulkFoodValidationError: Error, Equatable, Sendable {
    case emptyDescription
    case descriptionTooLong
    case unsupportedSchema(Int)
    case invalidItemCount
    case duplicateItemID
    case emptyQuery
    case queryTooLong
    case queryContainsControlCharacters
    case invalidAmount
}

nonisolated enum BulkFoodValidator {
    static func validateDescription(_ description: String) throws -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BulkFoodValidationError.emptyDescription }
        guard trimmed.count <= BulkFoodLimits.maximumDescriptionCharacters else {
            throw BulkFoodValidationError.descriptionTooLong
        }
        return trimmed
    }

    static func validate(_ extraction: BulkFoodExtraction) throws -> BulkFoodExtraction {
        guard extraction.schemaVersion == BulkFoodExtraction.schemaVersion else {
            throw BulkFoodValidationError.unsupportedSchema(extraction.schemaVersion)
        }
        guard (1...BulkFoodLimits.maximumItems).contains(extraction.items.count) else {
            throw BulkFoodValidationError.invalidItemCount
        }
        guard Set(extraction.items.map(\.id)).count == extraction.items.count else {
            throw BulkFoodValidationError.duplicateItemID
        }

        let validatedItems = try extraction.items.map(validate)
        return BulkFoodExtraction(items: validatedItems)
    }

    static func validate(_ item: BulkFoodExtractedItem) throws -> BulkFoodExtractedItem {
        let sourceQuery = try validateQuery(item.sourceQuery)
        let query = try validateQuery(item.query)
        let amount = try validateAmount(item.amount)
        return BulkFoodExtractedItem(
            id: item.id,
            sourceQuery: sourceQuery,
            query: query,
            amount: amount,
            unit: item.unit,
            amountOrigin: item.amountOrigin
        )
    }

    static func validateQuery(_ query: String) throws -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BulkFoodValidationError.emptyQuery }
        guard trimmed.count <= BulkFoodLimits.maximumQueryCharacters else {
            throw BulkFoodValidationError.queryTooLong
        }
        guard trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw BulkFoodValidationError.queryContainsControlCharacters
        }
        return trimmed
    }

    static func validateAmount(_ amount: Double) throws -> Double {
        guard amount.isFinite,
              amount >= BulkFoodLimits.minimumAmount,
              amount <= BulkFoodLimits.maximumAmount else {
            throw BulkFoodValidationError.invalidAmount
        }
        return amount
    }
}

nonisolated enum BulkFoodExtractionUnavailableReason: String, Codable, Equatable, Sendable {
    case operatingSystem
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedLocale
    case unknown
}

nonisolated enum BulkFoodExtractionAvailability: Equatable, Sendable {
    case available
    case unavailable(BulkFoodExtractionUnavailableReason)
}

nonisolated enum BulkFoodExtractionFailure: Error, Equatable, Sendable {
    case unavailable(BulkFoodExtractionUnavailableReason)
    case emptyInput
    case inputTooLong
    case refused
    case safetyGuardrail
    case contextLimit
    case invalidOutput
    case resourcesUnavailable
    case cancelled
    case unknown
}

nonisolated protocol BulkFoodExtracting: Sendable {
    func availability(for locale: Locale) -> BulkFoodExtractionAvailability
    func extract(description: String, locale: Locale) async throws -> BulkFoodExtraction
}

nonisolated enum BulkFoodIdentity: Hashable, Codable, Sendable {
    case barcode(String)
    case savedFood(UUID)
}

nonisolated enum BulkFoodMatchSource: String, Codable, Equatable, Sendable {
    case remembered
    case saved
    case cache
    case openFoodFacts
    case custom

    var reviewTitle: String {
        switch self {
        case .remembered: "Remembered"
        case .saved: "Saved"
        case .cache: "Open Food Facts cache"
        case .openFoodFacts: "Open Food Facts"
        case .custom: "Custom"
        }
    }
}

nonisolated struct BulkFoodMatch: Codable, Equatable, Identifiable, Sendable {
    let identity: BulkFoodIdentity
    let displayName: String
    let barcode: String?
    let source: BulkFoodMatchSource
    let servingAmount: Double
    let servingUnit: NutritionUnit
    let caloriesPerServing: Int
    let nutrientsPerServing: FoodNutrients

    var id: BulkFoodIdentity { identity }

    init(
        identity: BulkFoodIdentity,
        displayName: String,
        barcode: String? = nil,
        source: BulkFoodMatchSource,
        servingAmount: Double,
        servingUnit: NutritionUnit,
        caloriesPerServing: Int,
        nutrientsPerServing: FoodNutrients = .empty
    ) {
        self.identity = identity
        self.displayName = displayName
        self.barcode = barcode
        self.source = source
        self.servingAmount = servingAmount
        self.servingUnit = servingUnit
        self.caloriesPerServing = caloriesPerServing
        self.nutrientsPerServing = nutrientsPerServing
    }

    static func from(_ food: FoodNutrition, source: BulkFoodMatchSource) -> BulkFoodMatch? {
        guard Self.isValidBarcode(food.barcode) else { return nil }
        let servingCaloriesDouble = food.calories(for: food.defaultAmount.value)
        guard servingCaloriesDouble.isFinite,
              servingCaloriesDouble >= 0,
              servingCaloriesDouble <= Double(FoodCaloriePolicy.maximumCaloriesPerFood) else { return nil }
        return BulkFoodMatch(
            identity: .barcode(food.barcode),
            displayName: food.name,
            barcode: food.barcode,
            source: source,
            servingAmount: food.defaultAmount.value,
            servingUnit: food.defaultAmount.unit,
            caloriesPerServing: Int(servingCaloriesDouble.rounded()),
            nutrientsPerServing: food.nutrients(for: food.defaultAmount.value)
        )
    }

    func replacingSource(_ source: BulkFoodMatchSource) -> BulkFoodMatch {
        BulkFoodMatch(
            identity: identity,
            displayName: displayName,
            barcode: barcode,
            source: source,
            servingAmount: servingAmount,
            servingUnit: servingUnit,
            caloriesPerServing: caloriesPerServing,
            nutrientsPerServing: nutrientsPerServing
        )
    }

    func calories(for amount: Double) -> Int? {
        guard servingAmount.isFinite,
              servingAmount > 0,
              amount.isFinite,
              amount > 0,
              caloriesPerServing >= 0 else { return nil }
        let value = Double(caloriesPerServing) / servingAmount * amount
        guard value.isFinite,
              value >= 0,
              value <= Double(FoodCaloriePolicy.maximumCaloriesPerFood) else { return nil }
        return Int(value.rounded())
    }

    func nutrients(for amount: Double) -> FoodNutrients? {
        guard servingAmount.isFinite,
              servingAmount > 0,
              amount.isFinite,
              amount > 0 else { return nil }
        let multiplier = amount / servingAmount
        return nutrientsPerServing.scaledIfFinite(by: multiplier)
    }

    var isValid: Bool {
        let identityIsValid: Bool
        switch identity {
        case .barcode(let value): identityIsValid = Self.isValidBarcode(value)
        case .savedFood(let id):
            identityIsValid = id != UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            )
        }
        return identityIsValid
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && servingAmount.isFinite
            && servingAmount > 0
            && servingAmount <= BulkFoodLimits.maximumAmount
            && FoodCaloriePolicy.isValid(caloriesPerServing)
    }

    private static func isValidBarcode(_ barcode: String) -> Bool {
        guard (8...14).contains(barcode.utf8.count) else { return false }
        return barcode.utf8.allSatisfy { (48...57).contains($0) }
    }
}

nonisolated enum BulkFoodMatchFailure: String, Codable, Equatable, Sendable {
    case invalidQuery
    case noMatches
    case offline
    case rateLimited
    case unavailable
    case cancelled
}

nonisolated enum BulkFoodMatchPhase: Equatable, Sendable {
    case idle
    case searchingSaved
    case searchingRemote
    case chooseMatch
    case resolved
    case failed(BulkFoodMatchFailure)
}

nonisolated struct BulkFoodReviewItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceQuery: String
    var query: String
    var amount: Double
    var unit: NutritionUnit
    var amountOrigin: BulkAmountOrigin
    var selectedMatch: BulkFoodMatch?
    var candidates: [BulkFoodMatch]
    var matchPhase: BulkFoodMatchPhase
    var revision: Int64

    init(
        id: UUID = UUID(),
        sourceQuery: String,
        query: String,
        amount: Double,
        unit: NutritionUnit,
        amountOrigin: BulkAmountOrigin,
        selectedMatch: BulkFoodMatch? = nil,
        candidates: [BulkFoodMatch] = [],
        matchPhase: BulkFoodMatchPhase = .idle,
        revision: Int64 = 0
    ) {
        self.id = id
        self.sourceQuery = sourceQuery
        self.query = query
        self.amount = amount
        self.unit = unit
        self.amountOrigin = amountOrigin
        self.selectedMatch = selectedMatch
        self.candidates = candidates
        self.matchPhase = matchPhase
        self.revision = revision
    }

    var calories: Int? { selectedMatch?.calories(for: amount) }

    var isReady: Bool {
        guard case .resolved = matchPhase else { return false }
        return amountOrigin != .modelEstimate
            && amountOrigin != .defaultAmount
            && selectedMatch?.isValid == true
            && (try? BulkFoodValidator.validateQuery(query)) != nil
            && (try? BulkFoodValidator.validateAmount(amount)) != nil
            && selectedMatch?.servingUnit == unit
            && calories != nil
    }

    var snapshot: BulkFoodReviewItemSnapshot {
        BulkFoodReviewItemSnapshot(
            id: id,
            sourceQuery: sourceQuery,
            query: query,
            amount: amount,
            unit: unit,
            amountOrigin: amountOrigin,
            selectedMatch: selectedMatch
        )
    }
}

nonisolated struct BulkFoodCandidate: Equatable, Sendable {
    let match: BulkFoodMatch
    let priorUseCount: Int
    let lastUsedAt: Date?

    init(match: BulkFoodMatch, priorUseCount: Int = 0, lastUsedAt: Date? = nil) {
        self.match = match
        self.priorUseCount = max(0, priorUseCount)
        self.lastUsedAt = lastUsedAt
    }
}

nonisolated enum BulkFoodText {
    static func normalizedKey(_ value: String) -> String {
        let surrounding = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
        return value
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: surrounding)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive], locale: nil)
    }

    static func tokens(_ value: String) -> [String] {
        normalizedKey(value).split(separator: " ").map(String.init)
    }
}

nonisolated enum BulkFoodCandidateRanker {
    static func ranked(
        query: String,
        unit: NutritionUnit,
        candidates: [BulkFoodCandidate]
    ) -> [BulkFoodCandidate] {
        let normalizedQuery = BulkFoodText.normalizedKey(query)
        let queryTokens = BulkFoodText.tokens(query)
        let sorted = candidates
            .filter { $0.match.isValid && $0.match.servingUnit == unit }
            .sorted { lhs, rhs in
                compare(
                    lhs,
                    rhs,
                    normalizedQuery: normalizedQuery,
                    queryTokens: queryTokens
                )
            }
        var seen = Set<BulkFoodIdentity>()
        return sorted.filter { seen.insert($0.match.identity).inserted }
    }

    static func automaticSelection(
        query: String,
        unit: NutritionUnit,
        candidates: [BulkFoodCandidate]
    ) -> BulkFoodMatch? {
        let rankedCandidates = ranked(query: query, unit: unit, candidates: candidates)
        let normalized = BulkFoodText.normalizedKey(query)
        if let remembered = rankedCandidates.first(where: {
            $0.match.source == .remembered
        }) {
            return remembered.match
        }
        let exactSaved = rankedCandidates.filter {
            $0.match.source == .saved
                && BulkFoodText.normalizedKey($0.match.displayName) == normalized
        }
        return exactSaved.count == 1 ? exactSaved[0].match : nil
    }

    private static func compare(
        _ lhs: BulkFoodCandidate,
        _ rhs: BulkFoodCandidate,
        normalizedQuery: String,
        queryTokens: [String]
    ) -> Bool {
        let left = rank(lhs, normalizedQuery: normalizedQuery, queryTokens: queryTokens)
        let right = rank(rhs, normalizedQuery: normalizedQuery, queryTokens: queryTokens)
        if left.rememberedExact != right.rememberedExact { return left.rememberedExact }
        if left.nameExact != right.nameExact { return left.nameExact }
        if left.allTokens != right.allTokens { return left.allTokens }
        if left.prefixCoverage != right.prefixCoverage { return left.prefixCoverage > right.prefixCoverage }
        if left.useCount != right.useCount { return left.useCount > right.useCount }
        if left.lastUsedAt != right.lastUsedAt { return left.lastUsedAt > right.lastUsedAt }
        if left.sourcePriority != right.sourcePriority { return left.sourcePriority < right.sourcePriority }
        let leftName = BulkFoodText.normalizedKey(lhs.match.displayName)
        let rightName = BulkFoodText.normalizedKey(rhs.match.displayName)
        if leftName != rightName { return leftName < rightName }
        return stableIdentity(lhs.match.identity) < stableIdentity(rhs.match.identity)
    }

    private static func rank(
        _ candidate: BulkFoodCandidate,
        normalizedQuery: String,
        queryTokens: [String]
    ) -> (
        rememberedExact: Bool,
        nameExact: Bool,
        allTokens: Bool,
        prefixCoverage: Int,
        useCount: Int,
        lastUsedAt: Date,
        sourcePriority: Int
    ) {
        let name = BulkFoodText.normalizedKey(candidate.match.displayName)
        let nameTokens = BulkFoodText.tokens(candidate.match.displayName)
        let exact = name == normalizedQuery
        let allTokens = !queryTokens.isEmpty && queryTokens.allSatisfy { nameTokens.contains($0) }
        let prefixCoverage = queryTokens.reduce(into: 0) { count, token in
            if nameTokens.contains(where: { $0.hasPrefix(token) || token.hasPrefix($0) }) {
                count += 1
            }
        }
        return (
            candidate.match.source == .remembered && exact,
            exact,
            allTokens,
            prefixCoverage,
            candidate.priorUseCount,
            candidate.lastUsedAt ?? .distantPast,
            sourcePriority(candidate.match.source)
        )
    }

    private static func sourcePriority(_ source: BulkFoodMatchSource) -> Int {
        switch source {
        case .remembered: 0
        case .saved, .custom: 1
        case .cache: 2
        case .openFoodFacts: 3
        }
    }

    private static func stableIdentity(_ identity: BulkFoodIdentity) -> String {
        switch identity {
        case .barcode(let barcode): "barcode:\(barcode)"
        case .savedFood(let id): "saved:\(id.uuidString)"
        }
    }
}

nonisolated enum BulkAmountKnowledge: String, Codable, Equatable, Sendable {
    case explicitDescription
    case userEdited
    case acceptedEstimate
}

nonisolated struct BulkFoodLearningRecord: Codable, Equatable, Identifiable, Sendable {
    static let schemaVersion = 1

    let id: UUID
    let schemaVersion: Int
    let normalizedKey: String
    var confirmedQuery: String
    var amount: Double
    var unit: NutritionUnit
    var amountKnowledge: BulkAmountKnowledge
    var selectedIdentity: BulkFoodIdentity
    var selectionSnapshot: BulkFoodMatch
    var useCount: Int
    var createdAt: Date
    var lastUsedAt: Date
    var lastConfirmedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = Self.schemaVersion,
        normalizedKey: String,
        confirmedQuery: String,
        amount: Double,
        unit: NutritionUnit,
        amountKnowledge: BulkAmountKnowledge,
        selectedIdentity: BulkFoodIdentity,
        selectionSnapshot: BulkFoodMatch,
        useCount: Int = 1,
        createdAt: Date,
        lastUsedAt: Date,
        lastConfirmedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.normalizedKey = normalizedKey
        self.confirmedQuery = confirmedQuery
        self.amount = amount
        self.unit = unit
        self.amountKnowledge = amountKnowledge
        self.selectedIdentity = selectedIdentity
        self.selectionSnapshot = selectionSnapshot
        self.useCount = useCount
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.lastConfirmedAt = lastConfirmedAt
    }
}

actor BulkFoodLearningStore {
    private struct Envelope: Codable {
        let schemaVersion: Int
        var records: [BulkFoodLearningRecord]
    }

    static let schemaVersion = 1

    private let fileURL: URL
    private let maximumRecords: Int
    private let maximumBytes: Int
    private let now: @Sendable () -> Date
    private let removeItem: @Sendable (URL) throws -> Void
    private var records: [UUID: BulkFoodLearningRecord]
    private var generation: UInt64 = 0

    init(
        fileURL: URL,
        maximumRecords: Int = BulkFoodLimits.maximumLearningRecords,
        maximumBytes: Int = BulkFoodLimits.maximumLearningBytes,
        now: @escaping @Sendable () -> Date = { .now },
        removeItem: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) throws {
        self.fileURL = fileURL
        self.maximumRecords = max(1, maximumRecords)
        self.maximumBytes = max(1, maximumBytes)
        self.now = now
        self.removeItem = removeItem
        do {
            records = try Self.load(from: fileURL)
        } catch {
            records = [:]
            try? FileManager.default.removeItem(at: fileURL)
        }
        records = records.filter { Self.isValid($0.value) }
    }

    static func applicationStore() async throws -> BulkFoodLearningStore {
        try await BulkFoodApplicationStoreOwner.shared.learningStore()
    }

    fileprivate static func applicationFileURL() throws -> URL {
        try applicationDirectory().appending(path: "learned-food-choices.json")
    }

    func acquireLease() -> BulkFoodLearningLease {
        BulkFoodLearningLease(generation: generation)
    }

    func record(
        for source: String,
        unit: NutritionUnit? = nil,
        touch: Bool = false
    ) -> BulkFoodLearningRecord? {
        let key = BulkFoodText.normalizedKey(source)
        guard !key.isEmpty else { return nil }
        let candidates = records.values.filter {
            $0.normalizedKey == key && (unit == nil || $0.unit == unit)
        }
        guard var match = candidates.max(by: Self.recencyOrder) else { return nil }
        guard touch else { return match }
        match.lastUsedAt = now()
        if match.useCount < Int.max {
            match.useCount += 1
        }
        records[match.id] = match
        return match
    }

    func flushRecency(lease: BulkFoodLearningLease) throws {
        try validate(lease)
        try evictAndPersist()
    }

    @discardableResult
    func confirm(
        source: String,
        confirmedQuery: String,
        amount: Double,
        unit: NutritionUnit,
        amountKnowledge: BulkAmountKnowledge,
        selection: BulkFoodMatch,
        lease: BulkFoodLearningLease
    ) throws -> BulkFoodLearningRecord {
        try validate(lease)
        let key = BulkFoodText.normalizedKey(source)
        let query = try BulkFoodValidator.validateQuery(confirmedQuery)
        let validatedAmount = try BulkFoodValidator.validateAmount(amount)
        guard !key.isEmpty,
              key.count <= BulkFoodLimits.maximumQueryCharacters,
              selection.isValid,
              selection.servingUnit == unit else {
            throw BulkFoodValidationError.emptyQuery
        }
        let date = now()
        let existing = records.values
            .filter { $0.normalizedKey == key && $0.unit == unit }
            .max(by: Self.recencyOrder)
        let record = BulkFoodLearningRecord(
            id: existing?.id ?? UUID(),
            normalizedKey: key,
            confirmedQuery: query,
            amount: validatedAmount,
            unit: unit,
            amountKnowledge: amountKnowledge,
            selectedIdentity: selection.identity,
            selectionSnapshot: selection,
            useCount: min(Int.max, (existing?.useCount ?? 0) + 1),
            createdAt: existing?.createdAt ?? date,
            lastUsedAt: date,
            lastConfirmedAt: date
        )
        let previousRecords = records
        records[record.id] = record
        do {
            try evictAndPersist()
            return record
        } catch {
            records = previousRecords
            throw error
        }
    }

    func count() -> Int { records.count }

    func allRecords() -> [BulkFoodLearningRecord] {
        records.values.sorted { lhs, rhs in
            if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt > rhs.lastUsedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func clear() throws {
        let previousRecords = records
        records = [:]
        do {
            if FileManager.default.fileExists(atPath: fileURL.path()) {
                try removeItem(fileURL)
                guard !FileManager.default.fileExists(atPath: fileURL.path()) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            generation &+= 1
        } catch {
            records = previousRecords
            throw error
        }
    }

    private func validate(_ lease: BulkFoodLearningLease) throws {
        guard lease.generation == generation else { throw BulkFoodPersistenceError.staleLease }
    }

    private static func applicationDirectory() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "BulkFoodLogging", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
        return directory
    }

    private static func load(from fileURL: URL) throws -> [UUID: BulkFoodLearningRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return [:] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: fileURL))
        guard envelope.schemaVersion == schemaVersion else {
            throw BulkFoodValidationError.unsupportedSchema(envelope.schemaVersion)
        }
        return Dictionary(envelope.records.map { ($0.id, $0) }, uniquingKeysWith: { lhs, rhs in
            recencyOrder(lhs, rhs) ? rhs : lhs
        })
    }

    private static func isValid(_ record: BulkFoodLearningRecord) -> Bool {
        record.schemaVersion == BulkFoodLearningRecord.schemaVersion
            && !record.normalizedKey.isEmpty
            && record.normalizedKey.count <= BulkFoodLimits.maximumQueryCharacters
            && (try? BulkFoodValidator.validateQuery(record.confirmedQuery)) != nil
            && (try? BulkFoodValidator.validateAmount(record.amount)) != nil
            && record.selectedIdentity == record.selectionSnapshot.identity
            && record.selectionSnapshot.isValid
            && record.selectionSnapshot.servingUnit == record.unit
            && record.useCount >= 0
            && record.createdAt.timeIntervalSinceReferenceDate.isFinite
            && record.lastUsedAt.timeIntervalSinceReferenceDate.isFinite
            && record.lastConfirmedAt.timeIntervalSinceReferenceDate.isFinite
    }

    private static func recencyOrder(_ lhs: BulkFoodLearningRecord, _ rhs: BulkFoodLearningRecord) -> Bool {
        if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt < rhs.lastUsedAt }
        if lhs.lastConfirmedAt != rhs.lastConfirmedAt { return lhs.lastConfirmedAt < rhs.lastConfirmedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func evictAndPersist() throws {
        while records.count > maximumRecords || encodedSize() > maximumBytes {
            guard let oldest = records.values.min(by: Self.recencyOrder) else { break }
            records.removeValue(forKey: oldest.id)
        }
        try persist()
    }

    private func encodedSize() -> Int {
        (try? encodedData().count) ?? .max
    }

    private func encodedData() throws -> Data {
        let sorted = records.values.sorted { $0.id.uuidString < $1.id.uuidString }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: Self.schemaVersion, records: sorted))
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encodedData().write(to: fileURL, options: .atomic)
#if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path()
        )
#endif
    }
}

nonisolated struct BulkFoodReviewItemSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let sourceQuery: String
    var query: String
    var amount: Double
    var unit: NutritionUnit
    var amountOrigin: BulkAmountOrigin
    var selectedMatch: BulkFoodMatch?
}

nonisolated struct BulkFoodDraft: Codable, Equatable, Identifiable, Sendable {
    static let schemaVersion = 1

    let id: UUID
    let schemaVersion: Int
    var description: String
    var mealType: String
    var reviewItems: [BulkFoodReviewItemSnapshot]
    var operationID: UUID
    var commitDate: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = Self.schemaVersion,
        description: String,
        mealType: String,
        reviewItems: [BulkFoodReviewItemSnapshot],
        operationID: UUID = UUID(),
        commitDate: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.description = description
        self.mealType = mealType
        self.reviewItems = reviewItems
        self.operationID = operationID
        self.commitDate = commitDate
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, description, mealType, reviewItems, operationID, commitDate, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        description = try container.decode(String.self, forKey: .description)
        mealType = try container.decode(String.self, forKey: .mealType)
        reviewItems = try container.decode([BulkFoodReviewItemSnapshot].self, forKey: .reviewItems)
        operationID = try container.decodeIfPresent(UUID.self, forKey: .operationID) ?? UUID()
        commitDate = try container.decodeIfPresent(Date.self, forKey: .commitDate)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

nonisolated struct BulkFoodLearningLease: Sendable {
    fileprivate let generation: UInt64
}

nonisolated struct BulkFoodDraftLease: Sendable {
    fileprivate let generation: UInt64
}

nonisolated struct BulkFoodPersistenceSession: Sendable {
    let learningStore: BulkFoodLearningStore
    let learningLease: BulkFoodLearningLease
    let draftStore: BulkFoodDraftStore
    let draftLease: BulkFoodDraftLease

    static func applicationSession() async throws -> Self {
        try await BulkFoodApplicationStoreOwner.shared.session()
    }
}

actor BulkFoodDraftStore {
    private let fileURL: URL
    private let now: @Sendable () -> Date
    private let removeItem: @Sendable (URL) throws -> Void
    private var generation: UInt64 = 0

    init(
        fileURL: URL,
        now: @escaping @Sendable () -> Date = { .now },
        removeItem: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
    ) {
        self.fileURL = fileURL
        self.now = now
        self.removeItem = removeItem
    }

    static func applicationStore() async throws -> BulkFoodDraftStore {
        try await BulkFoodApplicationStoreOwner.shared.draftStore()
    }

    fileprivate static func applicationFileURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "BulkFoodLogging", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(values)
        return directory.appending(path: "meal-draft.json")
    }

    func acquireLease() -> BulkFoodDraftLease {
        BulkFoodDraftLease(generation: generation)
    }

    func load() -> BulkFoodDraft? {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return nil }
        do {
            let draft = try JSONDecoder().decode(BulkFoodDraft.self, from: Data(contentsOf: fileURL))
            let age = now().timeIntervalSince(draft.updatedAt)
            guard Self.isValid(draft), age >= 0, age <= BulkFoodLimits.draftLifetime else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return draft
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }


    func save(_ draft: BulkFoodDraft, lease: BulkFoodDraftLease) throws {
        try validate(lease)
        guard Self.isValid(draft),
              draft.updatedAt <= now() else { throw BulkFoodValidationError.invalidItemCount }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(draft).write(to: fileURL, options: .atomic)
#if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path()
        )
#endif
    }

    func hasDraft() -> Bool { load() != nil }

    func clear(lease: BulkFoodDraftLease) throws {
        try validate(lease)
        if FileManager.default.fileExists(atPath: fileURL.path()) {
            try removeItem(fileURL)
            guard !FileManager.default.fileExists(atPath: fileURL.path()) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        generation &+= 1
    }

    func clearIfMatching(_ draftID: UUID) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        let draft = try JSONDecoder().decode(BulkFoodDraft.self, from: Data(contentsOf: fileURL))
        guard draft.id == draftID else { return }
        try removeItem(fileURL)
        guard !FileManager.default.fileExists(atPath: fileURL.path()) else {
            throw CocoaError(.fileWriteUnknown)
        }
        generation &+= 1
    }

    private func validate(_ lease: BulkFoodDraftLease) throws {
        guard lease.generation == generation else { throw BulkFoodPersistenceError.staleLease }
    }

    private static func isValid(_ draft: BulkFoodDraft) -> Bool {
        guard draft.schemaVersion == BulkFoodDraft.schemaVersion,
              draft.operationID.uuidString != "00000000-0000-0000-0000-000000000000",
              draft.description.count <= BulkFoodLimits.maximumDescriptionCharacters,
              draft.reviewItems.count <= BulkFoodLimits.maximumItems,
              draft.commitDate?.timeIntervalSinceReferenceDate.isFinite ?? true,
              draft.updatedAt.timeIntervalSinceReferenceDate.isFinite else { return false }
        return Set(draft.reviewItems.map(\.id)).count == draft.reviewItems.count
            && draft.reviewItems.allSatisfy {
                let queryIsValid = $0.query.isEmpty
                    || (try? BulkFoodValidator.validateQuery($0.query)) != nil
                let sourceIsValid = $0.sourceQuery.isEmpty
                    || (try? BulkFoodValidator.validateQuery($0.sourceQuery)) != nil
                return queryIsValid
                    && sourceIsValid
                    && (try? BulkFoodValidator.validateAmount($0.amount)) != nil
                    && ($0.selectedMatch?.isValid ?? true)
                    && ($0.selectedMatch?.servingUnit == $0.unit || $0.selectedMatch == nil)
            }
    }
}

actor BulkFoodApplicationStoreOwner {
    static let shared = BulkFoodApplicationStoreOwner()

    private let learningFileURL: URL?
    private let draftFileURL: URL?
    private var cachedLearningStore: BulkFoodLearningStore?
    private var cachedDraftStore: BulkFoodDraftStore?

    init(learningFileURL: URL? = nil, draftFileURL: URL? = nil) {
        self.learningFileURL = learningFileURL
        self.draftFileURL = draftFileURL
    }

    func learningStore() throws -> BulkFoodLearningStore {
        if let cachedLearningStore { return cachedLearningStore }
        let store = try BulkFoodLearningStore(
            fileURL: learningFileURL ?? BulkFoodLearningStore.applicationFileURL()
        )
        cachedLearningStore = store
        return store
    }

    func draftStore() throws -> BulkFoodDraftStore {
        if let cachedDraftStore { return cachedDraftStore }
        let fileURL: URL
        if let draftFileURL {
            fileURL = draftFileURL
        } else {
            fileURL = try BulkFoodDraftStore.applicationFileURL()
        }
        let store = BulkFoodDraftStore(fileURL: fileURL)
        cachedDraftStore = store
        return store
    }

    func session() async throws -> BulkFoodPersistenceSession {
        let learningStore = try learningStore()
        let draftStore = try draftStore()
        return await BulkFoodPersistenceSession(
            learningStore: learningStore,
            learningLease: learningStore.acquireLease(),
            draftStore: draftStore,
            draftLease: draftStore.acquireLease()
        )
    }
}

nonisolated struct BulkPlateInsert: Codable, Equatable, Identifiable, Sendable {
    static func stableID(operationID: UUID, sourceItemID: UUID) -> UUID {
        var bytes = Array(operationID.uuidBytes)
        for (index, byte) in sourceItemID.uuidBytes.enumerated() {
            bytes[index] ^= byte
        }
        // Keep RFC 4122 variant/version bits stable while deriving deterministic identity.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    let id: UUID
    let sourceItemID: UUID
    let match: BulkFoodMatch
    let amount: Double
    let unit: NutritionUnit
    let mealType: String
    let date: Date

    init(
        id: UUID = UUID(),
        sourceItemID: UUID,
        match: BulkFoodMatch,
        amount: Double,
        unit: NutritionUnit,
        mealType: String,
        date: Date
    ) {
        self.id = id
        self.sourceItemID = sourceItemID
        self.match = match
        self.amount = amount
        self.unit = unit
        self.mealType = mealType
        self.date = date
    }
}

nonisolated private extension UUID {
    var uuidBytes: [UInt8] {
        withUnsafeBytes(of: uuid) { Array($0) }
    }
}
