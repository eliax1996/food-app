#if !SWIFT_PACKAGE
import AVFoundation
import Speech
import XCTest
@testable import count_calories

@MainActor
final class MealDictationServiceTests: XCTestCase {
    func testDuplicateStartIsRejectedWhileFirstStartIsRequesting() async {
        let gate = DictationStepGate()
        let factory = TestDictationFactory(scenarios: [.held(gate)])
        let controller = MealDictationController(factory: factory)

        let firstStart = Task { await controller.start(locale: Locale(identifier: "en_US")) }
        let firstStartReachedGate = await waitUntil { await gate.hasReached(0) }
        XCTAssertTrue(firstStartReachedGate)
        await controller.start(locale: Locale(identifier: "en_US"))

        let startCount = await factory.startCount()
        XCTAssertEqual(startCount, 1)
        XCTAssertEqual(controller.state, .requestingPermission)
        await gate.release(0)
        await firstStart.value
    }

    func testDeniedFixtureReportsPermissionFailureWithoutSystemAuthorization() async {
        let factory = MealDictationServiceFactories.make(arguments: [
            "count_calories",
            "-ui-testing-dictation-denied"
        ])
        let controller = MealDictationController(factory: factory)

        await controller.start(locale: Locale(identifier: "en_US"))

        XCTAssertTrue(controller.isSupported)
        XCTAssertEqual(controller.state, .failed(.permissionDenied))
        XCTAssertTrue(controller.needsMicrophoneSettings)
        XCTAssertTrue(controller.canToggle)
    }

    func testInterruptedFixtureForwardsFinalTextThenTruthfulFailure() async {
        let factory = MealDictationServiceFactories.make(arguments: [
            "count_calories",
            "-ui-testing-dictation-interrupted"
        ])
        let controller = MealDictationController(factory: factory)
        let start = Task { await controller.start(locale: Locale(identifier: "en_US")) }

        let receivedFinal = await waitUntil {
            controller.state == .listening(finalized: "dictated banana", volatile: "")
        }
        XCTAssertTrue(receivedFinal)
        await start.value

        XCTAssertEqual(controller.state, .failed(.interrupted))
    }

    func testBackpressureFixtureReportsResourcesUnavailable() async {
        let factory = MealDictationServiceFactories.make(arguments: [
            "count_calories",
            "-ui-testing-dictation-backpressure"
        ])
        let controller = MealDictationController(factory: factory)

        await controller.start(locale: Locale(identifier: "en_US"))

        XCTAssertEqual(controller.state, .failed(.resourcesUnavailable))
    }

    func testFailedRetryCancelsAndReleasesPriorServiceBeforeReplacementStarts() async {
        let factory = TestDictationFactory(scenarios: [.failure(.interrupted), .listening])
        let controller = MealDictationController(factory: factory)

        await controller.start()
        XCTAssertEqual(controller.state, .failed(.interrupted))
        await controller.start()

        XCTAssertEqual(controller.state, .listening(finalized: "second service", volatile: ""))
        let firstCancelCount = await factory.cancelCount(for: 0)
        let replacementOrderWasCorrect = await factory.secondServiceStartedAfterFirstCancellation()
        XCTAssertEqual(firstCancelCount, 1)
        XCTAssertTrue(replacementOrderWasCorrect)
    }

    func testStopAndCancelAreIdempotent() async {
        let stopFactory = TestDictationFactory(scenarios: [.listening])
        let stopController = MealDictationController(factory: stopFactory)
        await stopController.start()

        await stopController.stop()
        await stopController.stop()

        let stopCount = await stopFactory.stopCount(for: 0)
        XCTAssertEqual(stopCount, 1)
        XCTAssertEqual(stopController.state, .idle)

        let cancelFactory = TestDictationFactory(scenarios: [.listening])
        let cancelController = MealDictationController(factory: cancelFactory)
        await cancelController.start()

        await cancelController.cancel()
        await cancelController.cancel()

        let cancelCount = await cancelFactory.cancelCount(for: 0)
        XCTAssertEqual(cancelCount, 1)
        XCTAssertEqual(cancelController.state, .idle)
    }

    func testVolatileAndFinalStatesForwardInOrder() async {
        let gate = DictationStepGate()
        let factory = TestDictationFactory(scenarios: [.forwarding(gate)])
        let controller = MealDictationController(factory: factory)
        let start = Task { await controller.start() }

        let volatileReachedGate = await waitUntil { await gate.hasReached(0) }
        XCTAssertTrue(volatileReachedGate)
        XCTAssertEqual(controller.state, .listening(finalized: "", volatile: "banana"))

        await gate.release(0)
        let finalReachedGate = await waitUntil { await gate.hasReached(1) }
        XCTAssertTrue(finalReachedGate)
        XCTAssertEqual(controller.state, .listening(finalized: "banana", volatile: ""))

        await gate.release(1)
        await start.value
        XCTAssertEqual(controller.state, .failed(.interrupted))
    }

    @available(iOS 26.0, *)
    func testAudioSinkReportsDroppedBufferExactlyOnce() async throws {
        let format = try XCTUnwrap(AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        ))
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        _ = stream
        let drops = DictationCounter()
        let sink = MealAudioBufferSink(targetFormat: format, continuation: continuation) {
            Task { await drops.increment() }
        }
        sink.reportDroppedBuffer()
        sink.reportDroppedBuffer()
        sink.reportDroppedBuffer()

        let reportedDrop = await waitUntil { await drops.value() == 1 }
        XCTAssertTrue(reportedDrop)
        try await Task.sleep(for: .milliseconds(20))
        let dropCount = await drops.value()
        XCTAssertEqual(dropCount, 1)
        sink.finish()
        sink.reportDroppedBuffer()
        sink.finish()
    }

    func testPermissionRefreshOnlyClearsDenialWhenAuthorizationBecameAllowed() async {
        let authorization = TestAuthorization(.denied)
        let factory = TestDictationFactory(
            scenarios: [.failure(.permissionDenied)],
            authorization: authorization
        )
        let controller = MealDictationController(factory: factory)
        await controller.start()

        await controller.refreshPermissionStatus()
        XCTAssertEqual(controller.state, .failed(.permissionDenied))

        await authorization.set(.authorized)
        await controller.refreshPermissionStatus()
        XCTAssertEqual(controller.state, .idle)
        let makeCount = await factory.makeCount()
        XCTAssertEqual(makeCount, 1, "Refresh must inspect status without starting or prompting.")
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return await condition()
    }
}

private nonisolated enum TestDictationScenario: Sendable {
    case held(DictationStepGate)
    case failure(MealDictationFailure)
    case listening
    case forwarding(DictationStepGate)
}

private actor TestDictationFactory: MealDictationServiceMaking {
    nonisolated let isSupported = true
    private let scenarios: [TestDictationScenario]
    private let authorization: TestAuthorization
    private var services: [TestDictationService] = []
    private var replacementStartedAfterCancellation = false

    init(
        scenarios: [TestDictationScenario],
        authorization: TestAuthorization = TestAuthorization(.authorized)
    ) {
        self.scenarios = scenarios
        self.authorization = authorization
    }

    func make(update: @escaping MealDictationUpdate) async -> any MealDictationServicing {
        if services.count == 1 {
            replacementStartedAfterCancellation = await services[0].cancelCount() == 1
        }
        let index = services.count
        let scenario = scenarios[min(index, scenarios.count - 1)]
        let service = TestDictationService(scenario: scenario, update: update)
        services.append(service)
        return service
    }

    func microphoneAuthorization() async -> MealMicrophoneAuthorization {
        await authorization.value()
    }

    func makeCount() -> Int { services.count }

    func startCount() async -> Int {
        var total = 0
        for service in services { total += await service.startCount() }
        return total
    }

    func stopCount(for index: Int) async -> Int { await services[index].stopCount() }
    func cancelCount(for index: Int) async -> Int { await services[index].cancelCount() }
    func secondServiceStartedAfterFirstCancellation() -> Bool { replacementStartedAfterCancellation }
}

private actor TestDictationService: MealDictationServicing {
    private let scenario: TestDictationScenario
    private let update: MealDictationUpdate
    private var starts = 0
    private var stops = 0
    private var cancellations = 0

    init(scenario: TestDictationScenario, update: @escaping MealDictationUpdate) {
        self.scenario = scenario
        self.update = update
    }

    func start(locale: Locale) async {
        starts += 1
        switch scenario {
        case .held(let gate):
            await update(.requestingPermission)
            await gate.pause(at: 0)
        case .failure(let failure):
            await update(.requestingPermission)
            await update(.failed(failure))
        case .listening:
            await update(.requestingPermission)
            await update(.preparingAssets)
            await update(.listening(finalized: "second service", volatile: ""))
        case .forwarding(let gate):
            await update(.listening(finalized: "", volatile: "banana"))
            await gate.pause(at: 0)
            await update(.listening(finalized: "banana", volatile: ""))
            await gate.pause(at: 1)
            await update(.failed(.interrupted))
        }
    }

    func stop() async {
        stops += 1
        await update(.finishing)
        await update(.idle)
    }

    func cancel() async {
        cancellations += 1
        await update(.idle)
    }

    func startCount() -> Int { starts }
    func stopCount() -> Int { stops }
    func cancelCount() -> Int { cancellations }
}

private actor DictationStepGate {
    private var reached: Set<Int> = []
    private var released: Set<Int> = []
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]

    func pause(at step: Int) async {
        reached.insert(step)
        if released.remove(step) != nil { return }
        await withCheckedContinuation { continuation in
            waiters[step] = continuation
        }
    }

    func hasReached(_ step: Int) -> Bool { reached.contains(step) }

    func release(_ step: Int) {
        if let continuation = waiters.removeValue(forKey: step) {
            continuation.resume()
        } else {
            released.insert(step)
        }
    }
}

private actor DictationCounter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
}

private actor TestAuthorization {
    private var status: MealMicrophoneAuthorization

    init(_ status: MealMicrophoneAuthorization) {
        self.status = status
    }

    func value() -> MealMicrophoneAuthorization { status }
    func set(_ status: MealMicrophoneAuthorization) { self.status = status }
}
#endif
