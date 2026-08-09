#if !SWIFT_PACKAGE
import SwiftUI
import XCTest
@testable import count_calories

@MainActor
final class BarcodeScannerTests: XCTestCase {
    func testScannedBarcodeEmitsOnlyOnce() async {
        var scannedBarcodes: [String] = []
        let scanned = expectation(description: "Scanned barcode delivered")
        let coordinator = DataScannerRepresentable.Coordinator(onScan: { barcode in
            scannedBarcodes.append(barcode)
            scanned.fulfill()
        })

        coordinator.handleScannedBarcode("3017620422003")
        coordinator.handleScannedBarcode("9999999999999")

        await fulfillment(of: [scanned], timeout: 1)
        XCTAssertEqual(scannedBarcodes, ["3017620422003"])
    }

    func testDeniedAndRestrictedCameraAccessMapToPermissionIssue() {
        XCTAssertEqual(
            BarcodeScannerView.issue(for: .denied),
            .cameraPermissionDenied
        )
        XCTAssertEqual(
            BarcodeScannerView.issue(for: .restricted),
            .cameraPermissionDenied
        )
    }

    func testAuthorizedAndUndeterminedCameraAccessNeedNoIssue() {
        XCTAssertNil(BarcodeScannerView.issue(for: .authorized))
        XCTAssertNil(BarcodeScannerView.issue(for: .notDetermined))
    }

    func testBarcodeLookupFailureClassifiesConnectionAndServiceProblems() {
        XCTAssertEqual(
            BarcodeLookupFailure.classify(URLError(.notConnectedToInternet)),
            .offline
        )
        XCTAssertEqual(
            BarcodeLookupFailure.classify(URLError(.timedOut)),
            .unavailable
        )
        XCTAssertEqual(
            BarcodeLookupFailure.classify(FoodNutritionFetchError.serverError(503)),
            .unavailable
        )
        XCTAssertEqual(
            BarcodeLookupFailure.classify(FoodNutritionFetchError.invalidBarcode),
            .invalid
        )
    }

    func testBarcodeLookupFailureUsesCalmProductCopy() {
        XCTAssertEqual(BarcodeLookupFailure.notFound.title, "Product not found")
        XCTAssertEqual(
            BarcodeLookupFailure.incomplete.body,
            "Calorie details are missing. You can create a custom food below."
        )
        XCTAssertEqual(
            BarcodeLookupFailure.offline.body,
            "You can still create a custom food below. Reconnect, then try again."
        )
        XCTAssertEqual(BarcodeLookupFailure.offline.icon, "wifi.slash")
    }
}
#endif
