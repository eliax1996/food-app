import Foundation

enum NutritionLookupServiceFactory {
    static func make() throws -> NutritionLookupService {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") || arguments.contains("-design-review") {
            return NutritionLookupService(
                client: FixtureNutritionFetcher(),
                cache: InMemoryNutritionCache()
            )
        }
#endif
        return NutritionLookupService(
            client: OpenFoodFactsClient(),
            cache: try NutritionCache.applicationCache()
        )
    }
}

#if DEBUG
private actor InMemoryNutritionCache: FoodNutritionCaching {
    private var entries: [String: FoodNutrition] = [:]

    func nutrition(for barcode: String) -> FoodNutrition? {
        entries[barcode]
    }

    func store(_ nutrition: FoodNutrition) {
        entries[nutrition.barcode] = nutrition
    }

    func store(_ nutrition: FoodNutrition, for barcode: String) {
        entries[barcode] = nutrition
    }
}

private struct FixtureNutritionFetcher: FoodNutritionFetching {
    func fetchNutrition(for barcode: String) async throws -> FoodNutritionFetchResult {
        switch barcode {
        case "99999999":
            throw URLError(.notConnectedToInternet)
        case "00000000":
            return .notFound
        case "11111111":
            try await Task.sleep(for: .seconds(8))
            return .notFound
        case "12345678":
            return .found(
                FoodNutrition(
                    barcode: barcode,
                    name: "Fixture Granola",
                    defaultAmount: NutritionAmount(value: 45, unit: .grams),
                    caloriesPer100: 420,
                    nutrientsPer100: FoodNutrients(
                        carbohydratesGrams: 64,
                        proteinGrams: 10,
                        fatGrams: 14,
                        fiberGrams: 8
                    )
                )
            )
        default:
            return .notFound
        }
    }
}
#endif
