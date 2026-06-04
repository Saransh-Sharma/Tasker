import UIKit

struct DeviceOrientationPolicyResolver {
    func supportedOrientations(for idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        switch idiom {
        case .pad, .mac:
            return .all
        default:
            return [.portrait, .portraitUpsideDown]
        }
    }
}
