import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import CaloriesCore
#else
@testable import count_calories
#endif

@MainActor
final class FoodAmountAdjustmentTests: XCTestCase {
    func testWholeUnitAdjustmentsApplyExactDeltas() {
        XCTAssertEqual(FoodAmountAdjustment.result(for: 100, delta: -10), 90)
        XCTAssertEqual(FoodAmountAdjustment.result(for: 100, delta: -1), 99)
        XCTAssertEqual(FoodAmountAdjustment.result(for: 100, delta: 1), 101)
        XCTAssertEqual(FoodAmountAdjustment.result(for: 100, delta: 10), 110)
    }

    func testDecimalRemainderIsPreserved() {
        XCTAssertEqual(FoodAmountAdjustment.result(for: 100.5, delta: -1), 99.5)
        XCTAssertEqual(FoodAmountAdjustment.result(for: 100.5, delta: 1), 101.5)
    }

    func testFloatingPointBoundaryReachesMinimumAmount() {
        XCTAssertEqual(
            FoodAmountAdjustment.result(for: 10.01, delta: -10),
            FoodAmountAdjustment.minimumAmount
        )
        XCTAssertTrue(FoodAmountAdjustment.isValid(FoodAmountAdjustment.minimumAmount))
    }

    func testCrossingMinimumReturnsInvalidResult() {
        XCTAssertNil(FoodAmountAdjustment.result(for: 10, delta: -10))
        XCTAssertNil(FoodAmountAdjustment.result(for: 0.01, delta: -0.01))
        XCTAssertNil(FoodAmountAdjustment.result(for: 0.01, delta: -1))
        XCTAssertFalse(FoodAmountAdjustment.isValid(0))
        XCTAssertFalse(FoodAmountAdjustment.isValid(0.009))
        XCTAssertFalse(FoodAmountAdjustment.isValid(-1))
    }

    func testPortionCountRequiresPositiveFiniteIntRepresentableCompatibilityValue() {
        XCTAssertTrue(FoodAmountAdjustment.isValidPortionCount(0.25))
        XCTAssertTrue(FoodAmountAdjustment.isValidPortionCount(2.5))
        XCTAssertFalse(FoodAmountAdjustment.isValidPortionCount(0))
        XCTAssertFalse(FoodAmountAdjustment.isValidPortionCount(-1))
        XCTAssertFalse(FoodAmountAdjustment.isValidPortionCount(.nan))
        XCTAssertFalse(FoodAmountAdjustment.isValidPortionCount(.infinity))
        XCTAssertFalse(FoodAmountAdjustment.isValidPortionCount(Double.greatestFiniteMagnitude))
    }

    func testNonfiniteInputsAndOverflowReturnInvalidResults() {
        XCTAssertFalse(FoodAmountAdjustment.isValid(.nan))
        XCTAssertFalse(FoodAmountAdjustment.isValid(.infinity))
        XCTAssertFalse(FoodAmountAdjustment.isValid(-.infinity))
        XCTAssertNil(FoodAmountAdjustment.result(for: .nan, delta: 1))
        XCTAssertNil(FoodAmountAdjustment.result(for: 100, delta: .nan))
        XCTAssertNil(FoodAmountAdjustment.result(for: .infinity, delta: -1))
        XCTAssertNil(FoodAmountAdjustment.result(for: 100, delta: .infinity))
        XCTAssertNil(
            FoodAmountAdjustment.result(
                for: Double.greatestFiniteMagnitude,
                delta: Double.greatestFiniteMagnitude
            )
        )
    }
}
