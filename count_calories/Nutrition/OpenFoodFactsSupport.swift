import Foundation
import os

struct OpenFoodFactsHTTPClient: Sendable {
    private static let logger = Logger(
        subsystem: "ch.elia.count-calories",
        category: "nutrition.transport"
    )
    private static let userAgent = "CountCalories/1.0 (iOS; https://github.com/eliax1996/food-app)"

    private let session: URLSession
    private let timeout: TimeInterval

    init(session: URLSession, timeout: TimeInterval) {
        self.session = session
        self.timeout = timeout
    }

    func data(from url: URL, barcodeLength: Int) async throws -> Data? {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.logger.error(
                "Food lookup transport failed for barcode length \(barcodeLength, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodNutritionFetchError.invalidResponse
        }
        if httpResponse.statusCode == 404 {
            return nil
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            Self.logger.error(
                "Food lookup failed with HTTP status \(httpResponse.statusCode, privacy: .public)"
            )
            throw FoodNutritionFetchError.serverError(httpResponse.statusCode)
        }
        return data
    }
}

struct OpenFoodFactsProductMetadata: Decodable, Sendable {
    let code: String
    let name: String
    let servingAmounts: [NutritionAmount]
    let packageAmounts: [NutritionAmount]
    let inferredUnit: NutritionUnit

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = container.decodeLossyString(forKey: .code).filter(\.isNumber)
        name = container.decodeLossyString(forKey: .productName)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let servingSize = container.decodeLossyString(forKey: .servingSize)
        let quantity = container.decodeLossyString(forKey: .quantity)
        let servingQuantity = container.decodeFlexibleDoubleIfPresent(forKey: .servingQuantity)
        let servingQuantityUnit = container.decodeLossyString(forKey: .servingQuantityUnit)
        let productQuantity = container.decodeFlexibleDoubleIfPresent(forKey: .productQuantity)
        let productQuantityUnit = container.decodeLossyString(forKey: .productQuantityUnit)
        let nutritionDataPer = container.decodeLossyString(forKey: .nutritionDataPer)
        let categories = (try? container.decode([String].self, forKey: .categoriesTags)) ?? []

        let parsedServingSize = NutritionAmount.parse(servingSize)
        let parsedQuantity = NutritionAmount.parse(quantity)
        inferredUnit = NutritionUnit.inferred(from: servingQuantityUnit)
            ?? parsedServingSize?.unit
            ?? NutritionUnit.inferred(from: productQuantityUnit)
            ?? parsedQuantity?.unit
            ?? NutritionUnit.inferred(from: nutritionDataPer)
            ?? (categories.contains("en:beverages") ? .milliliters : .grams)

        var servingAmounts: [NutritionAmount] = []
        servingAmounts.appendUnique(
            NutritionAmount.normalized(
                value: servingQuantity,
                unitDescription: servingQuantityUnit
            )
        )
        servingAmounts.appendUnique(parsedServingSize)
        servingAmounts.appendUnique(
            NutritionAmount.validated(value: servingQuantity, unit: inferredUnit)
        )
        self.servingAmounts = servingAmounts

        var packageAmounts: [NutritionAmount] = []
        packageAmounts.appendUnique(
            NutritionAmount.normalized(
                value: productQuantity,
                unitDescription: productQuantityUnit
            )
        )
        packageAmounts.appendUnique(parsedQuantity)
        self.packageAmounts = packageAmounts
    }

    nonisolated func result(
        requestedBarcode: String,
        caloriesPer100: Double?,
        structuredServing: NutritionAmount? = nil,
        referenceUnit: NutritionUnit? = nil
    ) -> FoodNutritionFetchResult {
        guard
            !name.isEmpty,
            let caloriesPer100,
            caloriesPer100.isFinite,
            caloriesPer100 >= 0
        else {
            return .incompleteProduct
        }

        let barcode = (8...14).contains(code.count) ? code : requestedBarcode
        // OFF can report beverages as `100g`; explicit liquid metadata stays stronger. `100ml` is unambiguous.
        let standardUnit = referenceUnit == .milliliters ? NutritionUnit.milliliters : inferredUnit
        let amount = structuredServing
            ?? servingAmounts.first
            ?? packageAmounts.first
            ?? NutritionAmount(value: 100, unit: standardUnit)
        return .found(FoodNutrition(
            barcode: barcode,
            name: name,
            defaultAmount: amount,
            caloriesPer100: caloriesPer100
        ))
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case quantity
        case productQuantity = "product_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
        case categoriesTags = "categories_tags"
        case nutritionDataPer = "nutrition_data_per"
    }
}

nonisolated func normalizedFoodBarcode(_ barcode: String) throws -> String {
    let normalizedBarcode = barcode.filter(\.isNumber)
    guard (8...14).contains(normalizedBarcode.count) else {
        throw FoodNutritionFetchError.invalidBarcode
    }
    return normalizedBarcode
}

nonisolated func openFoodFactsProductURL(
    baseURL: URL,
    barcode: String,
    fields: String
) throws -> URL {
    guard var components = URLComponents(
        url: baseURL.appending(path: barcode),
        resolvingAgainstBaseURL: false
    ) else {
        throw FoodNutritionFetchError.invalidResponse
    }
    components.queryItems = [URLQueryItem(name: "fields", value: fields)]
    guard let url = components.url else {
        throw FoodNutritionFetchError.invalidResponse
    }
    return url
}

extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String {
        guard contains(key), (try? decodeNil(forKey: key)) == false else { return "" }
        return (try? decode(String.self, forKey: key)) ?? ""
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        guard contains(key), (try? decodeNil(forKey: key)) == false else { return nil }
        if let value = try? decode(Double.self, forKey: key) {
            return value
        }
        if let string = try? decode(String.self, forKey: key) {
            return Double(string.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

private extension Array where Element == NutritionAmount {
    mutating func appendUnique(_ amount: NutritionAmount?) {
        guard let amount, !contains(amount) else { return }
        append(amount)
    }
}
