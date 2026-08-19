import SwiftUI
import UIKit

/// Decodes the daypart artwork off the main thread before anything asks to draw it.
///
/// The six `Celestial*Background` imagesets are single 941×1672 1x-only PNGs, so
/// each one is a **6.29 MB** bitmap that then gets resampled 1.53× per axis to
/// fill a 3x phone. Nothing in the app cached or preheated them, which meant the
/// first draw of a phase paid a cold decode on whatever frame happened to need it
/// — and `Image(decorative:)` has no async-decode escape hatch to hide that.
///
/// `MoodAssetPreheater` already solved exactly this for the mood dial; this is the
/// same shape (idempotent behind a lock, `userInitiated` queue, `autoreleasepool`
/// per image so six 6 MB bitmaps do not stack in one pool) applied to the layer
/// that covers the entire screen.
///
/// Adjacent phases are included because the clock crosses a boundary while the app
/// is on screen and the daypart slider can jump to any phase at will; preheating
/// only the current one would just move the stall.
enum CelestialAssetPreheater {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var preheated: Set<String> = []
    private static let queue = DispatchQueue(
        label: "lifeboard.celestial-asset-preheater",
        qos: .userInitiated
    )

    /// Warms `phase` and the phases on either side of it in the daily cycle.
    static func preheat(around phase: CelestialPhase) {
        let names = assetNames(around: phase)

        lock.lock()
        let pending = names.subtracting(preheated)
        preheated.formUnion(pending)
        lock.unlock()

        guard pending.isEmpty == false else { return }

        queue.async {
            for name in pending {
                autoreleasepool {
                    _ = UIImage(named: name)?.preparingForDisplay()
                }
            }
        }
    }

    private static func assetNames(around phase: CelestialPhase) -> Set<String> {
        var names: Set<String> = []
        for phase in [phase] + neighbours(of: phase) {
            let descriptor = AtmosphereDescriptor.descriptor(for: phase)
            names.insert(descriptor.backgroundAsset)
            names.insert(descriptor.celestialAsset)
        }
        return names
    }

    /// The phases before and after `phase`, wrapping across midnight — the cycle
    /// is a ring, so night neighbours dawn.
    private static func neighbours(of phase: CelestialPhase) -> [CelestialPhase] {
        let order = CelestialPhase.allCases
        guard let index = order.firstIndex(of: phase), order.isEmpty == false else { return [] }
        let previous = order[(index - 1 + order.count) % order.count]
        let next = order[(index + 1) % order.count]
        return [previous, next]
    }

    #if DEBUG
    static func resetForTesting() {
        lock.lock()
        preheated.removeAll()
        lock.unlock()
    }
    #endif
}
