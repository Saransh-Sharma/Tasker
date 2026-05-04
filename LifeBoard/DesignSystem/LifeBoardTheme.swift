import UIKit
import Combine

public struct LifeBoardTokenTraitContext: Hashable, Sendable {
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

    public static let unspecified = LifeBoardTokenTraitContext()
}

public struct LifeBoardBrandPalette: Equatable {
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

    @MainActor
    public static let sarvam = LifeBoardBrandPalette(
        brandEmerald: UIColor(lifeboardHex: "#293A18"),
        brandMagenta: UIColor(lifeboardHex: "#B1205F"),
        brandMarigold: UIColor(lifeboardHex: "#FEBF2B"),
        brandRed: UIColor(lifeboardHex: "#C11317"),
        brandSandstone: UIColor(lifeboardHex: "#9E5F0A"),
        neutralIvory: UIColor(lifeboardHex: "#FFF8EF"),
        neutralCream: UIColor(lifeboardHex: "#F7EFE4"),
        neutralMist: UIColor(lifeboardHex: "#EFE4D6"),
        neutralStone: UIColor(lifeboardHex: "#E2D3C2"),
        neutralSandGray: UIColor(lifeboardHex: "#C9B9A6"),
        neutralUmber: UIColor(lifeboardHex: "#3A2E24"),
        neutralInk: UIColor(lifeboardHex: "#1B1511"),
        neutralDarkInk0: UIColor(lifeboardHex: "#0F0C0A"),
        neutralDarkInk1: UIColor(lifeboardHex: "#15110E"),
        neutralDarkInk2: UIColor(lifeboardHex: "#1D1712"),
        neutralDarkInk3: UIColor(lifeboardHex: "#2A211A"),
        neutralDarkBorder1: UIColor(lifeboardHex: "#3A2E24"),
        neutralDarkBorder2: UIColor(lifeboardHex: "#4A3B30"),
        neutralDarkText1: UIColor(lifeboardHex: "#FFF3E6"),
        neutralDarkText2: UIColor(lifeboardHex: "#E7D9CB"),
        neutralDarkText3: UIColor(lifeboardHex: "#CBBBA7"),
        neutralDarkDisabled: UIColor(lifeboardHex: "#7E7268"),
        inkDark: UIColor(lifeboardHex: "#10130D"),
        parchmentLight: UIColor(lifeboardHex: "#F6EFE2")
    )
}

public struct LifeBoardPatternTokens: Equatable {
    public let gatewaySunriseTop: UIColor
    public let gatewaySunriseMid: UIColor
    public let gatewaySunriseBottom: UIColor
    public let forestInkTop: UIColor
    public let forestInkBottom: UIColor
    public let patternTint: UIColor

    init(palette: LifeBoardBrandPalette) {
        gatewaySunriseTop = palette.brandSandstone
        gatewaySunriseMid = palette.brandMarigold
        gatewaySunriseBottom = palette.brandMagenta
        forestInkTop = palette.brandEmerald
        forestInkBottom = palette.inkDark
        patternTint = palette.brandSandstone.withAlphaComponent(0.12)
    }
}

public struct LifeBoardWidgetTokens: Equatable {
    public let background: UIColor
    public let backgroundElevated: UIColor
    public let accent: UIColor
    public let accentQuiet: UIColor
    public let highlight: UIColor
    public let textPrimary: UIColor
    public let textSecondary: UIColor

    init(palette: LifeBoardBrandPalette) {
        background = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk1 : palette.neutralIvory
        }
        backgroundElevated = UIColor { traits in
            traits.userInterfaceStyle == .dark ? palette.neutralDarkInk2 : UIColor(lifeboardHex: "#FFFCF8")
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
            traits.userInterfaceStyle == .dark ? palette.neutralDarkText2 : UIColor(lifeboardHex: "#6A594B")
        }
    }
}

@MainActor
public struct LifeBoardTheme {
    public let index: Int
    public let palette: LifeBoardBrandPalette
    public let patterns: LifeBoardPatternTokens
    public let widgets: LifeBoardWidgetTokens
    public let tokens: LifeBoardTokens

    public init(index: Int = 0) {
        // `index` is retained for backward compatibility, but the app now ships a single palette.
        self.index = index
        self.palette = .sarvam
        self.patterns = LifeBoardPatternTokens(palette: palette)
        self.widgets = LifeBoardWidgetTokens(palette: palette)
        self.tokens = LifeBoardTokens(
            color: LifeBoardColorTokens.make(palette: palette),
            typography: LifeBoardTypographyTokens.makeDefault(),
            spacing: LifeBoardSpacingTokens.default,
            elevation: LifeBoardElevationTokens.default,
            corner: LifeBoardCornerTokens.default
        )
    }

    public func tokens(for layoutClass: LifeBoardLayoutClass) -> LifeBoardTokens {
        LifeBoardTokens(
            color: tokens.color,
            typography: LifeBoardTypographyTokens.make(for: layoutClass),
            spacing: LifeBoardSpacingTokens.forLayout(layoutClass),
            elevation: LifeBoardElevationTokens.forLayout(layoutClass),
            corner: LifeBoardCornerTokens.forLayout(layoutClass)
        )
    }
}

@MainActor
public final class LifeBoardThemeManager: ObservableObject {
    private struct TokenCacheKey: Hashable {
        let layoutClass: LifeBoardLayoutClass
        let traits: LifeBoardTokenTraitContext
    }

    public static let shared = LifeBoardThemeManager()

    @Published public private(set) var currentTheme: LifeBoardTheme
    private var tokenCache: [TokenCacheKey: LifeBoardTokens] = [:]

    public var publisher: AnyPublisher<LifeBoardTheme, Never> {
        $currentTheme.eraseToAnyPublisher()
    }

    private init() {
        currentTheme = LifeBoardTheme()
    }

    public func reloadFromPersistence() {
        currentTheme = LifeBoardTheme()
        tokenCache.removeAll(keepingCapacity: false)
        LifeBoardTypographyTokens.resetCache()
    }

    public func tokens(for layoutClass: LifeBoardLayoutClass) -> LifeBoardTokens {
        tokens(for: layoutClass, traits: .unspecified)
    }

    public func tokens(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardTokens {
        guard V2FeatureFlags.iPadPerfThemeTokenCacheV2Enabled else {
            return currentTheme.tokens(for: layoutClass)
        }

        let cacheKey = TokenCacheKey(layoutClass: layoutClass, traits: traits)
        if let cached = tokenCache[cacheKey] {
            return cached
        }

        let resolved = currentTheme.tokens(for: layoutClass)
        tokenCache[cacheKey] = resolved
#if DEBUG
        logDebug(
            event: "themeTokenResolve",
            message: "Resolved brand tokens for layout + trait cluster",
            fields: [
                "layout_class": layoutClass.rawValue,
                "color_scheme": String(traits.colorScheme.rawValue),
                "content_size_category": traits.contentSizeCategory.rawValue,
                "accessibility_contrast": String(traits.accessibilityContrast.rawValue)
            ]
        )
#endif
        return resolved
    }

    public static var tokens: LifeBoardTokens {
        LifeBoardThemeManager.shared.currentTheme.tokens
    }

    public static func tokens(for layoutClass: LifeBoardLayoutClass) -> LifeBoardTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass)
    }

    public static func tokens(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass, traits: traits)
    }
}

public extension UIColor {
    convenience init(lifeboardHex hex: String, alpha: CGFloat = 1.0) {
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

    static func lifeboardDynamic(lightHex: String, darkHex: String) -> UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(lifeboardHex: darkHex)
            }
            return UIColor(lifeboardHex: lightHex)
        }
    }
}
