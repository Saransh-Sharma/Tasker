//
//  AppLock.swift
//  JournalSecurityKit
//
//  Biometric/passcode gate seam. Authentication is handled entirely by
//  LocalAuthentication (Secure Enclave); no credentials touch the app.
//

import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication

public protocol AppLockProviding: Sendable {
    var biometricsAvailable: Bool { get }
    var biometryTypeName: String { get }
    /// Biometrics first, device passcode fallback.
    func authenticate(reason: String) async -> Bool
}

public struct BiometricAppLock: AppLockProviding {

    public init() {}

    public var biometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public var biometryTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Passcode"
        }
    }

    public func authenticate(reason: String) async -> Bool {
        let biometricContext = LAContext()
        var error: NSError?
        if biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let success = (try? await biometricContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )) ?? false
            if success { return true }
            // Fall through to passcode on failure or user fallback.
        }
        let passcodeContext = LAContext()
        return (try? await passcodeContext.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )) ?? false
    }
}
#endif
