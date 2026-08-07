#if !SWIFT_PACKAGE
import SwiftUI
import XCTest
@testable import count_calories

@MainActor
final class BarcodeScannerTests: XCTestCase {
    func testScannedBarcodeDismissesScannerAndEmitsOnlyOnce() async {
        var isPresented = true
        var errorMessage: String?
        var scannedBarcodes: [String] = []
        let scanned = expectation(description: "Scanned barcode delivered")

        let coordinator = BarcodeScannerView.Coordinator(
            isPresented: Binding(
                get: { isPresented },
                set: { isPresented = $0 }
            ),
            errorMessage: Binding(
                get: { errorMessage },
                set: { errorMessage = $0 }
            ),
            onScan: { barcode in
                scannedBarcodes.append(barcode)
                scanned.fulfill()
            }
        )

        coordinator.handleScannedBarcode("3017620422003")
        coordinator.handleScannedBarcode("9999999999999")

        await fulfillment(of: [scanned], timeout: 1)
        XCTAssertFalse(isPresented)
        XCTAssertNil(errorMessage)
        XCTAssertEqual(scannedBarcodes, ["3017620422003"])
    }

    func testPlateEntryStoresFractionalQuantityAndVolumeUnit() {
        let entry = PlateEntry(
            foodName: "La Nostra Limonata",
            calories: 44,
            weightGrams: 275,
            quantity: 0.25,
            servingUnit: .milliliters
        )

        XCTAssertEqual(entry.portionCount, 0.25)
        XCTAssertEqual(entry.servingUnitRawValue, NutritionUnit.milliliters.rawValue)
    }
}
#endif
