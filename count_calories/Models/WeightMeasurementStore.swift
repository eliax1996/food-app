import Foundation

struct WeightMeasurementSnapshot: Equatable, Sendable {
    let date: Date
    let kilograms: Double
    let stableID: UUID
    let sequence: Int64
    let createdAt: Date
    let modifiedAt: Date
}

@MainActor
final class WeightMeasurementStore {
    private let coordinator: PlanEvidenceMutationCoordinator

    init(coordinator: PlanEvidenceMutationCoordinator) {
        self.coordinator = coordinator
    }

    @discardableResult
    func add(kilograms: Double, date: Date) throws -> WeightEntry {
        try coordinator.addWeightMeasurement(kilograms: kilograms, date: date)
    }

    func update(_ entry: WeightEntry, kilograms: Double, date: Date) throws {
        try coordinator.updateWeightMeasurement(entry, kilograms: kilograms, date: date)
    }

    @discardableResult
    func delete(_ entry: WeightEntry) throws -> WeightMeasurementSnapshot {
        try coordinator.deleteWeightMeasurement(entry)
    }

    @discardableResult
    func restore(_ snapshot: WeightMeasurementSnapshot) throws -> WeightEntry {
        try coordinator.restoreWeightMeasurement(snapshot)
    }

    func reconcileProfile() throws {
        try coordinator.reconcileWeightProfile()
    }
}
