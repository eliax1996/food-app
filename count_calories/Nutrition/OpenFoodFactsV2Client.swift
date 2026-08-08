import Foundation

struct OpenFoodFactsV2Client: FoodNutritionFetching {
    private static let requestedFields = [
        "code", "product_name", "quantity", "product_quantity", "product_quantity_unit",
        "serving_size", "serving_quantity", "serving_quantity_unit", "categories_tags",
        "nutrition_data_per", "nutriments"
    ].joined(separator: ",")

    private let transport: OpenFoodFactsHTTPClient
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org/api/v2/product")!,
        requestTimeout: TimeInterval = OpenFoodFactsClient.defaultRequestTimeout
    ) {
        transport = OpenFoodFactsHTTPClient(session: session, timeout: requestTimeout)
        self.baseURL = baseURL
    }

    init(transport: OpenFoodFactsHTTPClient, baseURL: URL) {
        self.transport = transport
        self.baseURL = baseURL
    }

    func fetchNutrition(for barcode: String) async throws -> FoodNutritionFetchResult {
        let normalizedBarcode = try normalizedFoodBarcode(barcode)
        let url = try openFoodFactsProductURL(baseURL: baseURL, barcode: normalizedBarcode, fields: Self.requestedFields)
        guard let data = try await transport.data(from: url, barcodeLength: normalizedBarcode.count) else {
            return .notFound
        }

        let response = try JSONDecoder().decode(V2ProductResponse.self, from: data)
        guard response.status == 1 else { return .notFound }
        guard let product = response.product else { throw FoodNutritionFetchError.invalidResponse }
        return product.result(requestedBarcode: normalizedBarcode)
    }
}

private struct V2ProductResponse: Decodable {
    let status: Int
    let product: OpenFoodFactsProduct?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeFlexibleDoubleIfPresent(forKey: .status) == 1 ? 1 : 0
        product = try container.decodeIfPresent(OpenFoodFactsProduct.self, forKey: .product)
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case product
    }
}
