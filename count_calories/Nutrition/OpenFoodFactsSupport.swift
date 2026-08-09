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
        var request = configuredRequest(url: url)
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

    func searchData(from url: URL, queryLength: Int, page: Int) async throws -> Data {
        let request = configuredRequest(url: url)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.logger.error(
                "Food search transport failed query length \(queryLength, privacy: .public) page \(page, privacy: .public)"
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FoodSearchError.invalidResponse
        }
        Self.logger.info(
            "Food search response query length \(queryLength, privacy: .public) page \(page, privacy: .public) status \(httpResponse.statusCode, privacy: .public)"
        )
        guard (200...299).contains(httpResponse.statusCode) else {
            throw FoodSearchError.serverError(httpResponse.statusCode)
        }
        return data
    }

    private func configuredRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        return request
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

    nonisolated func foodNutrition(
        caloriesPer100: Double?,
        nutrientsPer100: FoodNutrients = .empty,
        structuredServing: NutritionAmount? = nil,
        referenceUnit: NutritionUnit? = nil,
        requestedBarcode: String? = nil
    ) -> FoodNutrition? {
        guard
            !name.isEmpty,
            let caloriesPer100,
            caloriesPer100.isFinite,
            caloriesPer100 >= 0,
            let barcode = normalizedFoodBarcodeIfValid(code) ?? requestedBarcode
        else {
            return nil
        }

        let standardUnit = referenceUnit == .milliliters ? NutritionUnit.milliliters : inferredUnit
        let amount = structuredServing
            ?? servingAmounts.first
            ?? packageAmounts.first
            ?? NutritionAmount(value: 100, unit: standardUnit)
        return FoodNutrition(
            barcode: barcode,
            name: name,
            defaultAmount: amount,
            caloriesPer100: caloriesPer100,
            nutrientsPer100: nutrientsPer100
        )
    }

    nonisolated func result(
        requestedBarcode: String,
        caloriesPer100: Double?,
        nutrientsPer100: FoodNutrients = .empty,
        structuredServing: NutritionAmount? = nil,
        referenceUnit: NutritionUnit? = nil
    ) -> FoodNutritionFetchResult {
        guard let nutrition = foodNutrition(
            caloriesPer100: caloriesPer100,
            nutrientsPer100: nutrientsPer100,
            structuredServing: structuredServing,
            referenceUnit: referenceUnit,
            requestedBarcode: requestedBarcode
        ) else {
            return .incompleteProduct
        }
        return .found(nutrition)
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

struct OpenFoodFactsProduct: Decodable, Sendable {
    let metadata: OpenFoodFactsProductMetadata
    let structuredNutrition: V3NutritionData
    let legacyCaloriesPer100: Double?
    let legacyNutrientsPer100: FoodNutrients

    init(from decoder: Decoder) throws {
        metadata = try OpenFoodFactsProductMetadata(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        structuredNutrition = try container.decodeIfPresent(V3NutritionData.self, forKey: .nutrition) ?? .empty
        if let nutrients = try? container.nestedContainer(keyedBy: NutrientCodingKeys.self, forKey: .nutriments) {
            legacyCaloriesPer100 = nutrients.decodeFlexibleDoubleIfPresent(forKey: .energyKcalPer100)
            legacyNutrientsPer100 = FoodNutrients(
                carbohydratesGrams: nutrients.decodeFlexibleDoubleIfPresent(forKey: .carbohydratesPer100)
                    ?? nutrients.decodeFlexibleDoubleIfPresent(forKey: .totalCarbohydratesPer100),
                proteinGrams: nutrients.decodeFlexibleDoubleIfPresent(forKey: .proteinPer100),
                fatGrams: nutrients.decodeFlexibleDoubleIfPresent(forKey: .fatPer100),
                fiberGrams: nutrients.decodeFlexibleDoubleIfPresent(forKey: .fiberPer100)
            )
        } else {
            legacyCaloriesPer100 = nil
            legacyNutrientsPer100 = .empty
        }
    }

    nonisolated var nutrientsPer100: FoodNutrients {
        structuredNutrition.nutrientsPer100.mergingMissingValues(from: legacyNutrientsPer100)
    }

    nonisolated func result(requestedBarcode: String) -> FoodNutritionFetchResult {
        metadata.result(
            requestedBarcode: requestedBarcode,
            caloriesPer100: structuredNutrition.caloriesPer100 ?? legacyCaloriesPer100,
            nutrientsPer100: nutrientsPer100,
            structuredServing: structuredNutrition.servingAmount,
            referenceUnit: structuredNutrition.referenceUnit
        )
    }

    nonisolated func searchNutrition() -> FoodNutrition? {
        metadata.foodNutrition(
            caloriesPer100: structuredNutrition.caloriesPer100 ?? legacyCaloriesPer100,
            nutrientsPer100: nutrientsPer100,
            structuredServing: structuredNutrition.servingAmount,
            referenceUnit: structuredNutrition.referenceUnit
        )
    }

    private enum CodingKeys: String, CodingKey {
        case nutrition
        case nutriments
    }

    private enum NutrientCodingKeys: String, CodingKey {
        case energyKcalPer100 = "energy-kcal_100g"
        case carbohydratesPer100 = "carbohydrates_100g"
        case totalCarbohydratesPer100 = "carbohydrates-total_100g"
        case proteinPer100 = "proteins_100g"
        case fatPer100 = "fat_100g"
        case fiberPer100 = "fiber_100g"
    }
}

struct V3NutritionData: Decodable, Sendable {
    static let empty = V3NutritionData(aggregatedSet: .empty, inputSets: [])

    let aggregatedSet: V3NutrientSet
    let inputSets: [V3NutrientSet]

    nonisolated var caloriesPer100: Double? {
        if let calories = aggregatedSet.normalizedCaloriesPer100 {
            return calories
        }
        return inputSets.lazy
            .filter { !$0.isPrepared }
            .compactMap(\.normalizedCaloriesPer100)
            .first
    }

    nonisolated var nutrientsPer100: FoodNutrients {
        let aggregateNutrients = aggregatedSet.normalizedNutrientsPer100
        if !aggregateNutrients.isEmpty {
            return aggregateNutrients
        }
        return inputSets.lazy
            .filter { !$0.isPrepared }
            .map(\.normalizedNutrientsPer100)
            .first(where: { !$0.isEmpty })
            ?? .empty
    }

    nonisolated var referenceUnit: NutritionUnit? {
        let basis = [aggregatedSet] + inputSets
        for set in basis where !set.isPrepared {
            switch set.basis {
            case "100ml": return .milliliters
            case "100g": return .grams
            default: continue
            }
        }
        return nil
    }

    nonisolated var servingAmount: NutritionAmount? {
        for set in inputSets where set.basis == "serving" && !set.isPrepared {
            if let amount = NutritionAmount.normalized(value: set.perQuantity, unitDescription: set.perUnit) {
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

struct V3NutrientSet: Decodable, Sendable {
    static let empty = V3NutrientSet(
        calories: nil,
        nutrients: .empty,
        basis: "",
        perQuantity: 0,
        perUnit: "",
        preparation: ""
    )

    let calories: Double?
    let nutrients: FoodNutrients
    let basis: String
    let perQuantity: Double
    let perUnit: String
    let preparation: String

    nonisolated var isPrepared: Bool {
        preparation == "prepared" || preparation == "as_prepared"
    }

    nonisolated var normalizedCaloriesPer100: Double? {
        guard let calories, calories.isFinite, calories >= 0, let multiplier = per100Multiplier else {
            return nil
        }
        let normalized = calories * multiplier
        return normalized.isFinite ? normalized : nil
    }

    nonisolated var normalizedNutrientsPer100: FoodNutrients {
        guard let multiplier = per100Multiplier else { return .empty }
        return nutrients.scaled(by: multiplier)
    }

    nonisolated private var per100Multiplier: Double? {
        switch basis {
        case "100g", "100ml":
            return 1
        case "serving":
            guard let amount = NutritionAmount.normalized(
                value: perQuantity,
                unitDescription: perUnit
            ) else { return nil }
            return 100 / amount.value
        default:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nutrientContainer = try? container.nestedContainer(
            keyedBy: NutrientCodingKeys.self,
            forKey: .nutrients
        )

        func value(for key: NutrientCodingKeys) -> V3NutrientValue? {
            guard let nutrientContainer else { return nil }
            return try? nutrientContainer.decode(V3NutrientValue.self, forKey: key)
        }

        let carbohydrateValue = value(for: .carbohydrates)
            ?? value(for: .totalCarbohydrates)
        calories = value(for: .energyKcal)?.value
        nutrients = FoodNutrients(
            carbohydratesGrams: Self.grams(from: carbohydrateValue),
            proteinGrams: Self.grams(from: value(for: .proteins)),
            fatGrams: Self.grams(from: value(for: .fat)),
            fiberGrams: Self.grams(from: value(for: .fiber))
        )
        basis = container.decodeLossyString(forKey: .basis)
        perQuantity = container.decodeFlexibleDoubleIfPresent(forKey: .perQuantity) ?? 0
        perUnit = container.decodeLossyString(forKey: .perUnit)
        preparation = container.decodeLossyString(forKey: .preparation)
    }

    private init(
        calories: Double?,
        nutrients: FoodNutrients,
        basis: String,
        perQuantity: Double,
        perUnit: String,
        preparation: String
    ) {
        self.calories = calories
        self.nutrients = nutrients
        self.basis = basis
        self.perQuantity = perQuantity
        self.perUnit = perUnit
        self.preparation = preparation
    }

    private static func grams(from value: V3NutrientValue?) -> Double? {
        guard let value, let amount = value.value else { return nil }
        switch value.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "g": return amount
        case "kg": return amount * 1_000
        case "mg": return amount / 1_000
        case "mcg", "µg", "μg": return amount / 1_000_000
        default: return nil
        }
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
        case carbohydrates
        case totalCarbohydrates = "carbohydrates-total"
        case proteins
        case fat
        case fiber
    }
}

private struct V3NutrientValue: Decodable, Sendable {
    let value: Double?
    let unit: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedValue = container.decodeFlexibleDoubleIfPresent(forKey: .value)
            ?? container.decodeFlexibleDoubleIfPresent(forKey: .computedValue)
        if let decodedValue, decodedValue.isFinite, decodedValue >= 0 {
            value = decodedValue
        } else {
            value = nil
        }
        unit = container.decodeLossyString(forKey: .unit)
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case computedValue = "value_computed"
        case unit
    }
}

nonisolated func normalizedFoodBarcode(_ barcode: String) throws -> String {
    let normalizedBarcode = barcode.filter(\.isNumber)
    guard (8...14).contains(normalizedBarcode.count) else {
        throw FoodNutritionFetchError.invalidBarcode
    }
    return normalizedBarcode
}

nonisolated func normalizedFoodBarcodeIfValid(_ barcode: String) -> String? {
    try? normalizedFoodBarcode(barcode)
}

nonisolated func openFoodFactsProductURL(baseURL: URL, barcode: String, fields: String) throws -> URL {
    guard var components = URLComponents(url: baseURL.appending(path: barcode), resolvingAgainstBaseURL: false) else {
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
