import Foundation
import MLXLMCommon

extension EvaInferenceRequest {
    /// Builds the wire request.
    ///
    /// System messages are still dropped here, and deliberately: the route's
    /// operating contract and EVA's persona live server-side in `prompts.ts`,
    /// where they can be corrected without an app release. What the client owns
    /// is the person's *own* instruction, which now travels as
    /// `userInstructions` rather than being composed into a system message and
    /// silently discarded.
    static func make(
        route: EvaCloudRoute,
        promptSnapshot: LLMChatPromptSnapshot,
        consentRevision: Int,
        userInstructions: EvaUserInstructions? = nil,
        contractVersion: Int = 1,
        surface: EvaSurface = .evaTab
    ) throws -> EvaInferenceRequest {
        let messages = promptSnapshot.messages.compactMap { message -> EvaCloudMessage? in
            switch message.role {
            case .user: EvaCloudMessage(role: .user, content: message.content)
            case .assistant: EvaCloudMessage(role: .assistant, content: message.content)
            case .system, .tool: nil
            }
        }
        return EvaInferenceRequest(
            requestId: UUID(),
            route: route,
            contractVersion: contractVersion,
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            turnContext: contractVersion >= 4 ? .current(surface: surface) : nil,
            messages: messages.isEmpty ? [EvaCloudMessage(role: .user, content: "Continue.")] : messages,
            context: promptSnapshot.cloudContext.map { $0.forContract(contractVersion) },
            // A v1 Worker's strict schema has no `userInstructions` property and
            // rejects the whole request rather than ignoring it.
            userInstructions: contractVersion >= 2 ? userInstructions : nil,
            clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            platform: EvaInstallationIdentity.platform,
            installationId: try EvaInstallationIdentity.resolved(),
            consentRevision: consentRevision,
            providerCapabilities: .init(streaming: true, structuredOutput: true, spokenOutput: true)
        )
    }
}
