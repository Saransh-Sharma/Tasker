import Foundation

extension LLMGenerationProfile {
    static let addTaskSuggestion = LLMGenerationProfile(cloudRoute: .fieldSuggestion, timeoutSeconds: 6)
    static let universalInputClassification = LLMGenerationProfile(
        cloudRoute: .universalInputClassification,
        timeoutSeconds: 4,
        regularMaxRawTokens: 160,
        reasoningMaxRawTokens: 160,
        temperature: 0,
        topP: 0.8,
        stripReasoningBlocks: true,
        stripTemplateArtifacts: true,
        maxVisibleCharacters: 1_000
    )
    static let dynamicChips = LLMGenerationProfile(cloudRoute: .dynamicChips, timeoutSeconds: 6)
    static let dailyBrief = LLMGenerationProfile(cloudRoute: .dailyBrief, timeoutSeconds: 8)
    static let topThree = LLMGenerationProfile(cloudRoute: .topThree, timeoutSeconds: 10)
    static let breakdown = LLMGenerationProfile(cloudRoute: .taskBreakdown, timeoutSeconds: 10)
    static let journalAnswer = LLMGenerationProfile(cloudRoute: .journalAnswer, timeoutSeconds: 12)
    static let knowledgeAnswer = LLMGenerationProfile(cloudRoute: .knowledgeAnswer, timeoutSeconds: 12)
    static let shortcutsAnswer = LLMGenerationProfile(cloudRoute: .shortcutsAnswer, timeoutSeconds: 10)
    static let debugSmoke = LLMGenerationProfile(cloudRoute: .debugSmoke, timeoutSeconds: 8)
    static let chatPlanJSON = LLMGenerationProfile(
        cloudRoute: .plan,
        timeoutSeconds: 12,
        regularMaxRawTokens: 768,
        reasoningMaxRawTokens: 768,
        temperature: 0.1,
        topP: 0.85,
        repetitionPenalty: 1.05,
        repetitionContextSize: 64,
        stripReasoningBlocks: true,
        stripTemplateArtifacts: true
    )
    static let planRepairJSON = LLMGenerationProfile(
        cloudRoute: .planRepair,
        timeoutSeconds: 12,
        regularMaxRawTokens: 768,
        reasoningMaxRawTokens: 768,
        temperature: 0.1,
        topP: 0.85,
        stripReasoningBlocks: true,
        stripTemplateArtifacts: true
    )
}
