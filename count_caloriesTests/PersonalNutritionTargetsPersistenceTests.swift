#if !SWIFT_PACKAGE
import Foundation
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class PersonalNutritionTargetsPersistenceTests: XCTestCase {
    private enum InjectedFailure: Error { case save }

    func testTargetsPersistAndClearWithoutChangingPlanOrAdaptiveEvidence() throws {
        let fixture = try makeFixture()
        let targets = try XCTUnwrap(PersonalNutritionTargets(
            carbohydratesGrams: 220,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 28
        ))
        let original = try currentProfile(fixture.container)
        let originalGoal = original.dailyCalorieGoal
        let originalSource = original.planGoalSource
        let originalEvidence = original.evidenceRevision

        try fixture.coordinator.setPersonalNutritionTargets(targets)

        let saved = try currentProfile(fixture.container)
        XCTAssertEqual(saved.personalNutritionTargets, targets)
        XCTAssertEqual(saved.dailyCalorieGoal, originalGoal)
        XCTAssertEqual(saved.planGoalSource, originalSource)
        XCTAssertEqual(saved.evidenceRevision, originalEvidence)
        XCTAssertEqual(saved.adaptivePlanData, original.adaptivePlanData)

        try fixture.coordinator.setPersonalNutritionTargets(nil)
        let cleared = try currentProfile(fixture.container)
        XCTAssertNil(cleared.personalNutritionTargets)
        XCTAssertEqual(cleared.dailyCalorieGoal, originalGoal)
        XCTAssertEqual(cleared.evidenceRevision, originalEvidence)
    }

    func testCorruptStoredTargetsFailClosedWithoutDamagingProfile() throws {
        let schema = Schema([UserProfile.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        context.insert(UserProfile(
            dailyCalorieGoal: 1_923,
            personalNutritionTargetsData: Data("not-json".utf8)
        ))
        try context.save()

        let profile = try currentProfile(container)
        XCTAssertNil(profile.personalNutritionTargets)
        XCTAssertEqual(profile.dailyCalorieGoal, 1_923)
        XCTAssertEqual(profile.planGoalSource, .manual)
    }

    func testInjectedSaveFailureRollsBackTargetsAtomically() throws {
        let fixture = try makeFixture()
        let targets = try XCTUnwrap(PersonalNutritionTargets(
            carbohydratesGrams: 220,
            proteinGrams: 120,
            fatGrams: 60,
            fiberGrams: 28
        ))
        let failing = PlanEvidenceMutationCoordinator(
            modelContainer: fixture.container,
            beforeSave: { phase in
                if phase == .mutation { throw InjectedFailure.save }
            }
        )

        XCTAssertThrowsError(try failing.setPersonalNutritionTargets(targets))
        XCTAssertNil(try currentProfile(fixture.container).personalNutritionTargets)
    }

    func testTargetsSurviveFileBackedReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersonalTargets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("targets.store")
        let schema = Schema([UserProfile.self])
        let targets = try XCTUnwrap(PersonalNutritionTargets(
            carbohydratesGrams: 210,
            proteinGrams: 110,
            fatGrams: 70,
            fiberGrams: 30
        ))

        do {
            let configuration = ModelConfiguration("targets", schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(UserProfile())
            try context.save()
            try PlanEvidenceMutationCoordinator(modelContainer: container)
                .setPersonalNutritionTargets(targets)
        }

        do {
            let configuration = ModelConfiguration("targets", schema: schema, url: storeURL)
            let reopened = try ModelContainer(for: schema, configurations: [configuration])
            XCTAssertEqual(try currentProfile(reopened).personalNutritionTargets, targets)
        }
    }

    private struct Fixture {
        let container: ModelContainer
        let coordinator: PlanEvidenceMutationCoordinator
    }

    private func makeFixture() throws -> Fixture {
        let schema = Schema([UserProfile.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        context.insert(UserProfile(dailyCalorieGoal: 1_700))
        try context.save()
        return Fixture(
            container: container,
            coordinator: PlanEvidenceMutationCoordinator(modelContainer: container)
        )
    }

    private func currentProfile(_ container: ModelContainer) throws -> UserProfile {
        try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<UserProfile>()).first)
    }
}
#endif
