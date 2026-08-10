import Foundation

nonisolated enum WeightEntryDraft {
    static let fallbackKilograms = 70.0

    static func defaultKilograms(
        measurements: [WeightProgressPoint],
        profileCurrentWeight: Double?,
        now: Date = .now
    ) -> Double {
        if let latest = WeightHistory.latestValidMeasurement(from: measurements, now: now) {
            return latest.kilograms
        }
        if let profileCurrentWeight, WeightHistory.isValidWeight(profileCurrentWeight) {
            return profileCurrentWeight
        }
        return fallbackKilograms
    }

    static func adjustedKilograms(_ kilograms: Double, by delta: Double) -> Double? {
        guard kilograms.isFinite, delta.isFinite else { return nil }
        let adjusted = ((kilograms + delta) * 10).rounded() / 10
        return WeightHistory.isValidWeight(adjusted) ? adjusted : nil
    }
}
