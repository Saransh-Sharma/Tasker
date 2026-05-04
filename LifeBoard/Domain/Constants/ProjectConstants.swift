//
//  ProjectConstants.swift
//  LifeBoard
//
//  Domain constants for Project management
//

import Foundation

/// Constants related to project management
public struct ProjectConstants {
    /// Fixed UUID for the Inbox project
    /// This UUID never changes and represents the default project for all tasks
    public static let inboxProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Name of the default Inbox project
    public static let inboxProjectName = "Inbox"

    /// Description of the Inbox project
    public static let inboxProjectDescription = "Default project for uncategorized tasks"

    /// Initializes a new instance.
    private init() {
        // Prevent instantiation of constants struct
    }
}

/// Constants related to life-area seeding and defaults.
public struct LifeAreaConstants {
    public static let generalSeedColor = "#9E5F0A"

    /// Initializes a new instance.
    private init() {
        // Prevent instantiation of constants struct
    }
}

/// Shared life-area color resolver backed by the habit accent palette.
public struct LifeAreaColorPalette {
    public enum ResolutionReason: Equatable {
        case exactPaletteMatch
        case mappedLegacy
        case missingOrInvalid
    }

    public struct Resolution: Equatable {
        public let hex: String
        public let reason: ResolutionReason
    }

    public static var paletteHexes: [String] {
        HabitColorFamily.allCases.map(\.canonicalHex)
    }

    /// Returns a stable default color derived from UUID bytes.
    public static func defaultHex(for lifeAreaID: UUID) -> String {
        let palette = paletteHexes
        guard palette.isEmpty == false else {
            return HabitColorFamily.green.canonicalHex
        }

        let bytes = uuidBytes(lifeAreaID)
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }

        let index = Int(hash % UInt64(palette.count))
        return palette[index]
    }

    public static func normalizeOrMap(hex: String?, for lifeAreaID: UUID) -> String {
        resolve(hex: hex, for: lifeAreaID).hex
    }

    public static func resolve(hex: String?, for lifeAreaID: UUID) -> Resolution {
        let palette = paletteHexes
        guard palette.isEmpty == false else {
            return Resolution(hex: HabitColorFamily.green.canonicalHex, reason: .missingOrInvalid)
        }

        guard let normalized = normalizedHex(hex) else {
            return Resolution(hex: defaultHex(for: lifeAreaID), reason: .missingOrInvalid)
        }

        if let exact = palette.first(where: { $0 == normalized }) {
            return Resolution(hex: exact, reason: .exactPaletteMatch)
        }

        guard let mapped = nearestPaletteHex(for: normalized, palette: palette) else {
            return Resolution(hex: defaultHex(for: lifeAreaID), reason: .missingOrInvalid)
        }
        return Resolution(hex: mapped, reason: .mappedLegacy)
    }

    private static func nearestPaletteHex(for normalizedHex: String, palette: [String]) -> String? {
        guard let source = rgbComponents(for: normalizedHex) else { return nil }
        var bestHex: String?
        var bestDistance = Int.max

        for hex in palette {
            guard let candidate = rgbComponents(for: hex) else { continue }
            let distance =
                squaredDistance(source.r, candidate.r) +
                squaredDistance(source.g, candidate.g) +
                squaredDistance(source.b, candidate.b)
            if distance < bestDistance {
                bestDistance = distance
                bestHex = hex
            }
        }

        return bestHex
    }

    private static func squaredDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let delta = lhs - rhs
        return delta * delta
    }

    private static func rgbComponents(for normalizedHex: String) -> (r: Int, g: Int, b: Int)? {
        guard normalizedHex.count == 7 else { return nil }
        let rString = String(normalizedHex.dropFirst().prefix(2))
        let gString = String(normalizedHex.dropFirst(3).prefix(2))
        let bString = String(normalizedHex.dropFirst(5).prefix(2))
        guard
            let r = Int(rString, radix: 16),
            let g = Int(gString, radix: 16),
            let b = Int(bString, radix: 16)
        else {
            return nil
        }
        return (r, g, b)
    }

    private static func normalizedHex(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let rawHex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard rawHex.count == 6 else { return nil }

        let normalized = rawHex.uppercased()
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard normalized.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return "#\(normalized)"
    }

    private static func uuidBytes(_ id: UUID) -> [UInt8] {
        let tuple = id.uuid
        return [
            tuple.0, tuple.1, tuple.2, tuple.3,
            tuple.4, tuple.5, tuple.6, tuple.7,
            tuple.8, tuple.9, tuple.10, tuple.11,
            tuple.12, tuple.13, tuple.14, tuple.15
        ]
    }
}
