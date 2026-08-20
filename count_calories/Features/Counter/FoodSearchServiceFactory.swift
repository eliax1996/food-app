import Foundation

enum FoodSearchServiceFactory {
    static func make() -> RemoteFoodSearchService? {
#if DEBUG || RELEASE_VALIDATION
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") || arguments.contains("-design-review") {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "count-calories-fixture-food-search.json")
            try? FileManager.default.removeItem(at: url)
            guard let cache = try? FoodSearchCache(fileURL: url) else { return nil }
            return RemoteFoodSearchService(fetcher: FixtureFoodSearchFetcher(), cache: cache)
        }
#endif
        guard let cache = try? FoodSearchCache.applicationCache() else { return nil }
        return RemoteFoodSearchService(fetcher: OpenFoodFactsSearchClient(), cache: cache)
    }

    static var preferredLanguages: [String] {
        let current = Locale.current.language.languageCode?.identifier.lowercased() ?? "en"
        return current == "en" ? ["en"] : [current, "en"]
    }
}

private struct FixtureFoodSearchFetcher: FoodSearchFetching {
    func search(
        query: String,
        page: Int,
        pageSize: Int,
        languages: [String]
    ) async throws -> FoodSearchPage {
        let normalizedQuery = FoodSearchQuery.normalize(query)
        if normalizedQuery.contains("zzslow") {
            try await Task.sleep(for: .seconds(3))
        }
        if normalizedQuery.contains("zzoffline") {
            throw URLError(.notConnectedToInternet)
        }
        if normalizedQuery.contains("zzunavailable") {
            throw FoodSearchError.timedOut
        }

        let food: [FoodNutrition]
        if normalizedQuery.contains("zzremote") && page == 1 {
            food = [
                FoodNutrition(
                    barcode: "1234567890123",
                    name: "Remote Oat Drink",
                    defaultAmount: NutritionAmount(value: 250, unit: .milliliters),
                    caloriesPer100: 40,
                    nutrientsPer100: FoodNutrients(
                        carbohydratesGrams: 6.5,
                        proteinGrams: 1,
                        fatGrams: 1.2,
                        fiberGrams: 0.8
                    )
                )
            ]
        } else {
            food = []
        }
        return FoodSearchPage(
            query: FoodSearchQuery(query),
            foods: food,
            page: page,
            pageSize: pageSize,
            rawHitCount: food.count
        )
    }
}
