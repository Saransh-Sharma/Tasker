// LGPhase3Activator.swift
// Activator for Phase 3: Liquid Glass Home Screen
// Enables the Liquid Glass Home feature and manages the transition

import Foundation
import UIKit

class LGPhase3Activator {
    
    static func activatePhase3() {
        // Enable all necessary feature flags for Phase 3
        FeatureFlags.useLiquidGlassUI = true
        FeatureFlags.useLiquidGlassHome = true
        FeatureFlags.enableLiquidAnimations = true
        FeatureFlags.enableAdvancedAnimations = true
        FeatureFlags.showMigrationProgress = true
        
        print("🌊 Phase 3 Activated: Liquid Glass Home Screen enabled!")
        
        // Trigger UI update
        NotificationCenter.default.post(name: .featureFlagChanged, object: nil)
    }
    
    static func deactivatePhase3() {
        // Disable Liquid Glass Home but keep other features
        FeatureFlags.useLiquidGlassHome = false
        
        print("🏠 Phase 3 Deactivated: Returning to legacy Home Screen")
        
        // Trigger UI update
        NotificationCenter.default.post(name: .featureFlagChanged, object: nil)
    }
    
    static var isPhase3Active: Bool {
        return FeatureFlags.useLiquidGlassUI && FeatureFlags.useLiquidGlassHome
    }
}

// MARK: - Debug Helper

#if DEBUG
extension LGPhase3Activator {
    
    static func setupDebugActivation() {
        // Auto-activate Phase 3 in debug builds
        if !UserDefaults.standard.bool(forKey: "phase3_auto_activated") {
            activatePhase3()
            UserDefaults.standard.set(true, forKey: "phase3_auto_activated")
        }
    }
    
    static func resetDebugState() {
        UserDefaults.standard.removeObject(forKey: "phase3_auto_activated")
        FeatureFlags.resetToDefaults()
    }
}
#endif
