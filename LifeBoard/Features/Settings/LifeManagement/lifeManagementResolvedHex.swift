import SwiftUI
import UIKit

func lifeManagementResolvedHex(_ hex: String?) -> String? {
    let normalized = lifeManagementNormalizedHex(hex ?? "")
    guard normalized.isEmpty == false, normalized.count == 6 || normalized.count == 8 else {
        return nil
    }
    return normalized
}
