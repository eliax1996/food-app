import Foundation
import Observation

nonisolated enum MealDictationFailure: Error, Equatable, Sendable {
    case operatingSystem
    case unsupportedLocale
    case permissionDenied
    case assetsUnavailable
    case noInputDevice
    case interrupted
    case resourcesUnavailable
    case unknown
}

nonisolated enum MealDictationState: Equatable, Sendable {
    case idle
    case requestingPermission
    case preparingAssets
    case listening(finalized: String, volatile: String)
    case finishing
    case failed(MealDictationFailure)
}

nonisolated enum MealMicrophoneAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

typealias MealDictationUpdate = @MainActor @Sendable (MealDictationState) -> Void

nonisolated protocol MealDictationServicing: Sendable {
    func start(locale: Locale) async
    func stop() async
    func cancel() async
}

nonisolated protocol MealDictationServiceMaking: Sendable {
    var isSupported: Bool { get }

    func make(update: @escaping MealDictationUpdate) async -> any MealDictationServicing
    func microphoneAuthorization() async -> MealMicrophoneAuthorization
}

@MainActor
@Observable
final class MealDictationController {
    private(set) var state: MealDictationState = .idle
    private(set) var latestFinalizedText = ""

    @ObservationIgnored private let factory: any MealDictationServiceMaking
    @ObservationIgnored private var service: (any MealDictationServicing)?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var operation: Operation = .none

    private enum Operation: Equatable {
        case none
        case starting
        case stopping
    }

    init(factory: any MealDictationServiceMaking = MealDictationServiceFactories.make()) {
        self.factory = factory
    }

    var currentFinalizedText: String {
        if case .listening(let finalized, _) = state { return finalized }
        return latestFinalizedText
    }

    var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    var isSupported: Bool { factory.isSupported }

    var canToggle: Bool {
        guard isSupported, operation == .none else { return false }
        switch state {
        case .idle, .listening, .failed:
            return true
        case .requestingPermission, .preparingAssets, .finishing:
            return false
        }
    }

    var needsMicrophoneSettings: Bool {
        if case .failed(.permissionDenied) = state { return true }
        return false
    }

    var hasActiveRequest: Bool {
        switch state {
        case .requestingPermission, .preparingAssets, .listening, .finishing:
            return true
        case .idle, .failed:
            return false
        }
    }

    func start(locale: Locale = .current) async {
        guard factory.isSupported, operation == .none else { return }
        switch state {
        case .requestingPermission, .preparingAssets, .listening, .finishing:
            return
        case .idle, .failed:
            break
        }

        generation &+= 1
        latestFinalizedText = ""
        let requestGeneration = generation
        operation = .starting
        state = .requestingPermission

        if let previousService = service {
            service = nil
            await previousService.cancel()
            guard generation == requestGeneration, operation == .starting else { return }
        }

        let newService = await factory.make { [weak self] newState in
            guard let self, self.generation == requestGeneration else { return }
            if case .listening(let finalized, _) = newState, !finalized.isEmpty {
                self.latestFinalizedText = finalized
            }
            self.state = newState
        }
        guard generation == requestGeneration, operation == .starting else {
            await newService.cancel()
            return
        }

        service = newService
        await newService.start(locale: locale)
        guard generation == requestGeneration, operation == .starting else { return }
        operation = .none
    }

    func stop() async {
        guard operation == .none, case .listening = state, let service else { return }
        operation = .stopping
        state = .finishing
        let requestGeneration = generation
        await service.stop()
        guard generation == requestGeneration, operation == .stopping else { return }
        self.service = nil
        operation = .none
        if case .failed = state {
            return
        }
        state = .idle
    }

    func cancel() async {
        guard operation != .none || service != nil || state != .idle else { return }
        generation &+= 1
        let service = self.service
        self.service = nil
        operation = .stopping
        await service?.cancel()
        operation = .none
        state = .idle
    }

    func refreshPermissionStatus() async {
        guard case .failed(.permissionDenied) = state else { return }
        if await factory.microphoneAuthorization() == .authorized {
            state = .idle
        }
    }
}

nonisolated enum MealDictationServiceFactories {
    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> any MealDictationServiceMaking {
#if DEBUG
        if arguments.contains("-ui-testing-dictation-denied") {
            return FixtureMealDictationServiceFactory(scenario: .denied)
        }
        if arguments.contains("-ui-testing-dictation-interrupted") {
            return FixtureMealDictationServiceFactory(scenario: .interrupted)
        }
        if arguments.contains("-ui-testing-dictation-backpressure") {
            return FixtureMealDictationServiceFactory(scenario: .backpressure)
        }
#endif
#if canImport(Speech) && canImport(AVFoundation)
        return SystemMealDictationServiceFactory()
#else
        return UnsupportedMealDictationServiceFactory()
#endif
    }
}

private nonisolated struct UnsupportedMealDictationServiceFactory: MealDictationServiceMaking {
    let isSupported = false

    func make(update: @escaping MealDictationUpdate) async -> any MealDictationServicing {
        UnsupportedMealDictationService(update: update)
    }

    func microphoneAuthorization() async -> MealMicrophoneAuthorization { .denied }
}

private actor UnsupportedMealDictationService: MealDictationServicing {
    private let update: MealDictationUpdate
    private var finished = false

    init(update: @escaping MealDictationUpdate) {
        self.update = update
    }

    func start(locale: Locale) async {
        guard !finished else { return }
        finished = true
        await update(.failed(.operatingSystem))
    }

    func stop() async { await finish() }
    func cancel() async { await finish() }

    private func finish() async {
        guard !finished else { return }
        finished = true
        await update(.idle)
    }
}

#if DEBUG
private nonisolated enum FixtureMealDictationScenario: Equatable, Sendable {
    case denied
    case interrupted
    case backpressure
}

private nonisolated struct FixtureMealDictationServiceFactory: MealDictationServiceMaking {
    let scenario: FixtureMealDictationScenario
    let isSupported = true

    func make(update: @escaping MealDictationUpdate) async -> any MealDictationServicing {
        FixtureMealDictationService(scenario: scenario, update: update)
    }

    func microphoneAuthorization() async -> MealMicrophoneAuthorization {
        scenario == .denied ? .denied : .authorized
    }
}

private actor FixtureMealDictationService: MealDictationServicing {
    private let scenario: FixtureMealDictationScenario
    private let update: MealDictationUpdate
    private var finished = false

    init(scenario: FixtureMealDictationScenario, update: @escaping MealDictationUpdate) {
        self.scenario = scenario
        self.update = update
    }

    func start(locale: Locale) async {
        guard !finished else { return }
        await update(.requestingPermission)
        await Task.yield()
        guard !finished else { return }

        if scenario == .denied {
            finished = true
            await update(.failed(.permissionDenied))
            return
        }

        await update(.listening(finalized: "", volatile: "fixture dictated meal"))
        await Task.yield()
        guard !finished else { return }
        await update(.listening(finalized: "dictated banana", volatile: ""))
        try? await Task.sleep(for: .milliseconds(250))
        guard !finished else { return }
        finished = true
        switch scenario {
        case .interrupted:
            await update(.failed(.interrupted))
        case .backpressure:
            await update(.failed(.resourcesUnavailable))
        case .denied:
            await update(.failed(.permissionDenied))
        }
    }

    func stop() async {
        guard !finished else { return }
        finished = true
        await update(.finishing)
        await update(.idle)
    }

    func cancel() async {
        guard !finished else { return }
        finished = true
        await update(.idle)
    }
}
#endif

#if canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech

private nonisolated struct SystemMealDictationServiceFactory: MealDictationServiceMaking {
    let isSupported: Bool

    init() {
        if #available(iOS 26.0, *) {
            isSupported = SpeechTranscriber.isAvailable
        } else {
            isSupported = false
        }
    }

    func make(update: @escaping MealDictationUpdate) async -> any MealDictationServicing {
        guard #available(iOS 26.0, *) else {
            return UnsupportedMealDictationService(update: update)
        }
        return SystemMealDictationService(update: update)
    }

    func microphoneAuthorization() async -> MealMicrophoneAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }
}

@available(iOS 26.0, *)
nonisolated final class MealAudioBufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private let targetFormat: AVAudioFormat
    private let onDropped: @Sendable () -> Void
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var converter: AVAudioConverter?
    private var terminated = false
    private var reportedDrop = false

    init(
        targetFormat: AVAudioFormat,
        continuation: AsyncStream<AnalyzerInput>.Continuation,
        onDropped: @escaping @Sendable () -> Void
    ) {
        self.targetFormat = targetFormat
        self.continuation = continuation
        self.onDropped = onDropped
    }

    func consume(_ buffer: AVAudioPCMBuffer) {
        var shouldReportDrop = false
        lock.lock()
        if !terminated, let continuation {
            do {
                let converted = try convertLocked(buffer)
                switch continuation.yield(AnalyzerInput(buffer: converted)) {
                case .dropped:
                    shouldReportDrop = markDropLocked()
                case .terminated:
                    terminated = true
                    self.continuation = nil
                    converter = nil
                case .enqueued:
                    break
                @unknown default:
                    shouldReportDrop = markDropLocked()
                }
            } catch {
                shouldReportDrop = markDropLocked()
            }
        }
        lock.unlock()
        if shouldReportDrop { onDropped() }
    }

    func reportDroppedBuffer() {
        lock.lock()
        let shouldReportDrop = !terminated && markDropLocked()
        lock.unlock()
        if shouldReportDrop { onDropped() }
    }

    func finish() {
        lock.lock()
        guard !terminated else {
            lock.unlock()
            return
        }
        terminated = true
        let continuation = continuation
        self.continuation = nil
        converter = nil
        lock.unlock()
        continuation?.finish()
    }

    private func markDropLocked() -> Bool {
        guard !reportedDrop else { return false }
        reportedDrop = true
        return true
    }

    private func convertLocked(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard buffer.format != targetFormat else { return buffer }
        if converter?.inputFormat != buffer.format || converter?.outputFormat != targetFormat {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
            converter?.primeMethod = .none
        }
        guard let converter else { throw MealDictationFailure.resourcesUnavailable }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: max(1, capacity)
        ) else {
            throw MealDictationFailure.resourcesUnavailable
        }
        var conversionError: NSError?
        var supplied = false
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error else {
            if let conversionError { throw conversionError }
            throw MealDictationFailure.resourcesUnavailable
        }
        return output
    }
}

@available(iOS 26.0, *)
private actor SystemMealDictationService: MealDictationServicing {
    private enum Lifecycle: Equatable {
        case idle
        case starting
        case running
        case tearingDown(finalizing: Bool)
        case finished
    }

    private let update: MealDictationUpdate
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var audioSink: MealAudioBufferSink?
    private var resultTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var finalized = ""
    private var lifecycle: Lifecycle = .idle
    private var tapInstalled = false
    private var audioSessionActive = false

    init(update: @escaping MealDictationUpdate) {
        self.update = update
    }

    func start(locale: Locale) async {
        guard lifecycle == .idle else { return }
        lifecycle = .starting
        await update(.requestingPermission)

        do {
            guard await microphoneAllowed() else {
                await fail(.permissionDenied)
                return
            }
            guard lifecycle == .starting else { return }
            guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
                await fail(.unsupportedLocale)
                return
            }
            guard lifecycle == .starting else { return }

            await update(.preparingAssets)
            let transcriber = SpeechTranscriber(
                locale: supportedLocale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults],
                attributeOptions: []
            )
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            try Task.checkCancellation()
            guard lifecycle == .starting else { return }

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber]
            ) else {
                throw MealDictationFailure.resourcesUnavailable
            }
            guard lifecycle == .starting else { return }

            let (sequence, continuation) = AsyncStream<AnalyzerInput>.makeStream(
                bufferingPolicy: .bufferingNewest(24)
            )
            let sink = MealAudioBufferSink(
                targetFormat: analyzerFormat,
                continuation: continuation
            ) { [weak self] in
                Task { await self?.fail(.resourcesUnavailable) }
            }
            self.analyzer = analyzer
            audioSink = sink
            resultTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        await self?.receive(
                            text: String(result.text.characters),
                            isFinal: result.isFinal
                        )
                    }
                } catch is CancellationError {
                } catch {
                    Task { await self?.fail(.resourcesUnavailable) }
                }
            }

            try configureAudioSession()
            installNotificationObservers()
            try installTap(sink: sink)
            audioEngine.prepare()
            try audioEngine.start()
            try await analyzer.start(inputSequence: sequence)
            guard lifecycle == .starting else { return }

            lifecycle = .running
            await update(.listening(finalized: finalized, volatile: ""))
            timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
                await self?.stop()
            }
        } catch is CancellationError {
            await cancel()
        } catch let failure as MealDictationFailure {
            await fail(failure)
        } catch {
            await fail(.assetsUnavailable)
        }
    }

    func stop() async {
        guard lifecycle == .running || lifecycle == .starting else { return }
        lifecycle = .tearingDown(finalizing: true)
        await update(.finishing)
        await tearDown(finalize: true)
        lifecycle = .finished
        await update(.idle)
    }

    func cancel() async {
        guard lifecycle != .finished, !isTearingDown else { return }
        lifecycle = .tearingDown(finalizing: false)
        await tearDown(finalize: false)
        lifecycle = .finished
    }

    private var isTearingDown: Bool {
        if case .tearingDown = lifecycle { return true }
        return false
    }

    private func receive(text: String, isFinal: Bool) async {
        let acceptsResult = lifecycle == .starting
            || lifecycle == .running
            || lifecycle == .tearingDown(finalizing: true)
        guard acceptsResult else { return }
        if isFinal {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !finalized.isEmpty, !finalized.hasSuffix(" ") { finalized.append(" ") }
            finalized.append(trimmed)
            await update(.listening(finalized: finalized, volatile: ""))
        } else {
            await update(.listening(finalized: finalized, volatile: text))
        }
    }

    private func fail(_ failure: MealDictationFailure) async {
        guard lifecycle != .finished, !isTearingDown else { return }
        lifecycle = .tearingDown(finalizing: false)
        await tearDown(finalize: false)
        lifecycle = .finished
        await update(.failed(failure))
    }

    private func microphoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func configureAudioSession() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        audioSessionActive = true
#endif
    }

    private func installNotificationObservers() {
#if os(iOS)
        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: nil
            ) { [weak self] notification in
                guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      typeValue == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { await self?.fail(.interrupted) }
            },
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: nil
            ) { [weak self] _ in
                Task { await self?.fail(.interrupted) }
            }
        ]
#endif
    }

    private func installTap(sink: MealAudioBufferSink) throws {
        let input = audioEngine.inputNode
        let sourceFormat = input.outputFormat(forBus: 0)
        guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0 else {
            throw MealDictationFailure.noInputDevice
        }
        input.installTap(onBus: 0, bufferSize: 2_048, format: sourceFormat) { buffer, _ in
            sink.consume(buffer)
        }
        tapInstalled = true
    }

    private func tearDown(finalize: Bool) async {
        timeoutTask?.cancel()
        timeoutTask = nil

        let center = NotificationCenter.default
        for observer in notificationObservers { center.removeObserver(observer) }
        notificationObservers.removeAll()

        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioSink?.finish()
        audioSink = nil

        if let analyzer {
            if finalize {
                try? await analyzer.finalizeAndFinishThroughEndOfInput()
            } else {
                await analyzer.cancelAndFinishNow()
            }
        }

        let resultTask = resultTask
        self.resultTask = nil
        if !finalize {
            resultTask?.cancel()
        }
        _ = await resultTask?.value
        self.analyzer = nil

#if os(iOS)
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            audioSessionActive = false
        }
#endif
    }
}
#endif
