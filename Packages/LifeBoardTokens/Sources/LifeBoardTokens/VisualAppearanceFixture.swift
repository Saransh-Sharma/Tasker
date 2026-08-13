import SwiftUI
import UIKit

// The launch-argument appearance override used by the screenshot and
// snapshot runs. It is read from inside primitives that must honour
// `usesReducedMotion`, so it cannot stay behind the app boundary.
public enum VisualAppearanceFixture: String, CaseIterable, Sendable {
    case light
    case dark
    case highContrastLight = "high-contrast-light"
    case highContrastDark = "high-contrast-dark"
    case reducedTransparency = "reduced-transparency"
    case reducedMotion = "reduced-motion"
    case grayscale

    public static let launchArgumentPrefix = "-LIFEBOARD_VISUAL_APPEARANCE="

    public static var active: VisualAppearanceFixture? {
        VisualAppearanceFixture(arguments: ProcessInfo.processInfo.arguments)
    }

    public init?(arguments: [String]) {
        guard let argument = arguments.first(where: { $0.hasPrefix(Self.launchArgumentPrefix) }) else {
            return nil
        }
        self.init(rawValue: String(argument.dropFirst(Self.launchArgumentPrefix.count)))
    }

    public var launchArgument: String { "\(Self.launchArgumentPrefix)\(rawValue)" }

    public var preferredColorScheme: ColorScheme {
        self == .dark || self == .highContrastDark ? .dark : .light
    }

    public var usesHighContrast: Bool {
        self == .highContrastLight || self == .highContrastDark
    }

    public var usesReducedTransparency: Bool { self == .reducedTransparency }
    public var usesReducedMotion: Bool { self == .reducedMotion }
    public var usesGrayscale: Bool { self == .grayscale }
}
