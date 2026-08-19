import Foundation

nonisolated enum PersonalNutritionTargetInput {
    static func text(for value: Double?, locale: Locale = .current) -> String {
        guard let value else { return "" }
        let separator = locale.decimalSeparator ?? "."
        return String(value).replacingOccurrences(of: ".", with: separator)
    }

    static func value(from text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let separator = locale.decimalSeparator ?? "."
        var normalized = trimmed
        if separator != "." {
            guard !trimmed.contains(".") else { return nil }
            let components = trimmed.components(separatedBy: separator)
            guard components.count <= 2 else { return nil }
            normalized = components.joined(separator: ".")
        }

        var ascii = ""
        for character in normalized {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                ascii.append(String(digit))
            } else {
                ascii.append(character)
            }
        }
        let pattern = #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#
        guard ascii.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return Double(ascii)
    }
}

nonisolated struct PersonalNutritionTargets: Codable, Equatable, Sendable {
    static let maximumMacroEnergyCalories = 5_000.0
    static let maximumFiberGrams = 200.0

    let carbohydratesGrams: Double
    let proteinGrams: Double
    let fatGrams: Double
    let fiberGrams: Double

    init?(
        carbohydratesGrams: Double,
        proteinGrams: Double,
        fatGrams: Double,
        fiberGrams: Double
    ) {
        let values = [carbohydratesGrams, proteinGrams, fatGrams, fiberGrams]
        guard values.allSatisfy({ $0.isFinite && $0 > 0 }),
              fiberGrams <= Self.maximumFiberGrams else {
            return nil
        }
        let macroEnergyCalories = carbohydratesGrams * 4
            + proteinGrams * 4
            + fatGrams * 9
        guard macroEnergyCalories.isFinite,
              macroEnergyCalories <= Self.maximumMacroEnergyCalories else {
            return nil
        }
        self.carbohydratesGrams = carbohydratesGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }

    var macroEnergyCalories: Double {
        carbohydratesGrams * 4 + proteinGrams * 4 + fatGrams * 9
    }

    func grams(for nutrient: Macronutrient) -> Double {
        switch nutrient {
        case .carbohydrates: carbohydratesGrams
        case .protein: proteinGrams
        case .fat: fatGrams
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let carbohydrates = try container.decode(Double.self, forKey: .carbohydratesGrams)
        let protein = try container.decode(Double.self, forKey: .proteinGrams)
        let fat = try container.decode(Double.self, forKey: .fatGrams)
        let fiber = try container.decode(Double.self, forKey: .fiberGrams)
        guard let validated = Self(
            carbohydratesGrams: carbohydrates,
            proteinGrams: protein,
            fatGrams: fat,
            fiberGrams: fiber
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .carbohydratesGrams,
                in: container,
                debugDescription: "Personal nutrition targets are outside supported finite bounds."
            )
        }
        self = validated
    }

    private enum CodingKeys: String, CodingKey {
        case carbohydratesGrams
        case proteinGrams
        case fatGrams
        case fiberGrams
    }
}
