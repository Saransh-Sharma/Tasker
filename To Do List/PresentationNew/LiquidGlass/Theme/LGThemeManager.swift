// Liquid Glass Theme Manager
// Manages themes and visual styling for the Liquid Glass UI system

import UIKit

enum LGTheme: Int, CaseIterable {
    case light = 0
    case dark = 1
    case auto = 2
    case aurora = 3      // Special glass theme
    case ocean = 4       // Blue-tinted glass
    case sunset = 5      // Warm glass theme
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        case .aurora: return "Aurora"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        }
    }
}

class LGThemeManager {
    
    static let shared = LGThemeManager()
    
    private init() {
        loadTheme()
    }
    
    // MARK: - Properties
    var currentTheme: LGTheme = .auto {
        didSet {
            saveTheme()
            applyTheme()
        }
    }
    
    // MARK: - Theme Colors
    var primaryGlassColor: UIColor {
        switch currentTheme {
        case .light:
            return UIColor.white.withAlphaComponent(0.7)
        case .dark:
            return UIColor.black.withAlphaComponent(0.7)
        case .auto:
            return UIColor.systemBackground.withAlphaComponent(0.7)
        case .aurora:
            return UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.7)
        case .ocean:
            return UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.7)
        case .sunset:
            return UIColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 0.7)
        }
    }
    
    var secondaryGlassColor: UIColor {
        switch currentTheme {
        case .light:
            return UIColor.systemGray6.withAlphaComponent(0.8)
        case .dark:
            return UIColor.systemGray.withAlphaComponent(0.8)
        case .auto:
            return UIColor.secondarySystemBackground.withAlphaComponent(0.8)
        case .aurora:
            return UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 0.7)
        case .ocean:
            return UIColor(red: 0.3, green: 0.7, blue: 0.8, alpha: 0.7)
        case .sunset:
            return UIColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 0.7)
        }
    }
    
    var accentColor: UIColor {
        switch currentTheme {
        case .light, .dark, .auto:
            return UIColor.systemBlue
        case .aurora:
            return UIColor(red: 0.9, green: 0.3, blue: 0.9, alpha: 1.0)
        case .ocean:
            return UIColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1.0)
        case .sunset:
            return UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0)
        }
    }
    
    var glassBlurStyle: UIBlurEffect.Style {
        switch currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return .systemMaterial
        case .aurora, .ocean, .sunset:
            return .systemUltraThinMaterial
        }
    }
    
    // MARK: - Glass Effect Properties
    var glassIntensity: CGFloat {
        switch currentTheme {
        case .light, .dark:
            return 0.8
        case .auto:
            return 0.85
        case .aurora, .ocean, .sunset:
            return 0.9
        }
    }
    
    var shadowOpacity: Float {
        switch currentTheme {
        case .light:
            return 0.1
        case .dark:
            return 0.3
        case .auto:
            return 0.15
        case .aurora, .ocean, .sunset:
            return 0.2
        }
    }
    
    // MARK: - Methods
    func setTheme(_ theme: LGTheme) {
        currentTheme = theme
    }
    
    private func loadTheme() {
        let themeValue = UserDefaults.standard.integer(forKey: "lg_theme")
        if let theme = LGTheme(rawValue: themeValue) {
            currentTheme = theme
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "lg_theme")
    }
    
    private func applyTheme() {
        // Post notification for theme change
        NotificationCenter.default.post(name: .lgThemeDidChange, object: nil)
    }
}

extension Notification.Name {
    static let lgThemeDidChange = Notification.Name("LGThemeDidChange")
}
