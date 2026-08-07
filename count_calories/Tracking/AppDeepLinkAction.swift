import Foundation

enum AppDeepLinkAction: Equatable {
    case addMeal
    case adjustWater(by: Int)

    init?(url: URL) {
        guard url.scheme == "countcalories" else { return nil }

        switch url.host {
        case "add-food":
            self = .addMeal
        case "water":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let delta = components?.queryItems?
                .first(where: { $0.name == "delta" })?
                .value
                .flatMap(Int.init) ?? 0
            guard delta != 0 else { return nil }
            self = .adjustWater(by: delta)
        default:
            return nil
        }
    }
}
