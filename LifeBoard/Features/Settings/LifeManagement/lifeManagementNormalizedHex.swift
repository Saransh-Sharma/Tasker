import SwiftUI
import UIKit

func lifeManagementNormalizedHex(_ hex: String) -> String {
    hex.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
        .uppercased()
}
