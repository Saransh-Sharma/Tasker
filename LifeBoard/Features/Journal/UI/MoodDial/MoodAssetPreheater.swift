import Foundation

#if canImport(UIKit)
import UIKit

public enum MoodAssetPreheater {
    private static let lock = NSLock()
    private static var didPreheat = false
    private static let queue = DispatchQueue(label: "mood-dial-kit.mood-preheater", qos: .userInitiated)

    public static func preheatMoodAssets() {
        lock.lock()
        let shouldPreheat = !didPreheat
        didPreheat = true
        lock.unlock()

        guard shouldPreheat else { return }

        MoodDialSignposts.event("MoodAssetPreheatScheduled")
        let assetNames = Set(
            Mood.dialMoods.map { mood in
                mood.dialFaceAssetName
            }
        )

        queue.async {
            let token = MoodDialSignposts.begin("MoodAssetPreheat")
            for name in assetNames {
                autoreleasepool {
                    _ = UIImage(named: name, in: .module, with: nil)?.preparingForDisplay()
                }
            }
            MoodDialSignposts.end(token)
        }
    }

    #if DEBUG
    public static func resetForTesting() {
        lock.lock()
        didPreheat = false
        lock.unlock()
    }
    #endif
}
#else
public enum MoodAssetPreheater {
    public static func preheatMoodAssets() {}
}
#endif
