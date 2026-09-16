import UIKit

/// Bounded, appearance-aware cache shared by Home and feature surfaces.
/// UIKit prepares pixels off the main thread; concurrent requests share that work.
@MainActor
final class HomeSceneImageCache {
    static let shared = HomeSceneImageCache()
    private let images = NSCache<NSString, UIImage>()
    private var pending: [String: Task<UIImage?, Never>] = [:]
    private(set) var preparationCount = 0
    #if DEBUG
    private var cacheHitCount = 0
    private var coalescedLoadCount = 0
    private var knownKeys: Set<String> = []

    /// Explicit evidence reads only. Keys contain no user content; inspecting
    /// NSCache does not retain images or turn its eviction budget into a cap.
    var designEvidenceSnapshot: [String: Int] {
        let resident = knownKeys.compactMap { images.object(forKey: $0 as NSString) }
        return ["preparations": preparationCount, "cacheHits": cacheHitCount,
                "coalescedLoads": coalescedLoadCount, "pendingLoads": pending.count,
                "residentImages": resident.count,
                "residentDecodedBytes": resident.reduce(0) { total, image in
                    total + (image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
                }]
    }
    #endif

    init() {
        images.totalCostLimit = 32 * 1024 * 1024
        images.countLimit = 48
    }

    func key(kind: DashboardWidgetKind, dark: Bool, assetName: String? = nil) -> String {
        "\(assetName ?? "HomeCardScene_\(kind.rawValue)")|\(dark ? "dark" : "light")"
    }

    func cached(kind: DashboardWidgetKind, dark: Bool, assetName: String? = nil) -> UIImage? {
        images.object(forKey: key(kind: kind, dark: dark, assetName: assetName) as NSString)
    }

    func load(kind: DashboardWidgetKind, dark: Bool, assetName: String? = nil) async -> UIImage? {
        let key = key(kind: kind, dark: dark, assetName: assetName)
        if let image = images.object(forKey: key as NSString) {
            #if DEBUG
            cacheHitCount += 1
            #endif
            return image
        }
        if let task = pending[key] {
            #if DEBUG
            coalescedLoadCount += 1
            #endif
            return await task.value
        }
        #if DEBUG
        knownKeys.insert(key)
        #endif
        let task = Task { @MainActor [weak self] () -> UIImage? in
            let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            guard let source = UIImage(named: assetName ?? "HomeCardScene_\(kind.rawValue)", in: .main, compatibleWith: traits) else { return nil }
            let image = await source.byPreparingForDisplay() ?? source
            self?.preparationCount += 1
            let bytes = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            self?.images.setObject(image, forKey: key as NSString, cost: bytes)
            return image
        }
        pending[key] = task
        let image = await task.value
        pending[key] = nil
        return image
    }
}
