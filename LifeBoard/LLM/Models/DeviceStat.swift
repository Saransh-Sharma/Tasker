//
//  DeviceStat.swift
//
//

import Foundation
import MLXLLM
import MLX

private final class DeviceStatTimerBox {
    var timer: Timer?

    deinit {
        timer?.invalidate()
    }
}

@Observable
@MainActor
final class DeviceStat {

    var gpuUsage = Memory.snapshot()

    private let initialGPUSnapshot = Memory.snapshot()
    private let timerBox = DeviceStatTimerBox()

    /// Initializes a new instance.
    init() {
        timerBox.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateGPUUsages()
            }
        }
    }

    /// Executes updateGPUUsages.
    private func updateGPUUsages() {
        let gpuSnapshotDelta = initialGPUSnapshot.delta(Memory.snapshot())
        gpuUsage = gpuSnapshotDelta
    }

}
