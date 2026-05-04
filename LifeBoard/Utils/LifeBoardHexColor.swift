import SwiftUI
import UIKit

enum TaskerHexColor {
    static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let rawHex: String
        if trimmed.hasPrefix("#") {
            rawHex = String(trimmed.dropFirst())
        } else {
            rawHex = trimmed
        }

        guard rawHex.count == 6 else { return nil }
        let normalized = rawHex.uppercased()
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard normalized.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return "#\(normalized)"
    }

    static func color(_ value: String?, fallback: Color) -> Color {
        guard let normalized = Self.normalized(value) else { return fallback }
        return Color(uiColor: UIColor(taskerHex: normalized))
    }
}
