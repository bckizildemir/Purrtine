import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct InFlightMainActorOperationTests {
    @Test
    func overlappingCallersShareOneOperationAndCoordinatorCanBeReused() async {
        let sut = InFlightMainActorOperation()
        let probe = MainActorOperationProbe()

        let first = Task {
            await sut.run { await probe.perform() }
        }
        await sut.waitUntilRequestCount(1)
        await probe.waitUntilStarted()

        let second = Task {
            await sut.run { await probe.perform() }
        }
        let third = Task {
            await sut.run { await probe.perform() }
        }
        await sut.waitUntilRequestCount(3)

        #expect(probe.callCount == 1)
        probe.release()
        await first.value
        await second.value
        await third.value

        await sut.run { probe.performWithoutSuspending() }
        #expect(probe.callCount == 2)
    }
}

@MainActor
private final class MainActorOperationProbe {
    private(set) var callCount = 0
    private var isStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func perform() async {
        callCount += 1
        isStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters = []
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func performWithoutSuspending() {
        callCount += 1
    }

    func waitUntilStarted() async {
        if isStarted { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
