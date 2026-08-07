import Foundation

struct OpenFoodFactsV3Client: FoodNutritionFetching {
    private static let requestedFields = [
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
        "nutrition"
    ].joined(separator: ",")

    private let transport: OpenFoodFactsHTTPClient
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org/api/v3.6/product")!,
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
        let url = try openFoodFactsProductURL(
            baseURL: baseURL,
            barcode: normalizedBarcode,
            fields: Self.requestedFields
        )
        guard let data = try await transport.data(
            from: url,
            barcodeLength: normalizedBarcode.count
        ) else {
            return .notFound
        }

        let response = try JSONDecoder().decode(V3ProductResponse.self, from: data)
        guard let product = response.product else { return .notFound }
        return product.result(requestedBarcode: normalizedBarcode)
    }
}

private struct V3ProductResponse: Decodable {
    let product: V3Product?
}

private struct V3Product: Decodable {
    let metadata: OpenFoodFactsProductMetadata
    let nutrition: V3NutritionData

    init(from decoder: Decoder) throws {
        metadata = try OpenFoodFactsProductMetadata(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nutrition = try container.decodeIfPresent(V3NutritionData.self, forKey: .nutrition) ?? .empty
    }

    nonisolated func result(requestedBarcode: String) -> FoodNutritionFetchResult {
        metadata.result(
            requestedBarcode: requestedBarcode,
            caloriesPer100: nutrition.caloriesPer100,
            structuredServing: nutrition.servingAmount,
            referenceUnit: nutrition.referenceUnit
        )
    }

    private enum CodingKeys: String, CodingKey {
        case nutrition
    }
}

private struct V3NutritionData: Decodable {
    static let empty = V3NutritionData(aggregatedSet: .empty, inputSets: [])

    let aggregatedSet: V3NutrientSet
    let inputSets: [V3NutrientSet]

    nonisolated var caloriesPer100: Double? {
        if
            let aggregateCalories = aggregatedSet.calories,
            aggregatedSet.basis == "100g" || aggregatedSet.basis == "100ml"
        {
            return aggregateCalories
        }

        for set in inputSets where set.preparation != "prepared" {
            guard let calories = set.calories else { continue }
            switch set.basis {
            case "100g", "100ml":
                return calories
            case "serving":
                guard let amount = NutritionAmount.normalized(
                    value: set.perQuantity,
                    unitDescription: set.perUnit
                ) else {
                    continue
                }
                return calories * 100 / amount.value
            default:
                continue
            }
        }
        return nil
    }

    nonisolated var referenceUnit: NutritionUnit? {
        let basis = aggregatedSet.basis.isEmpty
            ? inputSets.first(where: { $0.basis == "100ml" || $0.basis == "100g" })?.basis
            : aggregatedSet.basis
        switch basis {
        case "100ml": return .milliliters
        case "100g": return .grams
        default: return nil
        }
    }

    nonisolated var servingAmount: NutritionAmount? {
        for set in inputSets where set.basis == "serving" && set.preparation != "prepared" {
            if let amount = NutritionAmount.normalized(
                value: set.perQuantity,
                unitDescription: set.perUnit
            ) {
                return amount
            }
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        aggregatedSet = try container.decodeIfPresent(V3NutrientSet.self, forKey: .aggregatedSet) ?? .empty
        inputSets = try container.decodeIfPresent([V3NutrientSet].self, forKey: .inputSets) ?? []
    }

    private init(aggregatedSet: V3NutrientSet, inputSets: [V3NutrientSet]) {
        self.aggregatedSet = aggregatedSet
        self.inputSets = inputSets
    }

    private enum CodingKeys: String, CodingKey {
        case aggregatedSet = "aggregated_set"
        case inputSets = "input_sets"
    }
}

private struct V3NutrientSet: Decodable {
    static let empty = V3NutrientSet(
        calories: nil,
        basis: "",
        perQuantity: 0,
        perUnit: "",
        preparation: ""
    )

    let calories: Double?
    let basis: String
    let perQuantity: Double
    let perUnit: String
    let preparation: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if
            let nutrients = try? container.nestedContainer(
                keyedBy: NutrientCodingKeys.self,
                forKey: .nutrients
            ),
            let calorieValue = try? nutrients.nestedContainer(
                keyedBy: NutrientValueCodingKeys.self,
                forKey: .energyKcal
            )
        {
            calories = calorieValue.decodeFlexibleDoubleIfPresent(forKey: .value)
                ?? calorieValue.decodeFlexibleDoubleIfPresent(forKey: .computedValue)
        } else {
            calories = nil
        }
        basis = container.decodeLossyString(forKey: .basis)
        perQuantity = container.decodeFlexibleDoubleIfPresent(forKey: .perQuantity) ?? 0
        perUnit = container.decodeLossyString(forKey: .perUnit)
        preparation = container.decodeLossyString(forKey: .preparation)
    }

    private init(
        calories: Double?,
        basis: String,
        perQuantity: Double,
        perUnit: String,
        preparation: String
    ) {
        self.calories = calories
        self.basis = basis
        self.perQuantity = perQuantity
        self.perUnit = perUnit
        self.preparation = preparation
    }

    private enum CodingKeys: String, CodingKey {
        case nutrients
        case basis = "per"
        case perQuantity = "per_quantity"
        case perUnit = "per_unit"
        case preparation
    }

    private enum NutrientCodingKeys: String, CodingKey {
        case energyKcal = "energy-kcal"
    }

    private enum NutrientValueCodingKeys: String, CodingKey {
        case value
        case computedValue = "value_computed"
    }
}
