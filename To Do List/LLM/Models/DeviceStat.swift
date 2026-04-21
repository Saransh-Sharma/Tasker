//
//  DeviceStat.swift
//
//

import Foundation
import MLXLLM
import MLX

@Observable
final class DeviceStat: @unchecked Sendable {

    @MainActor
    var gpuUsage = Memory.snapshot()

    private let initialGPUSnapshot = Memory.snapshot()
    private var timer: Timer?

    /// Initializes a new instance.
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateGPUUsages()
        }
    }

    deinit {
        timer?.invalidate()
    }

    /// Executes updateGPUUsages.
    private func updateGPUUsages() {
        let gpuSnapshotDelta = initialGPUSnapshot.delta(Memory.snapshot())
        DispatchQueue.main.async { [weak self] in
            self?.gpuUsage = gpuSnapshotDelta
        }
    }

}
