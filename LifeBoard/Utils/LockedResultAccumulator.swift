//
//  LockedResultAccumulator.swift
//

import Foundation

final class LockedResultAccumulator<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State
    private var firstError: Error?

    init(_ state: State) {
        self.state = state
    }

    func update(_ body: @Sendable (inout State) -> Void) {
        lock.lock()
        body(&state)
        lock.unlock()
    }

    func record(_ error: Error) {
        lock.lock()
        if firstError == nil {
            firstError = error
        }
        lock.unlock()
    }

    func snapshot() -> State {
        lock.lock()
        let state = state
        lock.unlock()
        return state
    }

    func result() -> Result<State, Error> {
        lock.lock()
        let state = state
        let firstError = firstError
        lock.unlock()

        if let firstError {
            return .failure(firstError)
        }
        return .success(state)
    }
}
