import Foundation
import LifeBoardContracts

enum KnowledgeFeatureFlags {
    static var textKitEditorEnabled: Bool {
        enabled(key: "feature.life_os.knowledge_notes_textkit_v2", argument: "KNOWLEDGE_NOTES_TEXTKIT_V2")
    }

    static var searchIndexEnabled: Bool {
        enabled(key: "feature.life_os.knowledge_notes_search_v2", argument: "KNOWLEDGE_NOTES_SEARCH_V2")
    }

    static var securityEnabled: Bool {
        enabled(key: "feature.life_os.knowledge_notes_security_v1", argument: "KNOWLEDGE_NOTES_SECURITY_V1")
    }

    static var evaEnabled: Bool {
        enabled(key: "feature.life_os.knowledge_notes_eva_v1", argument: "KNOWLEDGE_NOTES_EVA_V1")
    }

    private static func enabled(key: String, argument: String) -> Bool {
#if DEBUG
        let arguments = Set(ProcessInfo.processInfo.arguments)
        if arguments.contains("-LIFEBOARD_ENABLE_\(argument)") { return true }
        if arguments.contains("-LIFEBOARD_DISABLE_\(argument)") { return false }
#endif
        let sharedDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName)
        if let override = sharedDefaults?.object(forKey: key) as? Bool
            ?? UserDefaults.standard.object(forKey: key) as? Bool {
            return override
        }
        return true
    }
}
