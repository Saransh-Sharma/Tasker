import Foundation
import LifeBoardContracts

public enum JournalFeatureFlags {
    private static let key = "feature.life_os.eva_fm_responder_v1"
    private static let argument = "EVA_FM_RESPONDER_V1"

    public static var evaFoundationModelsResponderEnabled: Bool {
        #if DEBUG
        let arguments = Set(ProcessInfo.processInfo.arguments)
        if arguments.contains("-LIFEBOARD_ENABLE_\(argument)") { return true }
        if arguments.contains("-LIFEBOARD_DISABLE_\(argument)") { return false }
        #endif
        let standard = UserDefaults.standard
        let shared = UserDefaults(suiteName: AppGroupConstants.suiteName)
        if let override = shared?.object(forKey: key) as? Bool
            ?? standard.object(forKey: key) as? Bool {
            return override
        }
        return true
    }
}
