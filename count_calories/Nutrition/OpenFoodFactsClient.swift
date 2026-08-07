import Foundation
import os

protocol FoodNutritionFetching: Sendable {
    func fetchNutrition(for barcode: String) async throws -> FoodNutrition?
}

enum FoodNutritionFetchError: LocalizedError, Equatable {
    case invalidBarcode
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "The barcode must contain between 8 and 14 digits."
        case .invalidResponse:
            return "The food database returned an invalid response."
        case let .serverError(statusCode):
            return "The food database returned HTTP status \(statusCode)."
        }
    }
}

struct OpenFoodFactsClient: FoodNutritionFetching {
    private static let logger = Logger(subsystem: "ch.elia.count-calories", category: "nutrition.lookup")
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org/api/v2/product")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchNutrition(for barcode: String) async throws -> FoodNutrition? {
        let normalizedBarcode = barcode.filter(\.isNumber)
        guard (8...14).contains(normalizedBarcode.count) else {
            Self.logger.error("Rejected invalid barcode with length \(normalizedBarcode.count, privacy: .public)")
            throw FoodNutritionFetchError.invalidBarcode
        }

        var components = URLComponents(url: baseURL.appending(path: normalizedBarcode), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "code,product_name,brands,quantity,product_quantity,product_quantity_unit,serving_size,serving_quantity,serving_quantity_unit,categories_tags,nutrition_data_per,nutriments"
            )
        ]
        guard let url = components.url else { throw FoodNutritionFetchError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("CountCalories/1.0 (iOS nutrition tracker)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.logger.error("Food lookup transport failed for barcode length \(normalizedBarcode.count, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
        guard let response = response as? HTTPURLResponse else {
            throw FoodNutritionFetchError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            Self.logger.error("Food lookup failed with HTTP status \(response.statusCode, privacy: .public)")
            throw FoodNutritionFetchError.serverError(response.statusCode)
        }

        let productResponse: ProductResponse
        do {
            productResponse = try JSONDecoder().decode(ProductResponse.self, from: data)
        } catch {
            Self.logger.error("Food lookup decoding failed for barcode length \(normalizedBarcode.count, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
        guard productResponse.status == 1, let product = productResponse.product else {
            Self.logger.notice("Food lookup did not find a product for barcode length \(normalizedBarcode.count, privacy: .public)")
            return nil
        }

        let nutrition = product.nutrition(barcode: normalizedBarcode)
        if nutrition == nil {
            Self.logger.error("Food lookup returned incomplete nutrition for barcode length \(normalizedBarcode.count, privacy: .public)")
        } else {
            Self.logger.info("Food lookup succeeded for barcode length \(normalizedBarcode.count, privacy: .public)")
        }
        return nutrition
    }
}

private struct ProductResponse: Decodable {
    let status: Int
    let product: Product?
}

private struct Product: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let quantity: String?
    let productQuantity: FlexibleDouble?
    let productQuantityUnit: String?
    let servingSize: String?
    let servingQuantity: FlexibleDouble?
    let servingQuantityUnit: String?
    let categoriesTags: [String]?
    let nutritionDataPer: String?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case quantity
        case productQuantity = "product_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
        case categoriesTags = "categories_tags"
        case nutritionDataPer = "nutrition_data_per"
        case nutriments
    }

    func nutrition(barcode: String) -> FoodNutrition? {
        guard let name = productName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let amount = normalizedServingAmount
        return FoodNutrition(
            barcode: code?.filter(\.isNumber).isEmpty == false ? code!.filter(\.isNumber) : barcode,
            name: name,
            brand: brands?.nilIfBlank,
            quantityDescription: quantity?.nilIfBlank,
            servingGrams: amount?.value,
            servingUnit: amount?.unit ?? inferredServingUnit,
            caloriesPer100Grams: nutriments?.energyKcal?.value,
            proteinGramsPer100Grams: nutriments?.proteins?.value,
            carbohydrateGramsPer100Grams: nutriments?.carbohydrates?.value,
            fatGramsPer100Grams: nutriments?.fat?.value,
            fiberGramsPer100Grams: nutriments?.fiber?.value,
            sugarGramsPer100Grams: nutriments?.sugars?.value,
            saltGramsPer100Grams: nutriments?.salt?.value
        )
    }

    private var normalizedServingAmount: NutritionAmount? {
        let servingSizeAmount = NutritionAmount.parse(servingSize)
        let quantityAmount = NutritionAmount.parse(quantity)
        let inferredUnit = servingSizeAmount?.unit
            ?? unit(from: servingQuantityUnit)
            ?? unit(from: productQuantityUnit)
            ?? quantityAmount?.unit
            ?? inferredServingUnit

        return NutritionAmount(value: servingQuantity?.value, unitDescription: servingQuantityUnit)
            ?? servingSizeAmount
            ?? NutritionAmount(value: servingQuantity?.value, unit: inferredUnit)
            ?? NutritionAmount(value: productQuantity?.value, unitDescription: productQuantityUnit)
            ?? quantityAmount
    }

    private var inferredServingUnit: NutritionUnit {
        if let unit = unit(from: servingQuantityUnit)
            ?? NutritionAmount.parse(servingSize)?.unit
            ?? unit(from: productQuantityUnit)
            ?? NutritionAmount.parse(quantity)?.unit
            ?? NutritionAmount.parse(nutritionDataPer)?.unit {
            return unit
        }

        let isBeverage = categoriesTags?.contains("en:beverages") == true
        return isBeverage ? .milliliters : .grams
    }

    private func unit(from description: String?) -> NutritionUnit? {
        NutritionAmount(value: 1, unitDescription: description)?.unit
    }
}

private struct Nutriments: Decodable {
    let energyKcal: FlexibleDouble?
    let proteins: FlexibleDouble?
    let carbohydrates: FlexibleDouble?
    let fat: FlexibleDouble?
    let fiber: FlexibleDouble?
    let sugars: FlexibleDouble?
    let salt: FlexibleDouble?

    enum CodingKeys: String, CodingKey {
        case energyKcal = "energy-kcal_100g"
        case proteins = "proteins_100g"
        case carbohydrates = "carbohydrates_100g"
        case fat = "fat_100g"
        case fiber = "fiber_100g"
        case sugars = "sugars_100g"
        case salt = "salt_100g"
    }
}

private struct FlexibleDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let string = try? container.decode(String.self), let value = Double(string) {
            self.value = value
        } else {
            throw DecodingError.typeMismatch(Double.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected a number."))
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
