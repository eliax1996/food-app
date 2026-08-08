import Foundation

nonisolated protocol FoodSearchFetching: Sendable {
    func search(
        query: String,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) async throws -> FoodSearchPage
}

nonisolated struct FoodSearchQuery: Codable, Equatable, Sendable {
    let displayQuery: String
    let normalizedQuery: String

    init(_ displayQuery: String) {
        self.displayQuery = displayQuery
        normalizedQuery = Self.normalize(displayQuery)
    }

    static func normalize(_ query: String) -> String {
        query
            .precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: .caseInsensitive, locale: nil)
    }
}

nonisolated struct FoodSearchPage: Codable, Equatable, Sendable {
    let query: FoodSearchQuery
    let foods: [FoodNutrition]
    let page: Int
    let pageSize: Int
    let rawHitCount: Int

    var isTerminal: Bool { rawHitCount < pageSize }

    init(
        query: FoodSearchQuery,
        foods: [FoodNutrition],
        page: Int,
        pageSize: Int,
        rawHitCount: Int
    ) {
        self.query = query
        self.foods = foods
        self.page = page
        self.pageSize = pageSize
        self.rawHitCount = rawHitCount
    }

    private enum CodingKeys: String, CodingKey {
        case query
        case foods
        case page
        case pageSize
        case rawHitCount
    }
}

enum FoodSearchError: LocalizedError, Equatable, Sendable {
    case invalidQuery
    case invalidPage
    case invalidPageSize
    case invalidLanguages
    case invalidResponse
    case serverError(Int)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Search query cannot be empty."
        case .invalidPage:
            return "Search page must be at least 1."
        case .invalidPageSize:
            return "Search page size must be at least 1."
        case .invalidLanguages:
            return "At least one search language is required."
        case .invalidResponse:
            return "The food search returned an invalid response."
        case let .serverError(statusCode):
            return "The food search returned HTTP status \(statusCode)."
        case .timedOut:
            return "The food search timed out. Please try again."
        }
    }
}
