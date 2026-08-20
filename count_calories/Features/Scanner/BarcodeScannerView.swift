import AVFoundation
import SwiftUI
import UIKit
import Vision
import VisionKit
import os

enum BarcodeScannerIssue: Equatable {
    case cameraPermissionDenied
    case unsupported
    case temporarilyUnavailable

    var title: String {
        switch self {
        case .cameraPermissionDenied:
            "Camera access is off"
        case .unsupported:
            "Scanner unavailable"
        case .temporarilyUnavailable:
            "Scanner unavailable right now"
        }
    }

    var message: String {
        switch self {
        case .cameraPermissionDenied:
            "Allow camera access in Settings, or enter the barcode manually."
        case .unsupported:
            "This device cannot scan barcodes. Enter one manually instead."
        case .temporarilyUnavailable:
            "Camera could not start. Try again or enter barcode manually."
        }
    }

    var image: String {
        switch self {
        case .cameraPermissionDenied:
            "camera.fill"
        case .unsupported:
            "barcode.viewfinder"
        case .temporarilyUnavailable:
            "camera.badge.ellipsis"
        }
    }
}

struct BarcodeScannerView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Binding var isPresented: Bool
    let onScan: (String) -> Void
    let onEnterManually: () -> Void
    private let initialIssue: BarcodeScannerIssue?

    @State private var issue: BarcodeScannerIssue?
    @State private var shouldStartScanner = false
    @State private var isRequestingCameraAccess = false

    init(
        isPresented: Binding<Bool>,
        onScan: @escaping (String) -> Void,
        onEnterManually: @escaping () -> Void,
        initialIssue: BarcodeScannerIssue? = nil
    ) {
        _isPresented = isPresented
        self.onScan = onScan
        self.onEnterManually = onEnterManually
        self.initialIssue = initialIssue
    }

    var body: some View {
        NavigationStack {
            Group {
                if let debugBarcode = Self.debugBarcode {
                    fixtureScannerView(barcode: debugBarcode)
                } else if let issue {
                    issueView(for: issue)
                } else if shouldStartScanner {
                    DataScannerRepresentable(
                        onScan: { barcode in
                            onScan(barcode)
                            isPresented = false
                        },
                        onIssue: { scannerIssue in
                            issue = scannerIssue
                            shouldStartScanner = false
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView("Preparing camera")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .accessibilityLabel("Cancel barcode scanner")
                    .accessibilityIdentifier("barcode-scanner-cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if issue == nil {
                    manualEntryButton
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
        }
        .onAppear(perform: startScanner)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active,
                  issue == .cameraPermissionDenied,
                  Self.debugIssue == nil
            else { return }
            startScanner()
        }
    }

    private func fixtureScannerView(barcode: String) -> some View {
        ContentUnavailableView {
            Label("Test barcode ready", systemImage: "barcode.viewfinder")
        } description: {
            Text("Use deterministic scanner input.")
        } actions: {
            Button("Scan fixture barcode") {
                onScan(barcode)
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .accessibilityIdentifier("barcode-scanner-fixture-scan")
        }
    }

    @ViewBuilder
    private func issueView(for issue: BarcodeScannerIssue) -> some View {
        ContentUnavailableView {
            Label(issue.title, systemImage: issue.image)
        } description: {
            Text(issue.message)
        } actions: {
            VStack(spacing: 12) {
                if issue == .cameraPermissionDenied {
                    Button {
                        openSettings()
                    } label: {
                        actionLabel("Open Settings")
                    }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Open Settings for camera access")
                        .accessibilityIdentifier("barcode-scanner-open-settings")
                }

                if issue == .temporarilyUnavailable {
                    Button {
                        startScanner()
                    } label: {
                        actionLabel("Try scanner again")
                    }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Try barcode scanner again")
                        .accessibilityIdentifier("barcode-scanner-retry")
                }

                if issue == .unsupported {
                    manualEntryButton
                        .buttonStyle(.borderedProminent)
                } else {
                    manualEntryButton
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                }
            }
            .controlSize(.large)
            .frame(maxWidth: 280)
        }
        .accessibilityIdentifier("barcode-scanner-state")
    }

    private var manualEntryButton: some View {
        Button {
            onEnterManually()
        } label: {
            Text("Enter barcode manually")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityLabel("Enter barcode manually")
        .accessibilityIdentifier("barcode-scanner-enter-manually")
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func startScanner() {
        guard isPresented else { return }
        shouldStartScanner = false
        issue = nil

        if let forcedIssue = initialIssue ?? Self.debugIssue {
            issue = forcedIssue
            return
        }
        if Self.debugBarcode != nil {
            return
        }

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if let authorizationIssue = Self.issue(for: authorizationStatus) {
            issue = authorizationIssue
        } else if authorizationStatus == .notDetermined {
            requestCameraAccess()
        } else {
            startAuthorizedScanner()
        }
    }

    private func requestCameraAccess() {
        guard !isRequestingCameraAccess else { return }
        isRequestingCameraAccess = true

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.isRequestingCameraAccess = false
                guard self.isPresented else { return }
                if granted {
                    self.startAuthorizedScanner()
                } else {
                    self.issue = .cameraPermissionDenied
                }
            }
        }
    }

    private func startAuthorizedScanner() {
        guard DataScannerViewController.isSupported else {
            issue = .unsupported
            return
        }
        guard DataScannerViewController.isAvailable else {
            issue = .temporarilyUnavailable
            return
        }
        shouldStartScanner = true
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    static func issue(for authorizationStatus: AVAuthorizationStatus) -> BarcodeScannerIssue? {
        switch authorizationStatus {
        case .denied, .restricted:
            .cameraPermissionDenied
        case .authorized, .notDetermined:
            nil
        @unknown default:
            .temporarilyUnavailable
        }
    }

    private static var debugBarcode: String? {
#if DEBUG || RELEASE_VALIDATION
        ProcessInfo.processInfo.arguments.contains("-scanner-success") ? "12345678" : nil
#else
        nil
#endif
    }

    private static var debugIssue: BarcodeScannerIssue? {
#if DEBUG || RELEASE_VALIDATION
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-scanner-permission-denied") {
            return .cameraPermissionDenied
        }
        if arguments.contains("-scanner-unsupported") {
            return .unsupported
        }
        if arguments.contains("-scanner-temporarily-unavailable") {
            return .temporarilyUnavailable
        }
#endif
        return nil
    }
}

#if DEBUG || RELEASE_VALIDATION
#Preview("Scanner permission denied") {
    BarcodeScannerView(
        isPresented: .constant(true),
        onScan: { _ in },
        onEnterManually: {},
        initialIssue: .cameraPermissionDenied
    )
}
#endif

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onIssue: (BarcodeScannerIssue) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onIssue: onIssue)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let operation = AppLogger.begin(
            "scanner.start",
            category: .scanner,
            source: "camera"
        )
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

        guard DataScannerViewController.isSupported else {
            AppLogger.noop(operation, reason: "unsupported")
            context.coordinator.reportIssue(.unsupported)
            return scanner
        }
        guard DataScannerViewController.isAvailable else {
            AppLogger.noop(operation, reason: "temporarily_unavailable")
            context.coordinator.reportIssue(.temporarilyUnavailable)
            return scanner
        }

        do {
            try scanner.startScanning()
            AppLogger.succeed(operation)
        } catch {
            AppLogger.fail(operation, error: error)
            context.coordinator.reportIssue(.temporarilyUnavailable)
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private let onIssue: (BarcodeScannerIssue) -> Void
        private var didScanBarcode = false

        init(
            onScan: @escaping (String) -> Void,
            onIssue: @escaping (BarcodeScannerIssue) -> Void = { _ in }
        ) {
            self.onScan = onScan
            self.onIssue = onIssue
        }

        func reportIssue(_ issue: BarcodeScannerIssue) {
            DispatchQueue.main.async {
                self.onIssue(issue)
            }
        }

        func handleScannedBarcode(_ value: String) {
            guard !didScanBarcode else { return }
            didScanBarcode = true

            DispatchQueue.main.async {
                self.onScan(value)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard case let .barcode(code) = addedItems.first, let value = code.payloadStringValue else { return }
            handleScannedBarcode(value)
        }
    }
}
