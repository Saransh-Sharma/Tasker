import UIKit
import Combine

public struct TaskerThemeSwatch {
    public let index: Int
    public let primary: UIColor
    public let secondary: UIColor
}

public struct TaskerAccentTheme {
    public let name: String
    public let accentBaseHex: String

    public init(name: String, accentBaseHex: String) {
        self.name = name
        self.accentBaseHex = accentBaseHex
    }
}

public struct TaskerAccentRamp {
    public let accent050: UIColor
    public let accent100: UIColor
    public let accent400: UIColor
    public let accent500: UIColor
    public let accent600: UIColor
    public let onAccent: UIColor
    public let ring: UIColor

    public init(base: UIColor) {
        let source = base.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let hsl = source.taskerHSL

        func build(sDelta: CGFloat, lDelta: CGFloat) -> UIColor {
            let saturation = TaskerAccentRamp.clamp(hsl.s + sDelta, min: 0.35, max: 0.95)
            let lightness = TaskerAccentRamp.clamp(hsl.l + lDelta, min: 0.10, max: 0.92)
            return UIColor(taskerHue: hsl.h, saturation: saturation, lightness: lightness, alpha: 1.0)
        }

        self.accent500 = source
        self.accent600 = build(sDelta: 0.05, lDelta: -0.10)
        self.accent400 = build(sDelta: -0.05, lDelta: 0.08)
        self.accent100 = build(sDelta: -0.25, lDelta: 0.35)
        self.accent050 = build(sDelta: -0.35, lDelta: 0.45)

        if source.taskerPerceivedLuminance > 0.72 {
            self.onAccent = UIColor(taskerHex: "#0E0F12")
        } else {
            self.onAccent = .white
        }

        self.ring = self.accent500.withAlphaComponent(0.40)
    }

    private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

public struct TaskerTheme: Equatable {
    public static let userDefaultsKey = "selectedThemeIndex"

    public static let accentThemes: [TaskerAccentTheme] = [
        TaskerAccentTheme(name: "Default", accentBaseHex: "#F08A2B"),
        TaskerAccentTheme(name: "Red Blossom", accentBaseHex: "#E84444"),
        TaskerAccentTheme(name: "Cloud", accentBaseHex: "#D1E9F6"),
        TaskerAccentTheme(name: "Periwinkle", accentBaseHex: "#8EA6E9"),
        TaskerAccentTheme(name: "Light Green", accentBaseHex: "#AFF8A2"),
        TaskerAccentTheme(name: "Mustard", accentBaseHex: "#F9D749"),
        TaskerAccentTheme(name: "Baby Blue", accentBaseHex: "#97CDE8"),
        TaskerAccentTheme(name: "Coral", accentBaseHex: "#EE7470"),
        TaskerAccentTheme(name: "Plum", accentBaseHex: "#D4A4DA")
    ]

    static let legacyThemeCount = 28
    static let legacyToCurrentIndexMap: [Int: Int] = [
        0: 0, 1: 1, 2: 2, 3: 3,
        4: 1, 5: 2, 6: 3,
        7: 4, 8: 4, 9: 4, 10: 4, 11: 4,
        12: 5, 13: 5, 14: 5, 15: 5, 16: 5,
        17: 6, 18: 6, 19: 6, 20: 6,
        21: 7, 22: 7, 23: 7,
        24: 8, 25: 8, 26: 8, 27: 8
    ]

    public let index: Int
    public let accentTheme: TaskerAccentTheme
    public let accentRamp: TaskerAccentRamp
    public let tokens: TaskerTokens

    public init(index: Int) {
        let clampedIndex = TaskerTheme.clampIndex(index)
        self.index = clampedIndex
        self.accentTheme = TaskerTheme.accentThemes[clampedIndex]

        let baseColor = UIColor(taskerHex: accentTheme.accentBaseHex)
        let ramp = TaskerAccentRamp(base: baseColor)
        self.accentRamp = ramp

        self.tokens = TaskerTokens(
            color: TaskerColorTokens.make(accentRamp: ramp),
            typography: TaskerTypographyTokens.makeDefault(),
            spacing: TaskerSpacingTokens.default,
            elevation: TaskerElevationTokens.default,
            corner: TaskerCornerTokens.default
        )
    }

    public static func == (lhs: TaskerTheme, rhs: TaskerTheme) -> Bool {
        lhs.index == rhs.index
    }

    public static func clampIndex(_ index: Int) -> Int {
        guard !accentThemes.isEmpty else { return 0 }
        return Swift.max(0, Swift.min(accentThemes.count - 1, index))
    }

    static func migrateLegacyIndex(_ index: Int) -> Int {
        if let migrated = legacyToCurrentIndexMap[index] {
            return migrated
        }
        return clampIndex(index)
    }
}

@MainActor
public final class TaskerThemeManager: ObservableObject {
    public static let shared = TaskerThemeManager()
    static let themeMigrationKey = "selectedThemeIndexMigrationVersion"
    static let themeMigrationVersion = 1

    @Published public private(set) var currentTheme: TaskerTheme
    private let userDefaults: UserDefaults

    public var publisher: AnyPublisher<TaskerTheme, Never> {
        $currentTheme
            .removeDuplicates(by: { $0.index == $1.index })
            .eraseToAnyPublisher()
    }

    public var selectedThemeIndex: Int {
        currentTheme.index
    }

    public var availableThemes: [TaskerAccentTheme] {
        TaskerTheme.accentThemes
    }

    public var availableThemeSwatches: [TaskerThemeSwatch] {
        TaskerTheme.accentThemes.indices.map { index in
            let theme = TaskerTheme(index: index)
            return TaskerThemeSwatch(
                index: index,
                primary: theme.tokens.color.accentPrimary,
                secondary: theme.tokens.color.accentMuted
            )
        }
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let persisted = Self.migratedPersistedThemeIndex(in: userDefaults)
        self.currentTheme = TaskerTheme(index: persisted)
    }

    public func selectTheme(index: Int) {
        let clamped = TaskerTheme.clampIndex(index)
        guard clamped != currentTheme.index else { return }

        userDefaults.set(clamped, forKey: TaskerTheme.userDefaultsKey)
        currentTheme = TaskerTheme(index: clamped)
    }

    public func reloadFromPersistence() {
        let persisted = Self.migratedPersistedThemeIndex(in: userDefaults)
        currentTheme = TaskerTheme(index: persisted)
    }

    static func migratedPersistedThemeIndex(in userDefaults: UserDefaults) -> Int {
        let hasPersistedTheme = userDefaults.object(forKey: TaskerTheme.userDefaultsKey) != nil
        let persisted = hasPersistedTheme ? userDefaults.integer(forKey: TaskerTheme.userDefaultsKey) : 0
        let migrationVersion = userDefaults.integer(forKey: themeMigrationKey)

        if migrationVersion < themeMigrationVersion {
            let migrated = TaskerTheme.migrateLegacyIndex(persisted)
            userDefaults.set(migrated, forKey: TaskerTheme.userDefaultsKey)
            userDefaults.set(themeMigrationVersion, forKey: themeMigrationKey)
            return migrated
        }

        return TaskerTheme.clampIndex(persisted)
    }

    public static var tokens: TaskerTokens {
        TaskerThemeManager.shared.currentTheme.tokens
    }
}

private extension UIColor {
    struct TaskerHSL {
        let h: CGFloat
        let s: CGFloat
        let l: CGFloat
    }

    var taskerHSL: TaskerHSL {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return TaskerHSL(h: 0, s: 0, l: 0)
        }

        let maxValue = Swift.max(red, green, blue)
        let minValue = Swift.min(red, green, blue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2

        let saturation: CGFloat
        if delta == 0 {
            saturation = 0
        } else {
            saturation = delta / (1 - abs(2 * lightness - 1))
        }

        let hue: CGFloat
        if delta == 0 {
            hue = 0
        } else if maxValue == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = ((blue - red) / delta) + 2
        } else {
            hue = ((red - green) / delta) + 4
        }

        let normalizedHue = ((hue * 60).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360

        return TaskerHSL(h: normalizedHue, s: saturation, l: lightness)
    }

    var taskerPerceivedLuminance: CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
        return (0.299 * red) + (0.587 * green) + (0.114 * blue)
    }
}

public extension UIColor {
    convenience init(taskerHex hex: String, alpha: CGFloat = 1.0) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        var rawValue: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rawValue)

        if sanitized.count == 8 {
            let red = CGFloat((rawValue & 0xFF000000) >> 24) / 255.0
            let green = CGFloat((rawValue & 0x00FF0000) >> 16) / 255.0
            let blue = CGFloat((rawValue & 0x0000FF00) >> 8) / 255.0
            let alphaValue = CGFloat(rawValue & 0x000000FF) / 255.0
            self.init(red: red, green: green, blue: blue, alpha: alphaValue)
        } else {
            let red = CGFloat((rawValue & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((rawValue & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat(rawValue & 0x0000FF) / 255.0
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

    static func taskerDynamic(lightHex: String, darkHex: String) -> UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(taskerHex: darkHex)
            }
            return UIColor(taskerHex: lightHex)
        }
    }

    convenience init(taskerHue hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat) {
        let q: CGFloat
        if lightness < 0.5 {
            q = lightness * (1 + saturation)
        } else {
            q = lightness + saturation - lightness * saturation
        }
        let p = (2 * lightness) - q

        func hueToRGB(p: CGFloat, q: CGFloat, t: CGFloat) -> CGFloat {
            var value = t
            if value < 0 { value += 1 }
            if value > 1 { value -= 1 }
            if value < 1.0 / 6.0 { return p + (q - p) * 6 * value }
            if value < 1.0 / 2.0 { return q }
            if value < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - value) * 6 }
            return p
        }

        let red = hueToRGB(p: p, q: q, t: hue + 1.0 / 3.0)
        let green = hueToRGB(p: p, q: q, t: hue)
        let blue = hueToRGB(p: p, q: q, t: hue - 1.0 / 3.0)

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
