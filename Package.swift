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
        .target(
            name: "ReminderCore",
            path: "count_calories/Reminders"
        ),
        .target(
            name: "TrackingCore",
            dependencies: ["CaloriesCore"],
            path: "count_calories/Tracking"
        ),
        .testTarget(
            name: "CaloriesCoreTests",
            dependencies: ["CaloriesCore", "ReminderCore", "TrackingCore"],
            path: "count_caloriesTests"
        )
    ]
)
