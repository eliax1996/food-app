import Foundation

nonisolated enum NutritionUnit: String, Codable, Equatable, Sendable {
    case grams = "g"
    case milliliters = "ml"

    static func inferred(from description: String?) -> NutritionUnit? {
        guard let description else { return nil }
        if let parsedAmount = NutritionAmount.parse(description) {
            return parsedAmount.unit
        }

        switch description.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gram", "grams", "kg", "kilogram", "kilograms":
            return .grams
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres",
             "cl", "centiliter", "centiliters", "centilitre", "centilitres",
             "l", "liter", "liters", "litre", "litres":
            return .milliliters
        default:
            return nil
        }
    }
}

nonisolated struct NutritionAmount: Codable, Equatable, Sendable {
    let value: Double
    let unit: NutritionUnit

    init(value: Double, unit: NutritionUnit) {
        precondition(value.isFinite && value > 0, "Nutrition amounts must be finite and positive.")
        self.value = value
        self.unit = unit
    }

    static func validated(value: Double?, unit: NutritionUnit?) -> NutritionAmount? {
        guard let value, value.isFinite, value > 0, let unit else { return nil }
        return NutritionAmount(value: value, unit: unit)
    }

    static func normalized(value: Double?, unitDescription: String?) -> NutritionAmount? {
        guard let value, value.isFinite, value > 0, let unitDescription else { return nil }

        let normalizedValue: Double
        let unit: NutritionUnit
        switch unitDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gram", "grams":
            normalizedValue = value
            unit = .grams
        case "kg", "kilogram", "kilograms":
            normalizedValue = value * 1_000
            unit = .grams
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            normalizedValue = value
            unit = .milliliters
        case "cl", "centiliter", "centiliters", "centilitre", "centilitres":
            normalizedValue = value * 10
            unit = .milliliters
        case "l", "liter", "liters", "litre", "litres":
            normalizedValue = value * 1_000
            unit = .milliliters
        default:
            return nil
        }

        guard normalizedValue.isFinite else { return nil }
        return NutritionAmount(value: normalizedValue, unit: unit)
    }

    static func parse(_ description: String?) -> NutritionAmount? {
        guard let description else { return nil }
        let pattern = #"([0-9]+(?:[.,][0-9]+)?)\s*(ml|cl|kg|g|l)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(description.startIndex..., in: description)
        guard
            let match = expression.firstMatch(in: description, range: range),
            let valueRange = Range(match.range(at: 1), in: description),
            let unitRange = Range(match.range(at: 2), in: description),
            let value = Double(description[valueRange].replacingOccurrences(of: ",", with: "."))
        else {
            return nil
        }

        return normalized(value: value, unitDescription: String(description[unitRange]))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Double.self, forKey: .value)
        let unit = try container.decode(NutritionUnit.self, forKey: .unit)
        guard value.isFinite, value > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .value,
                in: container,
                debugDescription: "Nutrition amounts must be finite and positive."
            )
        }
        self.value = value
        self.unit = unit
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case unit
    }
}

nonisolated struct FoodNutrients: Codable, Equatable, Sendable {
    static let empty = FoodNutrients()

    let carbohydratesGrams: Double?
    let proteinGrams: Double?
    let fatGrams: Double?
    let fiberGrams: Double?

    init(
        carbohydratesGrams: Double? = nil,
        proteinGrams: Double? = nil,
        fatGrams: Double? = nil,
        fiberGrams: Double? = nil
    ) {
        self.carbohydratesGrams = Self.validated(carbohydratesGrams)
        self.proteinGrams = Self.validated(proteinGrams)
        self.fatGrams = Self.validated(fatGrams)
        self.fiberGrams = Self.validated(fiberGrams)
    }

    var hasCompleteMacros: Bool {
        carbohydratesGrams != nil && proteinGrams != nil && fatGrams != nil
    }

    var isComplete: Bool {
        hasCompleteMacros && fiberGrams != nil
    }

    var isEmpty: Bool {
        carbohydratesGrams == nil && proteinGrams == nil && fatGrams == nil && fiberGrams == nil
    }

    func scaled(by multiplier: Double) -> FoodNutrients {
        guard multiplier.isFinite, multiplier >= 0 else { return .empty }
        return FoodNutrients(
            carbohydratesGrams: carbohydratesGrams.map { $0 * multiplier },
            proteinGrams: proteinGrams.map { $0 * multiplier },
            fatGrams: fatGrams.map { $0 * multiplier },
            fiberGrams: fiberGrams.map { $0 * multiplier }
        )
    }

    func mergingMissingValues(from fallback: FoodNutrients) -> FoodNutrients {
        FoodNutrients(
            carbohydratesGrams: carbohydratesGrams ?? fallback.carbohydratesGrams,
            proteinGrams: proteinGrams ?? fallback.proteinGrams,
            fatGrams: fatGrams ?? fallback.fatGrams,
            fiberGrams: fiberGrams ?? fallback.fiberGrams
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            carbohydratesGrams: try container.decodeIfPresent(Double.self, forKey: .carbohydratesGrams),
            proteinGrams: try container.decodeIfPresent(Double.self, forKey: .proteinGrams),
            fatGrams: try container.decodeIfPresent(Double.self, forKey: .fatGrams),
            fiberGrams: try container.decodeIfPresent(Double.self, forKey: .fiberGrams)
        )
    }

    private static func validated(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private enum CodingKeys: String, CodingKey {
        case carbohydratesGrams
        case proteinGrams
        case fatGrams
        case fiberGrams
    }
}

nonisolated struct FoodNutrition: Codable, Equatable, Identifiable, Sendable {
    let barcode: String
    let name: String
    let defaultAmount: NutritionAmount
    let caloriesPer100: Double
    let nutrientsPer100: FoodNutrients

    init(
        barcode: String,
        name: String,
        defaultAmount: NutritionAmount,
        caloriesPer100: Double,
        nutrientsPer100: FoodNutrients = .empty
    ) {
        precondition(caloriesPer100.isFinite && caloriesPer100 >= 0, "Calories must be finite and nonnegative.")
        self.barcode = barcode
        self.name = name
        self.defaultAmount = defaultAmount
        self.caloriesPer100 = caloriesPer100
        self.nutrientsPer100 = nutrientsPer100
    }

    var id: String { barcode }

    func calories(for amount: Double) -> Double {
        caloriesPer100 * amount / 100
    }

    func nutrients(for amount: Double) -> FoodNutrients {
        nutrientsPer100.scaled(by: amount / 100)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let barcode = try container.decode(String.self, forKey: .barcode)
        let name = try container.decode(String.self, forKey: .name)
        let calories = try container.decodeIfPresent(Double.self, forKey: .caloriesPer100)
            ?? container.decode(Double.self, forKey: .legacyCaloriesPer100Grams)

        let defaultAmount: NutritionAmount
        if let currentAmount = try container.decodeIfPresent(NutritionAmount.self, forKey: .defaultAmount) {
            defaultAmount = currentAmount
        } else {
            let legacyValue = try container.decodeIfPresent(Double.self, forKey: .legacyServingGrams)
            let legacyUnit = try container.decodeIfPresent(NutritionUnit.self, forKey: .legacyServingUnit)
            let quantityDescription = try container.decodeIfPresent(String.self, forKey: .legacyQuantityDescription)
            defaultAmount = NutritionAmount.validated(value: legacyValue, unit: legacyUnit)
                ?? NutritionAmount.parse(quantityDescription)
                ?? NutritionAmount.validated(value: legacyValue, unit: .grams)
                ?? NutritionAmount(value: 100, unit: .grams)
        }

        guard
            !barcode.isEmpty,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            calories.isFinite,
            calories >= 0
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Cached food nutrition is incomplete or invalid."
            )
        }

        let currentNutrients = try container.decodeIfPresent(
            FoodNutrients.self,
            forKey: .nutrientsPer100
        )
        let legacyNutrients = FoodNutrients(
            carbohydratesGrams: try container.decodeIfPresent(
                Double.self,
                forKey: .legacyCarbohydratesPer100Grams
            ),
            proteinGrams: try container.decodeIfPresent(
                Double.self,
                forKey: .legacyProteinPer100Grams
            ),
            fatGrams: try container.decodeIfPresent(
                Double.self,
                forKey: .legacyFatPer100Grams
            ),
            fiberGrams: try container.decodeIfPresent(
                Double.self,
                forKey: .legacyFiberPer100Grams
            )
        )

        self.barcode = barcode
        self.name = name
        self.defaultAmount = defaultAmount
        caloriesPer100 = calories
        nutrientsPer100 = currentNutrients ?? legacyNutrients
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(barcode, forKey: .barcode)
        try container.encode(name, forKey: .name)
        try container.encode(defaultAmount, forKey: .defaultAmount)
        try container.encode(caloriesPer100, forKey: .caloriesPer100)
        try container.encode(nutrientsPer100, forKey: .nutrientsPer100)
    }

    private enum CodingKeys: String, CodingKey {
        case barcode
        case name
        case defaultAmount
        case caloriesPer100
        case nutrientsPer100
        case legacyQuantityDescription = "quantityDescription"
        case legacyServingGrams = "servingGrams"
        case legacyServingUnit = "servingUnit"
        case legacyCaloriesPer100Grams = "caloriesPer100Grams"
        case legacyProteinPer100Grams = "proteinGramsPer100Grams"
        case legacyCarbohydratesPer100Grams = "carbohydrateGramsPer100Grams"
        case legacyFatPer100Grams = "fatGramsPer100Grams"
        case legacyFiberPer100Grams = "fiberGramsPer100Grams"
    }
}
