import UIKit
import Combine

public struct TaskerTokenTraitContext: Hashable {
    public let colorScheme: UIUserInterfaceStyle
    public let contentSizeCategory: UIContentSizeCategory
    public let accessibilityContrast: UIAccessibilityContrast

    public init(
        colorScheme: UIUserInterfaceStyle = .unspecified,
        contentSizeCategory: UIContentSizeCategory = .unspecified,
        accessibilityContrast: UIAccessibilityContrast = .normal
    ) {
        self.colorScheme = colorScheme
        self.contentSizeCategory = contentSizeCategory
        self.accessibilityContrast = accessibilityContrast
    }

    public static let unspecified = TaskerTokenTraitContext()
}

public struct TaskerBrandPalette: Equatable {
    public let brandEmerald: UIColor
    public let brandMagenta: UIColor
    public let brandMarigold: UIColor
    public let brandRed: UIColor
    public let brandSandstone: UIColor
    public let neutralIvory: UIColor
    public let neutralCream: UIColor
    public let neutralMist: UIColor
    public let neutralStone: UIColor
    public let neutralSandGray: UIColor
    public let neutralUmber: UIColor
    public let neutralInk: UIColor
    public let neutralDarkInk0: UIColor
    public let neutralDarkInk1: UIColor
    public let neutralDarkInk2: UIColor
    public let neutralDarkInk3: UIColor
    public let neutralDarkBorder1: UIColor
    public let neutralDarkBorder2: UIColor
    public let neutralDarkText1: UIColor
    public let neutralDarkText2: UIColor
    public let neutralDarkText3: UIColor
    public let neutralDarkDisabled: UIColor
    public let inkDark: UIColor
    public let parchmentLight: UIColor

    public static let sarvam = TaskerBrandPalette(
        brandEmerald: UIColor(taskerHex: "#293A18"),
        brandMagenta: UIColor(taskerHex: "#B1205F"),
        brandMarigold: UIColor(taskerHex: "#FEBF2B"),
        brandRed: UIColor(taskerHex: "#C11317"),
        brandSandstone: UIColor(taskerHex: "#9E5F0A"),
        neutralIvory: UIColor(taskerHex: "#FFF8EF"),
        neutralCream: UIColor(taskerHex: "#F7EFE4"),
        neutralMist: UIColor(taskerHex: "#EFE4D6"),
        neutralStone: UIColor(taskerHex: "#E2D3C2"),
        neutralSandGray: UIColor(taskerHex: "#C9B9A6"),
        neutralUmber: UIColor(taskerHex: "#3A2E24"),
        neutralInk: UIColor(taskerHex: "#1B1511"),
        neutralDarkInk0: UIColor(taskerHex: "#0F0C0A"),
        neutralDarkInk1: UIColor(taskerHex: "#15110E"),
        neutralDarkInk2: UIColor(taskerHex: "#1D1712"),
        neutralDarkInk3: UIColor(taskerHex: "#2A211A"),
        neutralDarkBorder1: UIColor(taskerHex: "#3A2E24"),
        neutralDarkBorder2: UIColor(taskerHex: "#4A3B30"),
        neutralDarkText1: UIColor(taskerHex: "#FFF3E6"),
        neutralDarkText2: UIColor(taskerHex: "#E7D9CB"),
        neutralDarkText3: UIColor(taskerHex: "#CBBBA7"),
        neutralDarkDisabled: UIColor(taskerHex: "#7E7268"),
        inkDark: UIColor(taskerHex: "#10130D"),
        parchmentLight: UIColor(taskerHex: "#F6EFE2")
    )
}

public struct TaskerPatternTokens: Equatable {
    public let gatewaySunriseTop: UIColor
    public let gatewaySunriseMid: UIColor
    public let gatewaySunriseBottom: UIColor
    public let forestInkTop: UIColor
    public let forestInkBottom: UIColor
    public let patternTint: UIColor

    init(palette: TaskerBrandPalette) {
        gatewaySunriseTop = palette.brandSandstone
        gatewaySunriseMid = palette.brandMarigold
        gatewaySunriseBottom = palette.brandMagenta
        forestInkTop = palette.brandEmerald
        forestInkBottom = palette.inkDark
        patternTint = palette.brandSandstone.withAlphaComponent(0.12)
    }
}

public struct TaskerWidgetTokens: Equatable {
    public let background: UIColor
    public let backgroundElevated: UIColor
    public let accent: UIColor
    public let accentQuiet: UIColor
    public let highlight: UIColor
    public let textPrimary: UIColor
    public let textSecondary: UIColor

    init(palette: TaskerBrandPalette) {
        background = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk1 : palette.neutralIvory
        }
        backgroundElevated = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk2 : UIColor(taskerHex: "#FFFCF8")
        }
        accent = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.brandMarigold : palette.brandEmerald
        }
        accentQuiet = UIColor { traits in
            let base = traits.userInterfaceStyle == .dark ? palette.brandMarigold : palette.brandMagenta
            return base.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.16 : 0.14)
        }
        highlight = palette.brandMagenta
        textPrimary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkText1 : palette.neutralInk
        }
        textSecondary = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkText2 : UIColor(taskerHex: "#6A594B")
        }
    }
}

public struct TaskerTheme {
    public let index: Int
    public let palette: TaskerBrandPalette
    public let patterns: TaskerPatternTokens
    public let widgets: TaskerWidgetTokens
    public let tokens: TaskerTokens

    public init(index: Int = 0) {
        self.index = 0
        self.palette = .sarvam
        self.patterns = TaskerPatternTokens(palette: palette)
        self.widgets = TaskerWidgetTokens(palette: palette)
        self.tokens = TaskerTokens(
            color: TaskerColorTokens.make(palette: palette),
            typography: TaskerTypographyTokens.makeDefault(),
            spacing: TaskerSpacingTokens.default,
            elevation: TaskerElevationTokens.default,
            corner: TaskerCornerTokens.default
        )
    }

    public func tokens(for layoutClass: TaskerLayoutClass) -> TaskerTokens {
        TaskerTokens(
            color: tokens.color,
            typography: TaskerTypographyTokens.make(for: layoutClass),
            spacing: TaskerSpacingTokens.forLayout(layoutClass),
            elevation: TaskerElevationTokens.forLayout(layoutClass),
            corner: TaskerCornerTokens.forLayout(layoutClass)
        )
    }
}

@MainActor
public final class TaskerThemeManager: ObservableObject {
    private struct TokenCacheKey: Hashable {
        let layoutClass: TaskerLayoutClass
        let traits: TaskerTokenTraitContext
    }

    public static let shared = TaskerThemeManager()

    @Published public private(set) var currentTheme: TaskerTheme
    private var tokenCache: [TokenCacheKey: TaskerTokens] = [:]

    public var publisher: AnyPublisher<TaskerTheme, Never> {
        $currentTheme.eraseToAnyPublisher()
    }

    private init() {
        currentTheme = TaskerTheme()
    }

    public func reloadFromPersistence() {
        currentTheme = TaskerTheme()
        tokenCache.removeAll(keepingCapacity: false)
        TaskerTypographyTokens.resetCache()
    }

    public func tokens(for layoutClass: TaskerLayoutClass) -> TaskerTokens {
        tokens(for: layoutClass, traits: .unspecified)
    }

    public func tokens(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerTokens {
        guard V2FeatureFlags.iPadPerfThemeTokenCacheV2Enabled else {
            return currentTheme.tokens(for: layoutClass)
        }

        let cacheKey = TokenCacheKey(layoutClass: layoutClass, traits: traits)
        if let cached = tokenCache[cacheKey] {
            return cached
        }

        let resolved = currentTheme.tokens(for: layoutClass)
        tokenCache[cacheKey] = resolved
        logWarning(
            event: "themeTokenResolve",
            message: "Resolved brand tokens for layout + trait cluster",
            fields: [
                "layout_class": layoutClass.rawValue,
                "color_scheme": String(traits.colorScheme.rawValue),
                "content_size_category": traits.contentSizeCategory.rawValue,
                "accessibility_contrast": String(traits.accessibilityContrast.rawValue)
            ]
        )
        return resolved
    }

    public static var tokens: TaskerTokens {
        TaskerThemeManager.shared.currentTheme.tokens
    }

    public static func tokens(for layoutClass: TaskerLayoutClass) -> TaskerTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass)
    }

    public static func tokens(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass, traits: traits)
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
}
