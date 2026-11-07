import Foundation

@MainActor
final class InFlightMainActorOperation {
    private struct State {
        let token: UUID
        let task: Task<Void, Never>
    }

    private struct RequestCountWaiter {
        let target: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var state: State?
    private var requestCount = 0
    private var requestCountWaiters: [RequestCountWaiter] = []

    func run(_ operation: @escaping @MainActor () async -> Void) async {
        registerRequest()
        defer { requestCount -= 1 }

        if let task = state?.task {
            await task.value
            return
        }

        let token = UUID()
        let task = Task { @MainActor in
            await operation()
        }
        state = State(token: token, task: task)
        await task.value
        if state?.token == token {
            state = nil
        }
    }

    func waitUntilRequestCount(_ target: Int) async {
        guard requestCount < target else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters.append(
                RequestCountWaiter(target: target, continuation: continuation)
            )
        }
    }

    private func registerRequest() {
        requestCount += 1
        var remainingWaiters: [RequestCountWaiter] = []
        for waiter in requestCountWaiters {
            if requestCount >= waiter.target {
                waiter.continuation.resume()
            } else {
                remainingWaiters.append(waiter)
            }
        }
        requestCountWaiters = remainingWaiters
    }
}
