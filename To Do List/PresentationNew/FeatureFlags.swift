// Feature Flags for Liquid Glass UI Migration
// This file manages the gradual rollout of Liquid Glass UI features

import Foundation

struct FeatureFlags {
    
    // MARK: - UI Feature Flags
    static var useLiquidGlassUI: Bool {
        get { UserDefaults.standard.bool(forKey: "feature_liquid_glass_ui") }
        set { 
            UserDefaults.standard.set(newValue, forKey: "feature_liquid_glass_ui")
            NotificationCenter.default.post(name: .featureFlagChanged, object: nil)
        }
    }
    
    static var enableAdvancedAnimations: Bool {
        get { UserDefaults.standard.bool(forKey: "feature_advanced_animations") }
        set { UserDefaults.standard.set(newValue, forKey: "feature_advanced_animations") }
    }
    
    static var enableHapticFeedback: Bool {
        get { UserDefaults.standard.bool(forKey: "feature_haptic_feedback") }
        set { UserDefaults.standard.set(newValue, forKey: "feature_haptic_feedback") }
    }
    
    static var enableParticleEffects: Bool {
        get { UserDefaults.standard.bool(forKey: "feature_particle_effects") }
        set { UserDefaults.standard.set(newValue, forKey: "feature_particle_effects") }
    }
    
    // MARK: - Migration Flags
    static var showMigrationProgress: Bool {
        get { UserDefaults.standard.bool(forKey: "show_migration_progress") }
        set { UserDefaults.standard.set(newValue, forKey: "show_migration_progress") }
    }
    
    static var enableDebugMenu: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "enable_debug_menu")
        #endif
    }
    
    // MARK: - Screen-specific Flags
    static var useLiquidGlassHome: Bool {
        get { UserDefaults.standard.bool(forKey: "lg_home_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "lg_home_enabled") }
    }
    
    static var useLiquidGlassTasks: Bool {
        get { UserDefaults.standard.bool(forKey: "lg_tasks_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "lg_tasks_enabled") }
    }
    
    static var useLiquidGlassProjects: Bool {
        get { UserDefaults.standard.bool(forKey: "lg_projects_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "lg_projects_enabled") }
    }
    
    static var useLiquidGlassSettings: Bool {
        get { UserDefaults.standard.bool(forKey: "lg_settings_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "lg_settings_enabled") }
    }
    
    // MARK: - Helper Methods
    static func resetToDefaults() {
        useLiquidGlassUI = false
        enableAdvancedAnimations = true
        enableHapticFeedback = true
        enableParticleEffects = false
        showMigrationProgress = true
        useLiquidGlassHome = false
        useLiquidGlassTasks = false
        useLiquidGlassProjects = false
        useLiquidGlassSettings = false
    }
    
    static func enableAllLiquidGlass() {
        useLiquidGlassUI = true
        useLiquidGlassHome = true
        useLiquidGlassTasks = true
        useLiquidGlassProjects = true
        useLiquidGlassSettings = true
    }
}

extension Notification.Name {
    static let featureFlagChanged = Notification.Name("FeatureFlagChanged")
}
