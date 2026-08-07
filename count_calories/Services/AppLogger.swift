import os

enum AppLogger {
    static let persistence = Logger(
        subsystem: "ch.elia.count-calories",
        category: "persistence"
    )
}
