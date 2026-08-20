#if !SWIFT_PACKAGE
import XCTest
@testable import count_calories

final class AppObservabilityTests: XCTestCase {
    func testOperationalSpansReceiveUniqueCorrelationIdentifiers() {
        let first = AppLogger.begin(
            "test.operation",
            category: .persistence,
            source: "test"
        )
        let second = AppLogger.begin(
            "test.operation",
            category: .persistence,
            source: "test",
            parentID: first.id
        )
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.name, "test.operation")
        XCTAssertEqual(first.source, "test")
        XCTAssertNil(first.parentID)
        XCTAssertEqual(second.parentID, first.id)
        AppLogger.succeed(first)
        AppLogger.cancel(second)
    }

    func testNetworkFailuresMapToStablePrivacySafeCategories() {
        XCTAssertEqual(
            AppLogger.errorCategory(for: URLError(.notConnectedToInternet)),
            .networkOffline
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: URLError(.timedOut)),
            .networkTimeout
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: CancellationError()),
            .cancelled
        )
    }

    func testMutationFailuresDistinguishConflictInvalidInputAndUnavailable() {
        XCTAssertEqual(
            AppLogger.errorCategory(for: PlanEvidenceMutationError.compareAndSetFailed),
            .conflict
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: PlanEvidenceMutationError.invalidHistoricalMutation),
            .invalidInput
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: PlanEvidenceMutationError.coordinatorUnavailable),
            .unavailable
        )
    }

    func testBulkAndDictationFailuresUseStableCategories() {
        XCTAssertEqual(
            AppLogger.errorCategory(for: BulkFoodValidationError.invalidAmount),
            .invalidInput
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: BulkFoodPersistenceError.staleLease),
            .conflict
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: MealDictationFailure.permissionDenied),
            .permission
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: MealDictationFailure.resourcesUnavailable),
            .unavailable
        )
    }

    func testStorageFailuresNeverExposeRawDescriptionsAsCategories() {
        XCTAssertEqual(
            AppLogger.errorCategory(for: CocoaError(.fileWriteUnknown)),
            .storage
        )
        XCTAssertEqual(
            AppLogger.errorCategory(for: POSIXError(.EIO)),
            .storage
        )
    }
}
#endif
