import Foundation

enum FoodSearchServiceFactory {
    static func make() -> RemoteFoodSearchService? {
#if DEBUG
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
        let food: [FoodNutrition]
        if FoodSearchQuery.normalize(query).contains("zzremote") && page == 1 {
            food = [
                FoodNutrition(
                    barcode: "1234567890123",
                    name: "Remote Oat Drink",
                    defaultAmount: NutritionAmount(value: 250, unit: .milliliters),
                    caloriesPer100: 40
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
