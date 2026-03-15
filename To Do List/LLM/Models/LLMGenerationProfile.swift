import Foundation

struct LLMGenerationProfile {
    let timeoutSeconds: TimeInterval
    let regularMaxRawTokens: Int
    let reasoningMaxRawTokens: Int
    let regularMinAnswerTokensAfterAnswerPhase: Int
    let reasoningMinAnswerTokensAfterAnswerPhase: Int
    let temperature: Float
    let topP: Float
    let repetitionPenalty: Float?
    let repetitionContextSize: Int
    let stripReasoningBlocks: Bool
    let stripTemplateArtifacts: Bool
    let maxVisibleLines: Int?
    let maxVisibleCharacters: Int?

    init(
        timeoutSeconds: TimeInterval,
        regularMaxRawTokens: Int = 4_096,
        reasoningMaxRawTokens: Int? = nil,
        regularMinAnswerTokensAfterAnswerPhase: Int = 0,
        reasoningMinAnswerTokensAfterAnswerPhase: Int? = nil,
        temperature: Float = 0.5,
        topP: Float = 1.0,
        repetitionPenalty: Float? = nil,
        repetitionContextSize: Int = 20,
        stripReasoningBlocks: Bool = false,
        stripTemplateArtifacts: Bool = false,
        maxVisibleLines: Int? = nil,
        maxVisibleCharacters: Int? = nil
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.regularMaxRawTokens = regularMaxRawTokens
        self.reasoningMaxRawTokens = reasoningMaxRawTokens ?? regularMaxRawTokens
        self.regularMinAnswerTokensAfterAnswerPhase = regularMinAnswerTokensAfterAnswerPhase
        self.reasoningMinAnswerTokensAfterAnswerPhase = reasoningMinAnswerTokensAfterAnswerPhase ?? regularMinAnswerTokensAfterAnswerPhase
        self.temperature = temperature
        self.topP = topP
        self.repetitionPenalty = repetitionPenalty
        self.repetitionContextSize = repetitionContextSize
        self.stripReasoningBlocks = stripReasoningBlocks
        self.stripTemplateArtifacts = stripTemplateArtifacts
        self.maxVisibleLines = maxVisibleLines
        self.maxVisibleCharacters = maxVisibleCharacters
    }

    func maxRawTokens(isReasoningModel: Bool) -> Int {
        isReasoningModel ? reasoningMaxRawTokens : regularMaxRawTokens
    }

    func minAnswerTokensAfterAnswerPhase(isReasoningModel: Bool) -> Int {
        isReasoningModel ? reasoningMinAnswerTokensAfterAnswerPhase : regularMinAnswerTokensAfterAnswerPhase
    }

    static let chat = LLMGenerationProfile(
        timeoutSeconds: 0,
        regularMaxRawTokens: 256,
        reasoningMaxRawTokens: 512,
        regularMinAnswerTokensAfterAnswerPhase: 96,
        reasoningMinAnswerTokensAfterAnswerPhase: 128,
        temperature: 0.2,
        topP: 0.9,
        repetitionPenalty: 1.1,
        repetitionContextSize: 64,
        stripReasoningBlocks: true,
        stripTemplateArtifacts: true,
        maxVisibleLines: nil,
        maxVisibleCharacters: 2_400
    )
    static let addTaskSuggestion = LLMGenerationProfile(timeoutSeconds: 6)
    static let dynamicChips = LLMGenerationProfile(timeoutSeconds: 6)
    static let dailyBrief = LLMGenerationProfile(timeoutSeconds: 8)
    static let topThree = LLMGenerationProfile(timeoutSeconds: 10)
    static let breakdown = LLMGenerationProfile(timeoutSeconds: 10)
    static let chatPlanJSON = LLMGenerationProfile(timeoutSeconds: 12)
}

struct LLMVisibleTextFormattingResult {
    let text: String
    let removedReasoningBlocks: Bool
    let removedTemplateArtifacts: Bool
    let trimmedToVisibleLines: Bool
    let trimmedToVisibleCharacters: Bool

    var wasTrimmed: Bool {
        trimmedToVisibleLines || trimmedToVisibleCharacters
    }
}

struct LLMChatQualityAssessment {
    let isAcceptable: Bool
    let shouldRetry: Bool
    let reasons: [String]
}

enum LLMChatQualityGate {
    private static let genericIntroPrefixes = [
        "i am eva",
        "i'm eva",
        "i am ready to be your",
        "i'm ready to be your",
        "okay, i'm ready",
        "okay, i am ready",
        "i will focus on providing clear",
        "i am your proactive personal assistant",
        "i'm your proactive personal assistant",
    ]

    private static let capabilitiesPrompts = [
        "what can you do",
        "who are you",
        "introduce yourself",
        "what are you",
    ]

    static func assess(
        _ text: String,
        userPrompt: String?,
        terminationReason: String?
    ) -> LLMChatQualityAssessment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return LLMChatQualityAssessment(
                isAcceptable: false,
                shouldRetry: true,
                reasons: ["empty_output"]
            )
        }

        let lowercased = trimmed.lowercased()
        var reasons: [String] = []

        if looksLikeGenericIntro(lowercased, userPrompt: userPrompt) {
            reasons.append("generic_intro")
        }
        if hasRepetitionLoop(lowercased) {
            reasons.append("repetition_loop")
        }
        if terminationReason == "raw_cap" &&
            (reasons.isEmpty == false || trimmed.count > 1_000) {
            reasons.append("raw_cap_low_utility")
        }

        return LLMChatQualityAssessment(
            isAcceptable: reasons.isEmpty,
            shouldRetry: reasons.isEmpty == false,
            reasons: reasons
        )
    }

    private static func looksLikeGenericIntro(
        _ lowercased: String,
        userPrompt: String?
    ) -> Bool {
        guard genericIntroPrefixes.contains(where: lowercased.hasPrefix) else { return false }
        guard let userPrompt else { return true }
        let normalizedPrompt = userPrompt.lowercased()
        return capabilitiesPrompts.contains(where: normalizedPrompt.contains) == false
    }

    private static func hasRepetitionLoop(_ lowercased: String) -> Bool {
        let words = tokenizedWords(from: lowercased)
        guard words.count >= 12 else { return false }

        if maxRepeatedRun(in: words) >= 5 {
            return true
        }

        let tail = Array(words.suffix(24))
        if let dominantTailCount = dominantTokenCount(in: tail),
           dominantTailCount >= 10 {
            return true
        }

        if maxNGramRepeats(in: words, size: 2) >= 4 {
            return true
        }

        if maxNGramRepeats(in: words, size: 3) >= 3 {
            return true
        }

        return false
    }

    private static func tokenizedWords(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }

    private static func maxRepeatedRun(in words: [String]) -> Int {
        guard let first = words.first else { return 0 }
        var maxRun = 1
        var currentRun = 1
        var currentWord = first

        for word in words.dropFirst() {
            if word == currentWord {
                currentRun += 1
            } else {
                maxRun = max(maxRun, currentRun)
                currentRun = 1
                currentWord = word
            }
        }

        return max(maxRun, currentRun)
    }

    private static func dominantTokenCount(in words: [String]) -> Int? {
        guard words.isEmpty == false else { return nil }
        let counts = words.reduce(into: [String: Int]()) { partial, word in
            partial[word, default: 0] += 1
        }
        return counts.values.max()
    }

    private static func maxNGramRepeats(in words: [String], size: Int) -> Int {
        guard size > 0, words.count >= size else { return 0 }
        var counts: [String: Int] = [:]
        for index in 0...(words.count - size) {
            let ngram = words[index..<(index + size)].joined(separator: " ")
            counts[ngram, default: 0] += 1
        }
        return counts.values.max() ?? 0
    }
}

enum LLMChatTextSanitizer {
    private static let controlMarkers: [String] = [
        "<end_of_turn>",
        "<|end_of_turn|>",
        "<|im_end|>",
        "<|im_start|>",
        "<|end|>",
        "<|eot_id|>",
        "<start_of_turn>",
        "<｜User｜>",
        "<｜Assistant｜>",
        "<｜tool▁outputs▁begin｜>",
        "<｜tool▁outputs▁end｜>",
        "<｜tool▁calls▁begin｜>",
        "<｜tool▁calls▁end｜>",
        "<｜end▁of▁sentence｜>",
        "<｜begin▁of▁sentence｜>",
    ]

    struct Result {
        let text: String
        let removedReasoningBlocks: Bool
        let removedTemplateArtifacts: Bool
    }

    static func sanitize(
        _ text: String,
        stripReasoningBlocks: Bool,
        stripTemplateArtifacts: Bool,
        preserveThinkingBlocks: Bool = false
    ) -> Result {
        var sanitized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var removedReasoningBlocks = false
        var removedTemplateArtifacts = false

        if stripReasoningBlocks && preserveThinkingBlocks == false {
            let stripped = stripThinkBlocks(from: sanitized)
            sanitized = stripped.text
            removedReasoningBlocks = stripped.removed
        }

        if stripTemplateArtifacts {
            let stripped = stripTemplateControlArtifacts(from: sanitized)
            sanitized = stripped.text
            removedTemplateArtifacts = stripped.removed
        }

        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(
            text: sanitized,
            removedReasoningBlocks: removedReasoningBlocks,
            removedTemplateArtifacts: removedTemplateArtifacts
        )
    }

    static func sanitizeForPromptHistory(
        _ text: String,
        stripReasoningBlocks: Bool
    ) -> String? {
        let sanitized = sanitize(
            text,
            stripReasoningBlocks: stripReasoningBlocks,
            stripTemplateArtifacts: true
        ).text

        let collapsed = sanitized
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.isEmpty == false else { return nil }
        return collapsed
    }

    static func sanitizeForDisplay(_ text: String) -> String {
        sanitize(
            text,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true,
            preserveThinkingBlocks: true
        ).text
    }

    private static func stripThinkBlocks(from text: String) -> (text: String, removed: Bool) {
        let pattern = "<think>.*?(</think>|$)"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return (text, false)
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let removed = regex.firstMatch(in: text, options: [], range: range) != nil
        let stripped = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
        return (stripped, removed)
    }

    private static func stripTemplateControlArtifacts(from text: String) -> (text: String, removed: Bool) {
        let earliestMarker = controlMarkers
            .compactMap { marker -> Range<String.Index>? in
                text.range(of: marker)
            }
            .min(by: { $0.lowerBound < $1.lowerBound })

        var stripped = text
        var removed = false

        if let markerRange = earliestMarker {
            stripped = String(text[..<markerRange.lowerBound])
            removed = true
        }

        let normalized = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        let fenceCount = normalized.components(separatedBy: "```").count - 1
        if fenceCount % 2 != 0,
           let lastFenceRange = normalized.range(of: "```", options: .backwards) {
            stripped = String(normalized[..<lastFenceRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            removed = true
        } else {
            stripped = normalized
        }

        return (stripped, removed)
    }
}

enum LLMVisibleOutputFormatter {
    static func formatVisibleText(_ rawText: String, profile: LLMGenerationProfile) -> String {
        formatVisibleTextResult(rawText, profile: profile).text
    }

    static func formatVisibleTextResult(
        _ rawText: String,
        profile: LLMGenerationProfile
    ) -> LLMVisibleTextFormattingResult {
        let sanitized = LLMChatTextSanitizer.sanitize(
            rawText,
            stripReasoningBlocks: profile.stripReasoningBlocks,
            stripTemplateArtifacts: profile.stripTemplateArtifacts
        )

        var visibleText = sanitized.text
        var trimmedToVisibleLines = false
        var trimmedToVisibleCharacters = false

        if let maxVisibleLines = profile.maxVisibleLines {
            let trimmedLines = trimToVisibleLines(visibleText, maxVisibleLines: maxVisibleLines)
            visibleText = trimmedLines.text
            trimmedToVisibleLines = trimmedLines.wasTrimmed
        }

        if let maxVisibleCharacters = profile.maxVisibleCharacters,
           visibleText.count > maxVisibleCharacters {
            visibleText = String(visibleText.prefix(maxVisibleCharacters))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            trimmedToVisibleCharacters = true
        }

        if trimmedToVisibleLines || trimmedToVisibleCharacters {
            visibleText = appendEllipsisIfNeeded(visibleText)
        }

        return LLMVisibleTextFormattingResult(
            text: visibleText,
            removedReasoningBlocks: sanitized.removedReasoningBlocks,
            removedTemplateArtifacts: sanitized.removedTemplateArtifacts,
            trimmedToVisibleLines: trimmedToVisibleLines,
            trimmedToVisibleCharacters: trimmedToVisibleCharacters
        )
    }

    private static func trimToVisibleLines(
        _ text: String,
        maxVisibleLines: Int
    ) -> (text: String, wasTrimmed: Bool) {
        guard maxVisibleLines > 0 else {
            return ("", !text.isEmpty)
        }

        let lines = text.components(separatedBy: .newlines)
        var keptLines: [String] = []
        var nonEmptyLineCount = 0
        var wasTrimmed = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.isEmpty == false else { continue }
            if nonEmptyLineCount >= maxVisibleLines {
                wasTrimmed = true
                break
            }
            keptLines.append(line)
            nonEmptyLineCount += 1
        }

        if keptLines.count < lines.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count {
            wasTrimmed = true
        }

        return (keptLines.joined(separator: "\n"), wasTrimmed)
    }

    private static func appendEllipsisIfNeeded(_ text: String) -> String {
        guard text.isEmpty == false else { return text }
        if text.hasSuffix("...") {
            return text
        }
        return text + "..."
    }
}

struct LLMChatGenerationLimiter {
    let maxRawTokens: Int
    let minAnswerTokensAfterAnswerPhase: Int

    private(set) var answerPhaseStartTokenCount: Int?

    mutating func markAnswerPhaseStarted(currentTokenCount: Int) {
        guard answerPhaseStartTokenCount == nil else { return }
        answerPhaseStartTokenCount = max(1, currentTokenCount)
    }

    mutating func stopReason(currentTokenCount: Int) -> String? {
        guard currentTokenCount > 0 else { return nil }

        if let answerPhaseStartTokenCount {
            guard currentTokenCount >= maxRawTokens else { return nil }
            let answerTokenCount = currentTokenCount - answerPhaseStartTokenCount + 1
            guard answerTokenCount >= minAnswerTokensAfterAnswerPhase else { return nil }
            return currentTokenCount > maxRawTokens ? "answer_floor_reached" : "raw_cap"
        }

        let graceLimit = maxRawTokens + max(0, minAnswerTokensAfterAnswerPhase)
        if currentTokenCount >= graceLimit {
            return "raw_cap"
        }
        return nil
    }
}
