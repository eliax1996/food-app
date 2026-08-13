#if !SWIFT_PACKAGE
import SwiftData
import XCTest
@testable import count_calories

@MainActor
final class AppPersistenceTests: XCTestCase {
    private enum OpenFailure: Error { case unavailable }

    func testFailedStoreOpenCanRetryWithoutDeletingData() throws {
        let schema = Schema([Food.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        var attempts = 0
        let persistence = AppPersistence {
            attempts += 1
            guard attempts > 1 else { throw OpenFailure.unavailable }
            return container
        }

        XCTAssertTrue(persistence.hasError)
        XCTAssertNil(persistence.ready)

        persistence.retry()

        XCTAssertFalse(persistence.hasError)
        XCTAssertTrue(persistence.ready?.modelContainer === container)
        XCTAssertNotNil(persistence.ready?.mutationCoordinator)
        XCTAssertEqual(attempts, 2)
    }
}
#endif
