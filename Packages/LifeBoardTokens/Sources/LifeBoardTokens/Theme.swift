import UIKit
import Combine

public struct TokenTraitContext: Hashable, Sendable {
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

    public static let unspecified = TokenTraitContext()
}

public struct BrandPalette: Equatable, @unchecked Sendable {
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

    public static let sunrise = BrandPalette(
        brandEmerald: UIColor(lifeboardHex: "#28B53F"),
        brandMagenta: UIColor(lifeboardHex: "#6842FF"),
        brandMarigold: UIColor(lifeboardHex: "#FFB300"),
        brandRed: UIColor(lifeboardHex: "#FF7A3D"),
        brandSandstone: UIColor(lifeboardHex: "#FF7A3D"),
        neutralIvory: UIColor(lifeboardHex: "#FFFDFC"),
        neutralCream: UIColor(lifeboardHex: "#FFF8EF"),
        neutralMist: UIColor(lifeboardHex: "#F7FBFF"),
        neutralStone: UIColor(lifeboardHex: "#DDE3EE"),
        neutralSandGray: UIColor(lifeboardHex: "#B9C7DC"),
        neutralUmber: UIColor(lifeboardHex: "#48607F"),
        neutralInk: UIColor(lifeboardHex: "#071B52"),
        neutralDarkInk0: UIColor(lifeboardHex: "#080C17"),
        neutralDarkInk1: UIColor(lifeboardHex: "#10101A"),
        neutralDarkInk2: UIColor(lifeboardHex: "#171C2B"),
        neutralDarkInk3: UIColor(lifeboardHex: "#20263A"),
        neutralDarkBorder1: UIColor(lifeboardHex: "#3A4258"),
        neutralDarkBorder2: UIColor(lifeboardHex: "#56617B"),
        neutralDarkText1: UIColor(lifeboardHex: "#F7F1E7"),
        neutralDarkText2: UIColor(lifeboardHex: "#C9D2E3"),
        neutralDarkText3: UIColor(lifeboardHex: "#9DAAC2"),
        neutralDarkDisabled: UIColor(lifeboardHex: "#7E8AA2"),
        inkDark: UIColor(lifeboardHex: "#071B52"),
        parchmentLight: UIColor(lifeboardHex: "#FFF8EF")
    )

    @available(*, deprecated, message: "Use .sunrise. Sarvam is retained only for migration compatibility.")
    public static let sarvam = BrandPalette(
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

public enum ThreadSafeTokenResolver {
    private static let sunriseColorTokens = LifeBoardColorTokens.make(palette: .sunrise)

    /// - Parameter traits: Reserved for future trait-aware token resolution; currently unused.
    public static func color(
        for role: ColorRole,
        traits _: TokenTraitContext = .unspecified
    ) -> UIColor {
        sunriseColorTokens.color(for: role)
    }

    public static func color(
        for role: LegibilityRole,
        on surface: SurfaceContext,
        imageLuminance: CGFloat? = nil,
        traits _: TokenTraitContext = .unspecified
    ) -> UIColor {
        sunriseColorTokens.color(
            for: role,
            on: surface,
            imageLuminance: imageLuminance
        )
    }
}

public struct PatternTokens: Equatable {
    public let gatewaySunriseTop: UIColor
    public let gatewaySunriseMid: UIColor
    public let gatewaySunriseBottom: UIColor
    public let forestInkTop: UIColor
    public let forestInkBottom: UIColor
    public let patternTint: UIColor

    init(palette: BrandPalette) {
        gatewaySunriseTop = palette.brandSandstone
        gatewaySunriseMid = palette.brandMarigold
        gatewaySunriseBottom = palette.brandMagenta
        forestInkTop = palette.brandEmerald
        forestInkBottom = palette.inkDark
        patternTint = palette.brandSandstone.withAlphaComponent(0.12)
    }
}

public struct WidgetTokens: Equatable {
    public let background: UIColor
    public let backgroundElevated: UIColor
    public let accent: UIColor
    public let accentQuiet: UIColor
    public let highlight: UIColor
    public let textPrimary: UIColor
    public let textSecondary: UIColor

    init(palette: BrandPalette) {
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
public struct Theme {
    public let index: Int
    public let palette: BrandPalette
    public let patterns: PatternTokens
    public let widgets: WidgetTokens
    public let tokens: Tokens

    public init(index: Int = 0) {
        // `index` is retained for backward compatibility, but the app now ships a single palette.
        self.index = index
        self.palette = .sunrise
        self.patterns = PatternTokens(palette: palette)
        self.widgets = WidgetTokens(palette: palette)
        self.tokens = Tokens(
            color: LifeBoardColorTokens.make(palette: palette),
            typography: LifeBoardTypographyTokens.makeDefault(),
            spacing: LifeBoardSpacingTokens.default,
            elevation: ElevationTokens.default,
            corner: CornerTokens.default
        )
    }

    public func tokens(for layoutClass: LayoutClass) -> Tokens {
        Tokens(
            color: tokens.color,
            typography: LifeBoardTypographyTokens.make(for: layoutClass),
            spacing: LifeBoardSpacingTokens.forLayout(layoutClass),
            elevation: ElevationTokens.forLayout(layoutClass),
            corner: CornerTokens.forLayout(layoutClass)
        )
    }
}

@MainActor
public final class ThemeStore: ObservableObject {
    private struct TokenCacheKey: Hashable {
        let layoutClass: LayoutClass
        let traits: TokenTraitContext
    }

    public static let shared = ThemeStore()

    @Published public private(set) var currentTheme: Theme
    private var tokenCache: [TokenCacheKey: Tokens] = [:]

    public var publisher: AnyPublisher<Theme, Never> {
        $currentTheme.eraseToAnyPublisher()
    }

    private init() {
        currentTheme = Theme()
    }

    public func reloadFromPersistence() {
        currentTheme = Theme()
        tokenCache.removeAll(keepingCapacity: false)
        LifeBoardTypographyTokens.resetCache()
    }

    public func tokens(for layoutClass: LayoutClass) -> Tokens {
        tokens(for: layoutClass, traits: .unspecified)
    }

    /// Mirrors `V2FeatureFlags.iPadPerfThemeTokenCacheV2Enabled` storage.
    ///
    /// The flag service lives in the app and is not compiled into the widget or
    /// Watch targets, which link this package too — the same reason
    /// `ColorTokens` mirrors the unified-presentation flag rather than importing
    /// it. Key and default are kept identical on purpose; changing either here
    /// silently desynchronises the cache from the app's own switch.
    private static var tokenCacheEnabled: Bool {
        let key = "feature.ipad.perf.theme_token_cache_v2"
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    public func tokens(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> Tokens {
        guard Self.tokenCacheEnabled else {
            return currentTheme.tokens(for: layoutClass)
        }

        let cacheKey = TokenCacheKey(layoutClass: layoutClass, traits: traits)
        if let cached = tokenCache[cacheKey] {
            return cached
        }

        let resolved = currentTheme.tokens(for: layoutClass)
        tokenCache[cacheKey] = resolved
#if DEBUG
        TokensDiagnostics.debugLog?(
            "themeTokenResolve",
            "Resolved brand tokens for layout + trait cluster",
            [
                "layout_class": layoutClass.rawValue,
                "color_scheme": String(traits.colorScheme.rawValue),
                "content_size_category": traits.contentSizeCategory.rawValue,
                "accessibility_contrast": String(traits.accessibilityContrast.rawValue)
            ]
        )
#endif
        return resolved
    }

    public static var tokens: Tokens {
        ThemeStore.shared.currentTheme.tokens
    }

    public static func tokens(for layoutClass: LayoutClass) -> Tokens {
        ThemeStore.shared.tokens(for: layoutClass)
    }

    public static func tokens(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> Tokens {
        ThemeStore.shared.tokens(for: layoutClass, traits: traits)
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

/// Diagnostics hook for the token layer.
///
/// `Theme` used to call the app's `logDebug` directly. That is not
/// reachable from a package the widget and Watch processes also link, so the
/// call is routed through a closure the app installs at launch. Left unset the
/// token layer is silent, which is the correct default for the extensions.
public enum TokensDiagnostics {
    /// `(event, message, fields)`. DEBUG-only at the call site.
    public nonisolated(unsafe) static var debugLog: ((String, String, [String: String]) -> Void)?
}
