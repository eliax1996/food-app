import Foundation

enum NutritionUnit: String, Codable, Equatable, Sendable {
    case grams = "g"
    case milliliters = "ml"
}

struct NutritionAmount: Equatable, Sendable {
    let value: Double
    let unit: NutritionUnit

    init?(value: Double?, unit: NutritionUnit?) {
        guard let value, value > 0, let unit else { return nil }
        self.value = value
        self.unit = unit
    }

    init?(value: Double?, unitDescription: String?) {
        guard let value, value > 0, let unitDescription else { return nil }

        switch unitDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gram", "grams":
            self.init(value: value, unit: .grams)
        case "kg", "kilogram", "kilograms":
            self.init(value: value * 1_000, unit: .grams)
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            self.init(value: value, unit: .milliliters)
        case "cl", "centiliter", "centiliters", "centilitre", "centilitres":
            self.init(value: value * 10, unit: .milliliters)
        case "l", "liter", "liters", "litre", "litres":
            self.init(value: value * 1_000, unit: .milliliters)
        default:
            return nil
        }
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

        return NutritionAmount(value: value, unitDescription: String(description[unitRange]))
    }
}

struct FoodNutrition: Codable, Equatable, Identifiable, Sendable {
    let barcode: String
    let name: String
    let brand: String?
    let quantityDescription: String?
    let servingGrams: Double?
    let servingUnit: NutritionUnit?
    let caloriesPer100Grams: Double?
    let proteinGramsPer100Grams: Double?
    let carbohydrateGramsPer100Grams: Double?
    let fatGramsPer100Grams: Double?
    let fiberGramsPer100Grams: Double?
    let sugarGramsPer100Grams: Double?
    let saltGramsPer100Grams: Double?

    init(
        barcode: String,
        name: String,
        brand: String?,
        quantityDescription: String?,
        servingGrams: Double?,
        servingUnit: NutritionUnit? = nil,
        caloriesPer100Grams: Double?,
        proteinGramsPer100Grams: Double?,
        carbohydrateGramsPer100Grams: Double?,
        fatGramsPer100Grams: Double?,
        fiberGramsPer100Grams: Double?,
        sugarGramsPer100Grams: Double?,
        saltGramsPer100Grams: Double?
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.quantityDescription = quantityDescription
        self.servingGrams = servingGrams
        self.servingUnit = servingUnit
        self.caloriesPer100Grams = caloriesPer100Grams
        self.proteinGramsPer100Grams = proteinGramsPer100Grams
        self.carbohydrateGramsPer100Grams = carbohydrateGramsPer100Grams
        self.fatGramsPer100Grams = fatGramsPer100Grams
        self.fiberGramsPer100Grams = fiberGramsPer100Grams
        self.sugarGramsPer100Grams = sugarGramsPer100Grams
        self.saltGramsPer100Grams = saltGramsPer100Grams
    }

    var id: String { barcode }

    var servingAmount: Double? {
        servingGrams ?? NutritionAmount.parse(quantityDescription)?.value
    }

    var resolvedServingUnit: NutritionUnit {
        servingUnit ?? NutritionAmount.parse(quantityDescription)?.unit ?? .grams
    }

    var hasServingUnitMetadata: Bool {
        servingUnit != nil || NutritionAmount.parse(quantityDescription) != nil
    }

    func calories(for weightGrams: Double) -> Double? {
        guard let caloriesPer100Grams else { return nil }
        return caloriesPer100Grams * weightGrams / 100
    }
}
