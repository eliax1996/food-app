import Foundation
import SwiftData

struct WeightMeasurementSnapshot: Equatable, Sendable {
    let date: Date
    let kilograms: Double
    let stableID: UUID
    let sequence: Int64
}

@MainActor
final class WeightMeasurementStore {
    private let modelContext: ModelContext
    private let now: () -> Date

    init(modelContext: ModelContext, now: @escaping () -> Date = { .now }) {
        self.modelContext = modelContext
        self.now = now
    }

    @discardableResult
    func add(kilograms: Double, date: Date) throws -> WeightEntry {
        let operationNow = now()
        let validWeight = try validatedWeight(kilograms, date: date, now: operationNow)
        let entry = WeightEntry(
            date: date,
            kilograms: validWeight,
            sequence: try nextSequence()
        )
        modelContext.insert(entry)

        do {
            try reconcileProfile(now: operationNow)
            try modelContext.save()
            return entry
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func update(_ entry: WeightEntry, kilograms: Double, date: Date) throws {
        let operationNow = now()
        let validWeight = try validatedWeight(kilograms, date: date, now: operationNow)
        let nextSequence = try nextSequence()
        entry.kilograms = validWeight
        entry.date = date
        entry.sequence = nextSequence

        do {
            try reconcileProfile(now: operationNow)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func delete(_ entry: WeightEntry) throws -> WeightMeasurementSnapshot {
        let snapshot = WeightMeasurementSnapshot(
            date: entry.date,
            kilograms: entry.kilograms,
            stableID: entry.stableID,
            sequence: entry.sequence
        )
        let operationNow = now()
        modelContext.delete(entry)

        do {
            try reconcileProfile(now: operationNow)
            try modelContext.save()
            return snapshot
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func restore(_ snapshot: WeightMeasurementSnapshot) throws -> WeightEntry {
        let operationNow = now()
        let entry = WeightEntry(
            date: snapshot.date,
            kilograms: snapshot.kilograms,
            stableID: snapshot.stableID,
            sequence: snapshot.sequence
        )
        modelContext.insert(entry)

        do {
            try reconcileProfile(now: operationNow)
            try modelContext.save()
            return entry
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func reconcileProfile() throws {
        let operationNow = now()

        do {
            try reconcileProfile(now: operationNow)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func validatedWeight(_ kilograms: Double, date: Date, now: Date) throws -> Double {
        let validWeight = try WeightHistory.validatedWeight(kilograms)
        guard date <= now else {
            throw WeightHistoryError.futureTimestamp
        }
        return validWeight
    }

    private func nextSequence() throws -> Int64 {
        let entries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        let entryMaximum = entries.map(\.sequence).max() ?? 0
        let profileMaximum = profiles.map(\.nextWeightSequence).max() ?? 0
        let highWaterMark = max(profileMaximum, entryMaximum)
        guard highWaterMark < Int64.max else {
            throw WeightHistoryError.sequenceOverflow
        }

        let next = highWaterMark + 1
        if profiles.isEmpty {
            modelContext.insert(UserProfile(nextWeightSequence: next))
        } else {
            for profile in profiles {
                profile.nextWeightSequence = next
            }
        }
        return next
    }

    private func reconcileProfile(now: Date) throws {
        let entries = try modelContext.fetch(FetchDescriptor<WeightEntry>())
        let currentWeight = WeightHistory.latestValidMeasurement(
            from: entries.map {
                WeightProgressPoint(
                    date: $0.date,
                    kilograms: $0.kilograms,
                    stableID: $0.stableID,
                    sequence: $0.sequence
                )
            },
            now: now
        )?.kilograms ?? 0
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())

        if profiles.isEmpty {
            modelContext.insert(UserProfile(currentWeight: currentWeight))
        } else {
            for profile in profiles {
                profile.currentWeight = currentWeight
            }
        }
    }
}
