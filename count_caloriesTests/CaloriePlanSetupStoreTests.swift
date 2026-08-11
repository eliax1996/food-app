import XCTest
#if SWIFT_PACKAGE
@testable import TrackingCore
#else
@testable import count_calories
#endif

final class CaloriePlanSetupStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CaloriePlanSetupStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewInstallStartsWelcomeButExistingProfileMigratesToLegacyManual() {
        let newInstall = CaloriePlanSetupStore.load(
            profileExists: false,
            defaults: defaults
        )
        XCTAssertEqual(newInstall.status, .notStarted)
        XCTAssertEqual(newInstall.draft.step, .welcome)
        XCTAssertTrue(CaloriePlanSetupStore.shouldPresentAutomatically(
            record: newInstall
        ))

        CaloriePlanSetupStore.reset(defaults: defaults)
        let existing = CaloriePlanSetupStore.load(
            profileExists: true,
            defaults: defaults
        )
        XCTAssertEqual(existing.status, .legacyManual)
        XCTAssertFalse(CaloriePlanSetupStore.shouldPresentAutomatically(
            record: existing
        ))
    }

    func testInProgressDraftRoundTripsForResume() {
        let targetDate = Date(timeIntervalSince1970: 1_800_000_000)
        let record = CaloriePlanSetupRecord(
            status: .inProgress,
            draft: CaloriePlanSetupDraft(
                step: .pace,
                measurementSystem: .us,
                goalMode: .gain,
                currentWeightKilograms: 71.2,
                targetWeightKilograms: 75,
                age: 41,
                heightCentimeters: 173,
                equation: .male,
                activityLevel: .moderate,
                paceBasis: .targetDate,
                weeklyRateKilograms: 0.25,
                targetDate: targetDate,
                eligibilityConfirmed: true
            )
        )

        CaloriePlanSetupStore.save(record, defaults: defaults)

        XCTAssertEqual(
            CaloriePlanSetupStore.load(profileExists: true, defaults: defaults),
            record
        )
    }

    func testCorruptRecordFallsBackWithoutInventingCalculatedState() {
        defaults.set(Data("not-json".utf8), forKey: CaloriePlanSetupStore.storageKey)

        XCTAssertEqual(
            CaloriePlanSetupStore.load(profileExists: true, defaults: defaults).status,
            .legacyManual
        )
    }

    func testRecordWithoutNewAcceptanceBaselineMigratesWithNil() throws {
        let record = CaloriePlanSetupRecord(
            status: .inProgress,
            draft: CaloriePlanSetupDraft(),
            acceptedPlanDateAtStart: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoded = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "acceptedPlanDateAtStart")
        defaults.set(
            try JSONSerialization.data(withJSONObject: object),
            forKey: CaloriePlanSetupStore.storageKey
        )

        let migrated = CaloriePlanSetupStore.load(
            profileExists: true,
            defaults: defaults
        )
        XCTAssertEqual(migrated.status, .inProgress)
        XCTAssertNil(migrated.acceptedPlanDateAtStart)
    }

    func testAcceptedCalculationReconcilesInterruptedMarkerButNotActiveRedo() {
        let oldAcceptance = Date(timeIntervalSince1970: 1_700_000_000)
        let newAcceptance = Date(timeIntervalSince1970: 1_800_000_000)
        let interrupted = CaloriePlanSetupRecord(
            status: .inProgress,
            draft: CaloriePlanSetupDraft(),
            acceptedPlanDateAtStart: oldAcceptance
        )

        XCTAssertEqual(
            CaloriePlanSetupStore.reconciledAfterAcceptedCalculation(
                interrupted,
                acceptedPlanDate: newAcceptance
            ).status,
            .completed
        )
        XCTAssertEqual(
            CaloriePlanSetupStore.reconciledAfterAcceptedCalculation(
                interrupted,
                acceptedPlanDate: oldAcceptance
            ),
            interrupted,
            "An in-progress redo must not be mistaken for an interrupted acceptance."
        )
    }

    func testMaintainDraftUsesCurrentWeightAndRequiresExplicitEquationAndMode() {
        var draft = CaloriePlanSetupDraft()
        XCTAssertNil(draft.input())

        draft.goalMode = .maintain
        draft.equation = .female
        XCTAssertNil(draft.input(), "Daily routine must be selected explicitly.")
        draft.activityLevel = .low
        draft.currentWeightKilograms = 71.2
        draft.targetWeightKilograms = 42

        let input = draft.input()
        XCTAssertEqual(input?.goalMode, .maintain)
        XCTAssertEqual(input?.targetWeightKilograms, 71.2)
    }
}

#if !SWIFT_PACKAGE
final class CalculatedPlanProfileTests: XCTestCase {
    func testExistingProfileDefaultsToManualWithNoFabricatedCalculation() {
        let profile = UserProfile(dailyCalorieGoal: 1_700)

        XCTAssertEqual(profile.planGoalSource, .manual)
        XCTAssertNil(profile.storedCalculatedPlan)
        XCTAssertEqual(profile.dailyCalorieGoal, 1_700)
    }

    func testCalculatedAcceptanceManualOverrideAndRestoreAreExplicit() throws {
        let profile = UserProfile(dailyCalorieGoal: 1_700)
        let input = CaloriePlanInput(
            goalMode: .lose,
            currentWeightKilograms: 70,
            targetWeightKilograms: 65,
            age: 30,
            heightCentimeters: 170,
            equation: .female,
            activityLevel: .low,
            paceBasis: .weeklyRate,
            weeklyRateKilograms: 0.25,
            targetDate: nil
        )
        let evaluation = CalculatedCaloriePlanCalculator.evaluate(input)
        guard case .recommendation(let plan) = evaluation else {
            return XCTFail("Expected recommendation, got \(evaluation)")
        }

        try profile.applyCalculatedPlan(
            plan,
            measurementSystem: .metric,
            acceptedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(profile.planGoalSource, .calculated)
        XCTAssertEqual(profile.dailyCalorieGoal, plan.calorieGoal)
        XCTAssertEqual(profile.storedCalculatedPlan?.plan, plan)

        let manualDate = Date(timeIntervalSince1970: 1_900_000_000)
        profile.applyManualGoal(
            calories: 1_900,
            targetWeight: 64,
            targetDate: manualDate
        )
        XCTAssertEqual(profile.planGoalSource, .manual)
        XCTAssertEqual(profile.dailyCalorieGoal, 1_900)
        XCTAssertEqual(profile.storedCalculatedPlan?.plan, plan)

        XCTAssertTrue(profile.restoreStoredCalculatedGoal())
        XCTAssertEqual(profile.planGoalSource, .calculated)
        XCTAssertEqual(profile.dailyCalorieGoal, plan.calorieGoal)
        XCTAssertEqual(profile.targetWeight, plan.input.targetWeightKilograms)
        XCTAssertEqual(profile.targetDate, plan.forecastDate)
    }

    func testRestoreWithoutStoredCalculationChangesNothing() {
        let profile = UserProfile(dailyCalorieGoal: 1_700)

        XCTAssertFalse(profile.restoreStoredCalculatedGoal())
        XCTAssertEqual(profile.planGoalSource, .manual)
        XCTAssertEqual(profile.dailyCalorieGoal, 1_700)
    }
}
#endif
