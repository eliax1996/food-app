// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CaloriesCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CaloriesCore", targets: ["CaloriesCore"])
    ],
    targets: [
        .target(
            name: "CaloriesCore",
            path: "count_calories/Nutrition"
        ),
        .testTarget(
            name: "CaloriesCoreTests",
            dependencies: ["CaloriesCore"],
            path: "count_caloriesTests"
        )
    ]
)
