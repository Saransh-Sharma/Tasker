import Foundation

struct LLMGenerationProfile {
    let timeoutSeconds: TimeInterval

    static let chat = LLMGenerationProfile(timeoutSeconds: 0)
    static let addTaskSuggestion = LLMGenerationProfile(timeoutSeconds: 6)
    static let dynamicChips = LLMGenerationProfile(timeoutSeconds: 6)
    static let dailyBrief = LLMGenerationProfile(timeoutSeconds: 8)
    static let topThree = LLMGenerationProfile(timeoutSeconds: 10)
    static let breakdown = LLMGenerationProfile(timeoutSeconds: 10)
    static let chatPlanJSON = LLMGenerationProfile(timeoutSeconds: 12)
}
