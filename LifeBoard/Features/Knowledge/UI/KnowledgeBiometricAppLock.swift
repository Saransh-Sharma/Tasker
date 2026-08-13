import LocalAuthentication

struct KnowledgeBiometricAppLock {
    func authenticate(reason: String) async -> Bool {
        let biometricContext = LAContext()
        var error: NSError?
        if biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let success = (try? await biometricContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )) ?? false
            if success { return true }
        }
        let passcodeContext = LAContext()
        return (try? await passcodeContext.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )) ?? false
    }
}
