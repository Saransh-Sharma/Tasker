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
         // New user-selectable themes
        Theme(primary: UIColor(hex: "#E84444FF"), secondary: UIColor(hex: "#E1AFD1")),
        Theme(primary: UIColor(hex: "#D1E9F6"), secondary: UIColor(hex: "#F1D3CE")),
        Theme(primary: UIColor(hex: "#8EA6E97E"), secondary: UIColor(hex: "#E5E0FF")),
        
        // New Light Green themes
        Theme(primary: UIColor(hex: "#AFF8A2"), secondary: UIColor(hex: "#FFC15E")), // Light Green + Orange
        Theme(primary: UIColor(hex: "#AFF8A2"), secondary: UIColor(hex: "#626D58")), // Light Green + Dark Green
        Theme(primary: UIColor(hex: "#AFF8A2"), secondary: UIColor(hex: "#2E4052")), // Light Green + Dark Blue
        Theme(primary: UIColor(hex: "#AFF8A2"), secondary: UIColor(hex: "#246EB9")), // Light Green + Blue
        Theme(primary: UIColor(hex: "#AFF8A2"), secondary: UIColor(hex: "#000000")), // Light Green + Black
        
        // New Mustard themes
        Theme(primary: UIColor(hex: "#F9D749"), secondary: UIColor(hex: "#F05D5E")), // Mustard + Red
        Theme(primary: UIColor(hex: "#F9D749"), secondary: UIColor(hex: "#C1DBE3")), // Mustard + Light Blue
        Theme(primary: UIColor(hex: "#F9D749"), secondary: UIColor(hex: "#16302B")), // Mustard + Dark Green
        Theme(primary: UIColor(hex: "#F9D749"), secondary: UIColor(hex: "#FE4A49")), // Mustard + Bright Red
        Theme(primary: UIColor(hex: "#F9D749"), secondary: UIColor(hex: "#12100E")), // Mustard + Dark Brown
        
        // New Baby Blue themes
        Theme(primary: UIColor(hex: "#97CDE8"), secondary: UIColor(hex: "#B10F2E")), // Baby Blue + Dark Red
        Theme(primary: UIColor(hex: "#97CDE8"), secondary: UIColor(hex: "#DFD5A5")), // Baby Blue + Cream
        Theme(primary: UIColor(hex: "#97CDE8"), secondary: UIColor(hex: "#FC7753")), // Baby Blue + Orange
        Theme(primary: UIColor(hex: "#97CDE8"), secondary: UIColor(hex: "#1B4079")), // Baby Blue + Navy
        
        // New Coral themes
        Theme(primary: UIColor(hex: "#EE7470"), secondary: UIColor(hex: "#909CC2")), // Coral + Lavender
        Theme(primary: UIColor(hex: "#EE7470"), secondary: UIColor(hex: "#F2F3AE")), // Coral + Light Yellow
        Theme(primary: UIColor(hex: "#EE7470"), secondary: UIColor(hex: "#87F1FF")), // Coral + Cyan
        
        // New Plum themes
        Theme(primary: UIColor(hex: "#D4A4DA"), secondary: UIColor(hex: "#E59F71")), // Plum + Peach
        Theme(primary: UIColor(hex: "#D4A4DA"), secondary: UIColor(hex: "#1B264F")), // Plum + Navy
        Theme(primary: UIColor(hex: "#D4A4DA"), secondary: UIColor(hex: "#4EFFEF")), // Plum + Bright Cyan
        Theme(primary: UIColor(hex: "#D4A4DA"), secondary: UIColor(hex: "#2B4162"))  // Plum + Dark Blue
  
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
