//
//  ToDoColors.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation
import UIKit

class ToDoColors {
    
    // MARK: - Theme Definition
    struct Theme {
        let primary: UIColor
        let secondary: UIColor
    }
    
    // All available themes – first theme must remain the current default so existing users keep their colours
    static let themes: [Theme] = [
        // Default (existing) theme – MUST stay at index 0
        Theme(primary: #colorLiteral(red: 0.5490196078, green: 0.5450980392, blue: 0.8196078431, alpha: 1),
              secondary: #colorLiteral(red: 0.9824339747, green: 0.5298179388, blue: 0.176022768, alpha: 1)),
        // New user-selectable themes
        Theme(primary: UIColor(hex: "#E84444FF"), secondary: UIColor(hex: "#E1AFD1")),
        Theme(primary: UIColor(hex: "#D1E9F6"), secondary: UIColor(hex: "#F1D3CE")),
        Theme(primary: UIColor(hex: "#8EA6E97E"), secondary: UIColor(hex: "#E5E0FF")),
        Theme(primary: UIColor(hex: "#ECE3CE8E"), secondary: UIColor(hex: "#739072")),
        Theme(primary: UIColor(hex: "#BFECFFA7"), secondary: UIColor(hex: "#CDC1FF")),
        Theme(primary: UIColor(hex: "#D2E0FB"), secondary: UIColor(hex: "#F9F3CC")),
        Theme(primary: UIColor(hex: "#789DBC"), secondary: UIColor(hex: "#FFE3E3")),
        Theme(primary: UIColor(hex: "#304FFEFF"), secondary: UIColor(hex: "#FEE764FF")), // Indigo ↔ sunflower
        Theme(primary: UIColor(hex: "#00695CFF"), secondary: UIColor(hex: "#B27079FF")), // Deep teal ↔ muted rose
        Theme(primary: UIColor(hex: "#8E24AAFF"), secondary: UIColor(hex: "#70BF5BFF")), // Royal purple ↔ fresh spring green
        Theme(primary: UIColor(hex: "#C23C13FF"), secondary: UIColor(hex: "#4EB2D1FF")), // Burnt orange ↔ clear-sky cyan
        Theme(primary: UIColor(hex: "#455A64FF"), secondary: UIColor(hex: "#FF9940FF")), // Blue-grey ↔ warm tangerine
        Theme(primary: UIColor(hex: "#C2185BFF"), secondary: UIColor(hex: "#52D19FFF")), // Vivid magenta ↔ minty green
        Theme(primary: UIColor(hex: "#5D4037FF"), secondary: UIColor(hex: "#82A3B1FF")),
        Theme(primary: UIColor(hex: "#0D47A1FF"), secondary: UIColor(hex: "#FFB300FF")), // deep navy ↔ bold amber
        Theme(primary: UIColor(hex: "#B71C1CFF"), secondary: UIColor(hex: "#1CB7B7FF")), // fierce crimson ↔ tropical teal
        Theme(primary: UIColor(hex: "#2E7D32FF"), secondary: UIColor(hex: "#7D2E79FF")), // forest green ↔ royal magenta
        Theme(primary: UIColor(hex: "#512DA8FF"), secondary: UIColor(hex: "#A85B2DFF")), // rich indigo ↔ toasted copper
        Theme(primary: UIColor(hex: "#006064FF"), secondary: UIColor(hex: "#640D00FF")), // ocean teal ↔ burnt sienna
        Theme(primary: UIColor(hex: "#37474FFF"), secondary: UIColor(hex: "#FFB539FF")), // blue-gray ↔ sunset apricot
        Theme(primary: UIColor(hex: "#0277BDFF"), secondary: UIColor(hex: "#BD6F02FF")), // cerulean ↔ harvest orange
        Theme(primary: UIColor(hex: "#00897BFF"), secondary: UIColor(hex: "#890800FF")), // jade teal ↔ oxblood
        Theme(primary: UIColor(hex: "#C2185BFF"), secondary: UIColor(hex: "#18C269FF")), // vivid rose ↔ spring green
        Theme(primary: UIColor(hex: "#5D4037FF"), secondary: UIColor(hex: "#37805DFF")), // cocoa brown ↔ pine teal
        Theme(primary: UIColor(hex: "#1E88E5FF"), secondary: UIColor(hex: "#E5A31EFF")), // royal blue ↔ goldenrod
        Theme(primary: UIColor(hex: "#3949ABFF"), secondary: UIColor(hex: "#AB8D39FF")), // indigo dusk ↔ antique brass
        Theme(primary: UIColor(hex: "#7B1FA2FF"), secondary: UIColor(hex: "#1FA266FF")), // velvet violet ↔ emerald sea
        Theme(primary: UIColor(hex: "#E65100FF"), secondary: UIColor(hex: "#0066E6FF")), // blaze orange ↔ cobalt sky
        Theme(primary: UIColor(hex: "#004D40FF"), secondary: UIColor(hex: "#4D000CFF")), // dark cyan ↔ deep burgundy
        Theme(primary: UIColor(hex: "#283593FF"), secondary: UIColor(hex: "#939C28FF")), // midnight indigo ↔ electric chartreuse
        Theme(primary: UIColor(hex: "#AD1457FF"), secondary: UIColor(hex: "#14AD6AFF")), // raspberry wine ↔ mint surf
        Theme(primary: UIColor(hex: "#4527A0FF"), secondary: UIColor(hex: "#A06B27FF")), // cosmic purple ↔ bronze spice
        Theme(primary: UIColor(hex: "#2962FFFF"), secondary: UIColor(hex: "#FFBC29FF")), // strike-blue ↔ marigold
        Theme(primary: UIColor(hex: "#BF360CFF"), secondary: UIColor(hex: "#0C9ABFFF"))  // volcanic red ↔ bright cyan
  // Cocoa brown ↔ cool slate
    ]
    
    // Key for persisting selected theme
    private static let userDefaultsKey = "selectedThemeIndex"
    
    // Currently selected theme index (defaults to 0 if none saved)
    static var currentIndex: Int {
        get {
            return UserDefaults.standard.integer(forKey: userDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            // Notify observers
            NotificationCenter.default.post(name: .themeChanged, object: nil)
        }
    }
    
    // MARK: - Instance Properties – forwarded from the currently selected theme
    var backgroundColor = UIColor.systemGray5 // Not part of new theme but kept for compatibility
    var primaryColor: UIColor
    var secondaryAccentColor: UIColor
    
    // Derived colours
    var primaryColorDarker: UIColor {
        return primaryColor.withBrightness(0.8)
    }
    var completeTaskSwipeColor = UIColor(red: 46/255.0, green: 204/255.0, blue: 113/255.0, alpha: 1.0)
    
    // Existing additional properties
    var darkModeColor = UIColor.black
    var primaryTextColor = UIColor.label
    var foregroundColor = UIColor.systemBackground
    
    // MARK: - Init
    init() {
        let theme = ToDoColors.themes[ToDoColors.currentIndex]
        self.primaryColor = theme.primary
        self.secondaryAccentColor = theme.secondary
    }
    
    // MARK: - Public Helpers
    static func setTheme(index: Int) {
        guard index >= 0 && index < themes.count else { return }
        currentIndex = index
    }

    
    
    //Original theme
    
    
}



// MARK: - Notifications
extension Notification.Name {
    static let themeChanged = Notification.Name("ToDoThemeChangedNotification")
}

// MARK: - UIColor helpers
extension UIColor {
    /// Create a UIColor from hex string like "#AABBCC" or "AABBCC"
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
    
    /// Adjust brightness of color
    func withBrightness(_ brightness: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var currentBrightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if self.getHue(&hue, saturation: &saturation, brightness: &currentBrightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: currentBrightness * brightness, alpha: alpha)
        }
        return self
    }
}
