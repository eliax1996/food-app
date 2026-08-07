import Foundation
import os

nonisolated protocol FoodNutritionFetching: Sendable {
    func fetchNutrition(for barcode: String) async throws -> FoodNutritionFetchResult
}

enum FoodNutritionFetchResult: Equatable, Sendable {
    case found(FoodNutrition)
    case incompleteProduct
    case notFound
}

enum FoodNutritionFetchError: LocalizedError, Equatable, Sendable {
    case invalidBarcode
    case invalidResponse
    case serverError(Int)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "The barcode must contain between 8 and 14 digits."
        case .invalidResponse:
            return "The food database returned an invalid response."
        case let .serverError(statusCode):
            return "The food database returned HTTP status \(statusCode)."
        case .timedOut:
            return "The food lookup took too long."
        }
    }

    fileprivate var shouldSkipVersionFallback: Bool {
        switch self {
        case .serverError(429), .serverError(503):
            return true
        default:
            return false
        }
    }
}

struct OpenFoodFactsClient: FoodNutritionFetching {
    static let defaultFallbackDelay = Duration.milliseconds(750)
    static let defaultResponseTimeout = Duration.seconds(6)
    static let defaultRequestTimeout: TimeInterval = 6

    private static let logger = Logger(
        subsystem: "ch.elia.count-calories",
        category: "nutrition.lookup"
    )

    private let primary: any FoodNutritionFetching
    private let fallback: any FoodNutritionFetching
    private let fallbackDelay: Duration
    private let responseTimeout: Duration

    init(
        session: URLSession = .shared,
        primaryBaseURL: URL = URL(string: "https://world.openfoodfacts.org/api/v3.6/product")!,
        fallbackBaseURL: URL = URL(string: "https://world.openfoodfacts.org/api/v2/product")!,
        requestTimeout: TimeInterval = defaultRequestTimeout,
        fallbackDelay: Duration = defaultFallbackDelay,
        responseTimeout: Duration = defaultResponseTimeout
    ) {
        let transport = OpenFoodFactsHTTPClient(session: session, timeout: requestTimeout)
        primary = OpenFoodFactsV3Client(transport: transport, baseURL: primaryBaseURL)
        fallback = OpenFoodFactsV2Client(transport: transport, baseURL: fallbackBaseURL)
        self.fallbackDelay = fallbackDelay
        self.responseTimeout = responseTimeout
    }

    init(
        primary: any FoodNutritionFetching,
        fallback: any FoodNutritionFetching,
        fallbackDelay: Duration = defaultFallbackDelay,
        responseTimeout: Duration = defaultResponseTimeout
    ) {
        self.primary = primary
        self.fallback = fallback
        self.fallbackDelay = fallbackDelay
        self.responseTimeout = responseTimeout
    }

    func fetchNutrition(for barcode: String) async throws -> FoodNutritionFetchResult {
        let normalizedBarcode = try normalizedFoodBarcode(barcode)

        return try await withThrowingTaskGroup(
            of: LookupEvent.self,
            returning: FoodNutritionFetchResult.self
        ) { group in
            group.addTask {
                await Self.fetch(using: primary, source: .primaryV3, barcode: normalizedBarcode)
            }
            group.addTask {
                do {
                    try await Task.sleep(for: fallbackDelay)
                    return .fallbackDelayElapsed
                } catch {
                    return .cancelled
                }
            }
            group.addTask {
                do {
                    try await Task.sleep(for: responseTimeout)
                    return .deadline
                } catch {
                    return .cancelled
                }
            }

            var primaryCompleted = false
            var fallbackStarted = false
            var fallbackCompleted = false
            var errors: [LookupSource: any Error] = [:]
            var sawIncompleteProduct = false
            var sawNotFound = false

            while let event = try await group.next() {
                switch event {
                case let .response(source, result):
                    if source == .primaryV3 {
                        primaryCompleted = true
                    } else {
                        fallbackCompleted = true
                    }

                    var primaryNeedsFallback = false
                    switch result {
                    case let .success(.found(nutrition)):
                        group.cancelAll()
                        Self.logger.info(
                            "Nutrition lookup succeeded via \(source.logName, privacy: .public) for barcode length \(normalizedBarcode.count, privacy: .public)"
                        )
                        return .found(nutrition)
                    case .success(.incompleteProduct):
                        sawIncompleteProduct = true
                        primaryNeedsFallback = source == .primaryV3
                    case .success(.notFound):
                        sawNotFound = true
                        if source == .primaryV3 && !fallbackStarted {
                            group.cancelAll()
                            return .notFound
                        }
                    case let .failure(error):
                        errors[source] = error
                        if source == .primaryV3,
                           let fetchError = error as? FoodNutritionFetchError,
                           fetchError.shouldSkipVersionFallback,
                           !fallbackStarted {
                            group.cancelAll()
                            throw error
                        }
                        primaryNeedsFallback = source == .primaryV3
                    }

                    if primaryNeedsFallback && !fallbackStarted {
                        fallbackStarted = true
                        group.addTask {
                            await Self.fetch(
                                using: fallback,
                                source: .fallbackV2,
                                barcode: normalizedBarcode
                            )
                        }
                    }

                    if primaryCompleted && fallbackCompleted {
                        group.cancelAll()
                        if sawIncompleteProduct {
                            return .incompleteProduct
                        }
                        if sawNotFound {
                            return .notFound
                        }
                        throw errors[.primaryV3]
                            ?? errors[.fallbackV2]
                            ?? FoodNutritionFetchError.invalidResponse
                    }

                case .fallbackDelayElapsed:
                    if !primaryCompleted && !fallbackStarted {
                        fallbackStarted = true
                        group.addTask {
                            await Self.fetch(
                                using: fallback,
                                source: .fallbackV2,
                                barcode: normalizedBarcode
                            )
                        }
                    }

                case .deadline:
                    group.cancelAll()
                    if sawIncompleteProduct {
                        return .incompleteProduct
                    }
                    if sawNotFound {
                        return .notFound
                    }
                    Self.logger.notice(
                        "Nutrition lookup reached UX deadline for barcode length \(normalizedBarcode.count, privacy: .public)"
                    )
                    throw errors[.primaryV3]
                        ?? errors[.fallbackV2]
                        ?? FoodNutritionFetchError.timedOut

                case .cancelled:
                    continue
                }
            }

            try Task.checkCancellation()
            throw errors[.primaryV3]
                ?? errors[.fallbackV2]
                ?? FoodNutritionFetchError.invalidResponse
        }
    }

    private static func fetch(
        using client: any FoodNutritionFetching,
        source: LookupSource,
        barcode: String
    ) async -> LookupEvent {
        do {
            return .response(source, .success(try await client.fetchNutrition(for: barcode)))
        } catch {
            return .response(source, .failure(error))
        }
    }
}

private enum LookupSource: String, Sendable {
    case primaryV3
    case fallbackV2

    nonisolated var logName: String {
        switch self {
        case .primaryV3: "Open Food Facts v3.6"
        case .fallbackV2: "Open Food Facts v2 fallback"
        }
    }
}

private enum LookupEvent: @unchecked Sendable {
    case response(LookupSource, Result<FoodNutritionFetchResult, any Error>)
    case fallbackDelayElapsed
    case deadline
    case cancelled
}
