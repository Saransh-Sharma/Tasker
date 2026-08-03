import Foundation

private final class HealthObserverCompletion: @unchecked Sendable {
    private let completion: () -> Void

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    func call() {
        completion()
    }
}

public final class HealthObserverCoordinator: @unchecked Sendable {
    private let gateway: any HealthKitGatewayProtocol
    private let lock = NSLock()
    private var engine: HealthSyncEngine?
    private var dirtyMetrics = Set<HealthMetric>()
    private var installed = false

    public init(gateway: any HealthKitGatewayProtocol) {
        self.gateway = gateway
    }

    public func installObservers() {
        let shouldInstall = lock.withLock {
            guard installed == false else { return false }
            installed = true
            return true
        }
        guard shouldInstall else { return }

        for metric in HealthKitTypeCatalog.readableMetrics {
            gateway.installObserver(metric: metric) { [weak self] completion in
                let completionBox = HealthObserverCompletion(completion)
                guard let self else {
                    completionBox.call()
                    return
                }
                Task {
                    await self.handle(metric: metric)
                    completionBox.call()
                }
            }
            Task {
                try? await gateway.enableBackgroundDelivery(for: metric)
            }
        }
    }

    public func attach(engine: HealthSyncEngine) {
        let buffered = lock.withLock {
            self.engine = engine
            let result = dirtyMetrics
            dirtyMetrics.removeAll()
            return result
        }
        guard buffered.isEmpty == false else { return }
        Task {
            _ = try? await engine.refresh(metrics: buffered)
        }
    }

    private func handle(metric: HealthMetric) async {
        let engine = lock.withLock {
            let result = self.engine
            if result == nil {
                dirtyMetrics.insert(metric)
            }
            return result
        }
        guard let engine else { return }
        _ = try? await engine.refresh(metrics: [metric])
    }
}
