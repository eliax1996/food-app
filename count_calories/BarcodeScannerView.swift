import SwiftUI
import Vision
import VisionKit
import os

struct BarcodeScannerView: UIViewControllerRepresentable {
    private static let logger = Logger(subsystem: "ch.elia.count-calories", category: "barcode.scanner")

    @Binding var isPresented: Bool
    @Binding var errorMessage: String?
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, errorMessage: $errorMessage, onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            Self.logger.error("Barcode scanner is unavailable")
            context.coordinator.dismissWithError("Barcode scanning is unavailable on this device. Enter the barcode manually.")
            return scanner
        }
        do {
            try scanner.startScanning()
        } catch {
            Self.logger.error("Failed to start barcode scanner: \(error.localizedDescription, privacy: .public)")
            context.coordinator.dismissWithError("Barcode scanning could not start. Enter the barcode manually.")
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding private var isPresented: Bool
        @Binding private var errorMessage: String?
        private let onScan: (String) -> Void
        private var didScanBarcode = false

        init(isPresented: Binding<Bool>, errorMessage: Binding<String?>, onScan: @escaping (String) -> Void) {
            _isPresented = isPresented
            _errorMessage = errorMessage
            self.onScan = onScan
        }

        func dismissWithError(_ message: String) {
            DispatchQueue.main.async {
                self.errorMessage = message
                self.isPresented = false
            }
        }

        func handleScannedBarcode(_ value: String) {
            guard !didScanBarcode else { return }
            didScanBarcode = true

            DispatchQueue.main.async {
                self.onScan(value)
                self.isPresented = false
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard case let .barcode(code) = addedItems.first, let value = code.payloadStringValue else { return }
            handleScannedBarcode(value)
        }
    }
}
