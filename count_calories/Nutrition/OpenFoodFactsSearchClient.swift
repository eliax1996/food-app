import Foundation

struct OpenFoodFactsSearchClient: FoodSearchFetching {
    static let requestedFields = [
        "code",
        "product_name",
        "quantity",
        "product_quantity",
        "product_quantity_unit",
        "serving_size",
        "serving_quantity",
        "serving_quantity_unit",
        "categories_tags",
        "nutrition_data_per",
        "nutrition",
        "nutriments"
    ].joined(separator: ",")

    private let transport: OpenFoodFactsHTTPClient
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://search.openfoodfacts.org/search")!,
        requestTimeout: TimeInterval = OpenFoodFactsClient.defaultRequestTimeout
    ) {
        transport = OpenFoodFactsHTTPClient(session: session, timeout: requestTimeout)
        self.baseURL = baseURL
    }

    init(transport: OpenFoodFactsHTTPClient, baseURL: URL) {
        self.transport = transport
        self.baseURL = baseURL
    }

    func search(
        query: String,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) async throws -> FoodSearchPage {
        try await search(
            query: FoodSearchQuery(query),
            page: page,
            pageSize: pageSize,
            languages: languages
        )
    }

    func search(
        query: FoodSearchQuery,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) async throws -> FoodSearchPage {
        guard !query.normalizedQuery.isEmpty else { throw FoodSearchError.invalidQuery }
        guard page >= 1 else { throw FoodSearchError.invalidPage }
        guard pageSize >= 1 else { throw FoodSearchError.invalidPageSize }
        guard !languages.isEmpty, languages.allSatisfy({ !$0.isEmpty }) else {
            throw FoodSearchError.invalidLanguages
        }

        let url = try searchURL(
            query: query.normalizedQuery,
            page: page,
            pageSize: pageSize,
            languages: languages
        )
        let data = try await transport.searchData(
            from: url,
            queryLength: query.normalizedQuery.count,
            page: page
        )

        let envelope: OpenFoodFactsSearchEnvelope
        do {
            envelope = try JSONDecoder().decode(OpenFoodFactsSearchEnvelope.self, from: data)
        } catch is DecodingError {
            throw FoodSearchError.invalidResponse
        }

        guard !envelope.timedOut else { throw FoodSearchError.timedOut }

        return FoodSearchPage(
            query: query,
            foods: envelope.hits.compactMap { $0.searchNutrition() },
            page: page,
            pageSize: pageSize,
            rawHitCount: envelope.hits.count
        )
    }

    private func searchURL(
        query: String,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw FoodSearchError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "langs", value: languages.joined(separator: ",")),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "fields", value: Self.requestedFields)
        ]
        guard let url = components.url else { throw FoodSearchError.invalidResponse }
        return url
    }
}

private struct OpenFoodFactsSearchEnvelope: Decodable {
    let hits: [OpenFoodFactsProduct]
    let timedOut: Bool

    private enum CodingKeys: String, CodingKey {
        case hits
        case timedOut = "timed_out"
    }
}
