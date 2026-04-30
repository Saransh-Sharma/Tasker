import Foundation
import MLXLMCommon

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
    let preservesVisibleThinking: Bool

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
        maxVisibleCharacters: Int? = nil,
        preservesVisibleThinking: Bool = false
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
        self.preservesVisibleThinking = preservesVisibleThinking
    }

    func maxRawTokens(isReasoningModel: Bool) -> Int {
        isReasoningModel ? reasoningMaxRawTokens : regularMaxRawTokens
    }

    func minAnswerTokensAfterAnswerPhase(isReasoningModel: Bool) -> Int {
        isReasoningModel ? reasoningMinAnswerTokensAfterAnswerPhase : regularMinAnswerTokensAfterAnswerPhase
    }

    static let chat = LLMGenerationProfile(
        timeoutSeconds: 0,
        regularMaxRawTokens: 384,
        reasoningMaxRawTokens: 1_024,
        regularMinAnswerTokensAfterAnswerPhase: 128,
        reasoningMinAnswerTokensAfterAnswerPhase: 256,
        temperature: 0.2,
        topP: 0.9,
        repetitionPenalty: 1.1,
        repetitionContextSize: 64,
        stripReasoningBlocks: true,
        stripTemplateArtifacts: true,
        maxVisibleLines: nil,
        maxVisibleCharacters: 2_400
    )

    static func chatProfile(
        for model: ModelConfiguration,
        requestOptions: LLMGenerationRequestOptions
    ) -> LLMGenerationProfile {
        let tuning = model.chatTuningProfile
        let supportsVisibleThinking = requestOptions.showsVisibleThinking && model.supportsVisibleThinking
        return LLMGenerationProfile(
            timeoutSeconds: 0,
            regularMaxRawTokens: tuning.answerOnlyMaxRawTokens,
            reasoningMaxRawTokens: supportsVisibleThinking ? tuning.thinkingMaxRawTokens : tuning.answerOnlyMaxRawTokens,
            regularMinAnswerTokensAfterAnswerPhase: tuning.minAnswerTokensAfterAnswerPhase,
            reasoningMinAnswerTokensAfterAnswerPhase: tuning.minAnswerTokensAfterAnswerPhase,
            temperature: supportsVisibleThinking ? tuning.temperature : 0.2,
            topP: supportsVisibleThinking ? tuning.topP : 0.9,
            repetitionPenalty: supportsVisibleThinking ? tuning.repetitionPenalty : 1.1,
            repetitionContextSize: 64,
            stripReasoningBlocks: supportsVisibleThinking == false,
            stripTemplateArtifacts: true,
            maxVisibleLines: nil,
            maxVisibleCharacters: tuning.maxVisibleCharacters,
            preservesVisibleThinking: supportsVisibleThinking
        )
    }
    static let addTaskSuggestion = LLMGenerationProfile(timeoutSeconds: 6)
    static let dynamicChips = LLMGenerationProfile(timeoutSeconds: 6)
    static let dailyBrief = LLMGenerationProfile(timeoutSeconds: 8)
    static let topThree = LLMGenerationProfile(timeoutSeconds: 10)
    static let breakdown = LLMGenerationProfile(timeoutSeconds: 10)
    static let chatPlanJSON = LLMGenerationProfile(
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
    let hardFailureReasons: [String]
    let softWarningReasons: [String]
    let repetitionDiagnostics: LLMChatRepetitionDiagnostics?
    let qualityTextSource: String
}

struct LLMChatRepetitionDiagnostics {
    let confidence: String
    let detector: String
    let repeatedLineCount: Int
    let repeatedSentenceCount: Int
    let tailLoopDetected: Bool
    let repeatedTailPreview: String?
}

struct LLMChatOutputAssessment {
    let finalOutput: String
    let salvageOutput: String
    let qualityAssessment: LLMChatQualityAssessment
    let templateMismatch: Bool
    let thinkingOnlyOutput: Bool
    let removedReasoningBlocks: Bool
    let removedTemplateArtifacts: Bool
    let thinkingLength: Int
    let answerLength: Int
    let hasVisibleThinking: Bool
    let hasAnswer: Bool
    let extractionMode: String
    let rawCapHitStage: String?
}

struct LLMVisibleThinkingExtractionResult {
    let normalizedText: String
    let thinkingText: String?
    let answerText: String?
    let mode: String
    let isOpenEnded: Bool

    var hasVisibleThinking: Bool {
        thinkingText?.isEmpty == false
    }

    var hasAnswer: Bool {
        answerText?.isEmpty == false
    }
}

struct LLMTemplateCompatibilityProfile {
    let identifier: String
    let leadingRolePreambles: [String]
    let terminalControlMarkers: [String]
}

enum LLMTemplateCompatibility {
    private static let cacheLock = NSLock()
    private static var profileCache: [String: LLMTemplateCompatibilityProfile] = [:]
    private static let qwenProfile = LLMTemplateCompatibilityProfile(
        identifier: "qwen",
        leadingRolePreambles: [
            "<|im_start|>",
            "<|im_start|>assistant",
            "<|im_start|>user",
            "<|im_start|>system",
            "<｜Assistant｜>",
            "<｜assistant｜>",
            "<｜User｜>",
            "<｜user｜>",
            "<｜System｜>",
            "<｜system｜>"
        ],
        terminalControlMarkers: [
            "<end_of_turn>",
            "<|end_of_turn|>",
            "<|im_end|>",
            "<|end|>",
            "<|eot_id|>",
            "<start_of_turn>",
            "<｜tool▁outputs▁begin｜>",
            "<｜tool▁outputs▁end｜>",
            "<｜tool▁calls▁begin｜>",
            "<｜tool▁calls▁end｜>",
            "<｜end▁of▁sentence｜>",
            "<｜begin▁of▁sentence｜>"
        ]
    )

    private static let genericProfile = LLMTemplateCompatibilityProfile(
        identifier: "generic",
        leadingRolePreambles: [
            "<|im_start|>",
            "<|im_start|>assistant",
            "<|im_start|>user",
            "<|im_start|>system",
            "<｜Assistant｜>",
            "<｜assistant｜>",
            "<｜User｜>",
            "<｜user｜>",
            "<｜System｜>",
            "<｜system｜>"
        ],
        terminalControlMarkers: [
            "<end_of_turn>",
            "<|end_of_turn|>",
            "<|im_end|>",
            "<|end|>",
            "<|eot_id|>",
            "<start_of_turn>",
            "<｜end▁of▁sentence｜>",
            "<｜begin▁of▁sentence｜>"
        ]
    )

    static func profile(for modelName: String?) -> LLMTemplateCompatibilityProfile {
        let cacheKey = modelName ?? "__generic__"
        cacheLock.lock()
        if let cached = profileCache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let resolvedProfile: LLMTemplateCompatibilityProfile
        if let metadata = tokenizerMetadata(for: modelName),
           metadata.localizedCaseInsensitiveContains("qwen") {
            resolvedProfile = qwenProfile
        } else if modelName?.localizedCaseInsensitiveContains("qwen") == true {
            resolvedProfile = qwenProfile
        } else {
            resolvedProfile = genericProfile
        }

        cacheLock.lock()
        profileCache[cacheKey] = resolvedProfile
        cacheLock.unlock()
        return resolvedProfile
    }

    private static func tokenizerMetadata(for modelName: String?) -> String? {
        guard let modelName,
              let applicationSupportDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
              ).first,
              let folderURL = LLMPersistedModelSelection.modelFolderURL(
                for: modelName,
                applicationSupportDirectory: applicationSupportDirectory
              ) else {
            return nil
        }

        let candidateFiles = [
            "tokenizer_config.json",
            "tokenizer.json",
            "config.json"
        ]

        var combinedMetadata = ""
        for file in candidateFiles {
            let url = folderURL.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data.prefix(32_768), encoding: .utf8),
                  text.isEmpty == false else {
                continue
            }
            combinedMetadata.append(text)
            if text.localizedCaseInsensitiveContains("qwen") {
                return combinedMetadata
            }
        }

        return combinedMetadata.isEmpty ? nil : combinedMetadata
    }
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
                reasons: ["empty_output"],
                hardFailureReasons: ["empty_output"],
                softWarningReasons: [],
                repetitionDiagnostics: nil,
                qualityTextSource: "sanitized_full"
            )
        }

        let lowercased = trimmed.lowercased()
        let repetitionDiagnostics = repetitionDiagnostics(for: trimmed)
        var hardFailureReasons: [String] = []
        var softWarningReasons: [String] = []

        if looksLikeGenericIntro(lowercased, userPrompt: userPrompt) {
            let lowValueIntro = looksLikeLowValueIntro(trimmed, userPrompt: userPrompt)
            if terminationReason == "eos" {
                if lowValueIntro {
                    hardFailureReasons.append("generic_intro")
                } else {
                    softWarningReasons.append("generic_intro")
                }
            } else {
                hardFailureReasons.append("generic_intro")
            }
        }

        switch repetitionDiagnostics.confidence {
        case "high_confidence_loop":
            hardFailureReasons.append("repetition_loop")
        case "low_confidence_structured_repetition":
            softWarningReasons.append("low_confidence_structured_repetition")
        default:
            break
        }

        if terminationReason == "answer_floor_reached" &&
            hardFailureReasons.isEmpty &&
            looksLowValueAtRawCap(trimmed) {
            softWarningReasons.append("answer_floor_low_utility")
        }

        let reasons = hardFailureReasons.isEmpty ? softWarningReasons : hardFailureReasons
        return LLMChatQualityAssessment(
            isAcceptable: hardFailureReasons.isEmpty,
            shouldRetry: hardFailureReasons.isEmpty == false,
            reasons: reasons,
            hardFailureReasons: hardFailureReasons,
            softWarningReasons: softWarningReasons,
            repetitionDiagnostics: repetitionDiagnostics.detector == "none" ? nil : repetitionDiagnostics,
            qualityTextSource: "sanitized_full"
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

    private static func looksLikeLowValueIntro(_ text: String, userPrompt: String?) -> Bool {
        let normalized = normalizeStructuredUnit(text)
        if normalized.count < 160 {
            return true
        }
        guard let userPrompt else { return false }
        let promptTokens = Set(tokenizedMeaningfulWords(from: userPrompt.lowercased()))
        let outputTokens = Set(tokenizedMeaningfulWords(from: normalized))
        return promptTokens.isDisjoint(with: outputTokens)
    }

    private static func looksLowValueAtRawCap(_ text: String) -> Bool {
        let normalized = normalizeStructuredUnit(text)
        return normalized.count < 120
    }

    private static func repetitionDiagnostics(for text: String) -> LLMChatRepetitionDiagnostics {
        let repeatedLine = repeatedLineDiagnostics(in: text)
        let repeatedSentence = repeatedSentenceDiagnostics(in: text)
        let trailingLoop = trailingLoopDiagnostics(in: text)

        if repeatedLine.count >= 3 {
            return LLMChatRepetitionDiagnostics(
                confidence: "high_confidence_loop",
                detector: "repeated_lines",
                repeatedLineCount: repeatedLine.count,
                repeatedSentenceCount: 0,
                tailLoopDetected: trailingLoop.detected,
                repeatedTailPreview: repeatedLine.preview
            )
        }

        if repeatedSentence.count >= 2 {
            return LLMChatRepetitionDiagnostics(
                confidence: "high_confidence_loop",
                detector: "repeated_sentences",
                repeatedLineCount: 0,
                repeatedSentenceCount: repeatedSentence.count,
                tailLoopDetected: trailingLoop.detected,
                repeatedTailPreview: repeatedSentence.preview
            )
        }

        if trailingLoop.detected {
            return LLMChatRepetitionDiagnostics(
                confidence: "high_confidence_loop",
                detector: "trailing_loop",
                repeatedLineCount: trailingLoop.repeatedLineCount,
                repeatedSentenceCount: 0,
                tailLoopDetected: true,
                repeatedTailPreview: trailingLoop.preview
            )
        }

        if repeatedLine.count == 2 || repeatedSentence.count == 1 {
            return LLMChatRepetitionDiagnostics(
                confidence: "low_confidence_structured_repetition",
                detector: repeatedLine.count == 2 ? "repeated_lines" : "repeated_sentences",
                repeatedLineCount: repeatedLine.count,
                repeatedSentenceCount: repeatedSentence.count,
                tailLoopDetected: trailingLoop.detected,
                repeatedTailPreview: repeatedLine.preview ?? repeatedSentence.preview
            )
        }

        return LLMChatRepetitionDiagnostics(
            confidence: "none",
            detector: "none",
            repeatedLineCount: 0,
            repeatedSentenceCount: 0,
            tailLoopDetected: false,
            repeatedTailPreview: nil
        )
    }

    private static func repeatedLineDiagnostics(in text: String) -> (count: Int, preview: String?) {
        let normalizedLines = text
            .components(separatedBy: .newlines)
            .map(normalizeStructuredUnit)
            .filter(isMeaningfulStructuredUnit)

        guard normalizedLines.count >= 2 else { return (0, nil) }
        let counts = normalizedLines.reduce(into: [String: Int]()) { partial, line in
            partial[line, default: 0] += 1
        }
        guard let candidate = counts.max(by: { $0.value < $1.value }), candidate.value >= 2 else {
            return (0, nil)
        }
        return (candidate.value, candidate.key)
    }

    private static func repeatedSentenceDiagnostics(in text: String) -> (count: Int, preview: String?) {
        let normalizedSentences = splitSentences(from: text)
            .map(normalizeStructuredUnit)
            .filter { normalized in
                isMeaningfulStructuredUnit(normalized) && normalized.count >= 32
            }

        guard normalizedSentences.count >= 2 else { return (0, nil) }
        let counts = normalizedSentences.reduce(into: [String: Int]()) { partial, sentence in
            partial[sentence, default: 0] += 1
        }
        guard let candidate = counts.max(by: { $0.value < $1.value }), candidate.value >= 2 else {
            return (0, nil)
        }
        return (candidate.value, candidate.key)
    }

    private static func trailingLoopDiagnostics(in text: String) -> (detected: Bool, repeatedLineCount: Int, preview: String?) {
        let normalizedLines = text
            .components(separatedBy: .newlines)
            .map(normalizeStructuredUnit)
            .filter(isMeaningfulStructuredUnit)
        let tail = Array(normalizedLines.suffix(4))
        guard tail.count >= 3 else { return (false, 0, nil) }
        if Set(tail).count == 1 {
            return (true, tail.count, tail.last)
        }
        if tail.count >= 4, Set(tail.suffix(3)).count == 1 {
            return (true, 3, tail.last)
        }
        return (false, 0, nil)
    }

    private static func splitSentences(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private static func normalizeStructuredUnit(_ text: String) -> String {
        var normalized = text.lowercased()
        normalized = normalized.replacingOccurrences(
            of: #"^\s*(?:[-*•]|\d+[.)]|[a-z][.)])\s*"#,
            with: "",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(of: #"\*\*|__|`"#, with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #"\[[^\]]+\]\([^)]+\)"#, with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isMeaningfulStructuredUnit(_ text: String) -> Bool {
        guard text.count >= 10 else { return false }
        let ignoredHeaders: Set<String> = [
            "today",
            "next",
            "focus",
            "context",
            "summary",
            "key information from the summary",
            "context analysis"
        ]
        if ignoredHeaders.contains(text) {
            return false
        }
        return tokenizedMeaningfulWords(from: text).count >= 2
    }

    private static func tokenizedMeaningfulWords(from text: String) -> [String] {
        let ignoredTokens: Set<String> = [
            "the", "and", "for", "with", "that", "this", "from", "into", "today",
            "next", "focus", "context", "plan", "task", "tasks", "project", "projects"
        ]
        return text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && ignoredTokens.contains($0) == false }
    }
}

enum LLMChatOutputClassifier {
    private static let thinkMarkers = [
        "<think>",
        "</think>"
    ]

    static func assess(
        rawOutput: String,
        modelName: String,
        userPrompt: String,
        terminationReason: String?
    ) -> LLMChatOutputAssessment {
        let model = ModelConfiguration.getModelByName(modelName)
        let sanitizedResult = LLMChatTextSanitizer.sanitize(
            rawOutput,
            stripReasoningBlocks: true,
            stripTemplateArtifacts: true,
            modelName: modelName
        )
        let displayResult = LLMChatTextSanitizer.sanitize(
            rawOutput,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true,
            modelName: modelName,
            preserveThinkingBlocks: model?.supportsVisibleThinking == true
        )
        let sanitizedOutput = sanitizedResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayOutput = displayResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let visibleThinking = LLMVisibleThinkingExtractor.extract(
            from: displayOutput,
            modelName: modelName,
            closeOpenThinkingBlock: true
        )
        let rawTrimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawNonEmpty = rawTrimmed.isEmpty == false

        let salvageOutput = rawNonEmpty && sanitizedOutput.isEmpty
            ? LLMChatTextSanitizer.salvageRecoverableText(
                rawOutput,
                stripReasoningBlocks: true,
                modelName: modelName
            )
            : sanitizedOutput
        let salvageVisibleText = rawNonEmpty && sanitizedOutput.isEmpty
            ? LLMChatTextSanitizer.sanitize(
                salvageOutput,
                stripReasoningBlocks: false,
                stripTemplateArtifacts: true,
                modelName: modelName
            ).text
            : salvageOutput
        let hasRecoverableVisibleContent = salvageVisibleText.isEmpty == false
        let rawLowercased = rawTrimmed.lowercased()
        let hasVisibleThinking = visibleThinking.hasVisibleThinking
        let answerCandidate = visibleThinking.answerText?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let answerForQuality = hasVisibleThinking
            ? (answerCandidate ?? "")
            : sanitizedOutput
        let thinkingOnlyOutput = rawNonEmpty &&
            answerForQuality.isEmpty &&
            (hasVisibleThinking ||
             (sanitizedOutput.isEmpty &&
              hasRecoverableVisibleContent == false &&
              (sanitizedResult.removedReasoningBlocks ||
               thinkMarkers.contains(where: rawLowercased.contains))))
        let templateMismatch = rawNonEmpty &&
            sanitizedOutput.isEmpty &&
            hasRecoverableVisibleContent &&
            hasVisibleThinking == false
        let rawCapHitStage: String?
        if terminationReason == "raw_cap" || terminationReason == "answer_floor_reached" {
            if hasVisibleThinking && (answerCandidate?.isEmpty ?? true) {
                rawCapHitStage = "thinking_only"
            } else if hasVisibleThinking {
                rawCapHitStage = "post_answer"
            } else {
                rawCapHitStage = "pre_answer"
            }
        } else {
            rawCapHitStage = nil
        }

        let qualityTextSource = hasVisibleThinking && answerCandidate?.isEmpty == false
            ? "answer"
            : "sanitized_full"
        let qualityAssessment: LLMChatQualityAssessment
        if templateMismatch {
            qualityAssessment = LLMChatQualityAssessment(
                isAcceptable: false,
                shouldRetry: false,
                reasons: ["template_mismatch"],
                hardFailureReasons: ["template_mismatch"],
                softWarningReasons: [],
                repetitionDiagnostics: nil,
                qualityTextSource: qualityTextSource
            )
        } else if thinkingOnlyOutput {
            qualityAssessment = LLMChatQualityAssessment(
                isAcceptable: false,
                shouldRetry: true,
                reasons: [hasVisibleThinking ? "answer_missing_after_thinking" : "thinking_only_output"],
                hardFailureReasons: [hasVisibleThinking ? "answer_missing_after_thinking" : "thinking_only_output"],
                softWarningReasons: [],
                repetitionDiagnostics: nil,
                qualityTextSource: qualityTextSource
            )
        } else if rawNonEmpty && sanitizedOutput.isEmpty {
            qualityAssessment = LLMChatQualityAssessment(
                isAcceptable: false,
                shouldRetry: true,
                reasons: ["empty_output"],
                hardFailureReasons: ["empty_output"],
                softWarningReasons: [],
                repetitionDiagnostics: nil,
                qualityTextSource: qualityTextSource
            )
        } else {
            let gateAssessment = LLMChatQualityGate.assess(
                answerForQuality.isEmpty == false ? answerForQuality : sanitizedOutput,
                userPrompt: userPrompt,
                terminationReason: terminationReason
            )
            qualityAssessment = LLMChatQualityAssessment(
                isAcceptable: gateAssessment.isAcceptable,
                shouldRetry: gateAssessment.shouldRetry,
                reasons: gateAssessment.reasons,
                hardFailureReasons: gateAssessment.hardFailureReasons,
                softWarningReasons: gateAssessment.softWarningReasons,
                repetitionDiagnostics: gateAssessment.repetitionDiagnostics,
                qualityTextSource: qualityTextSource
            )
        }

        return LLMChatOutputAssessment(
            finalOutput: hasVisibleThinking ? visibleThinking.normalizedText : sanitizedOutput,
            salvageOutput: templateMismatch ? salvageVisibleText : "",
            qualityAssessment: qualityAssessment,
            templateMismatch: templateMismatch,
            thinkingOnlyOutput: thinkingOnlyOutput,
            removedReasoningBlocks: sanitizedResult.removedReasoningBlocks,
            removedTemplateArtifacts: sanitizedResult.removedTemplateArtifacts || displayResult.removedTemplateArtifacts,
            thinkingLength: visibleThinking.thinkingText?.count ?? 0,
            answerLength: answerCandidate?.count ?? 0,
            hasVisibleThinking: hasVisibleThinking,
            hasAnswer: (answerCandidate?.isEmpty == false) || (hasVisibleThinking == false && sanitizedOutput.isEmpty == false),
            extractionMode: visibleThinking.mode,
            rawCapHitStage: rawCapHitStage
        )
    }
}

enum LLMVisibleThinkingExtractor {
    private static let plainTextThinkingPrefixes = [
        "thinking process:",
        "thought process:",
        "reasoning:",
        "analysis:",
        "let me think:"
    ]

    private static let plainTextAnswerMarkers = [
        "final answer:",
        "answer:"
    ]

    static func extract(
        from text: String,
        modelName: String?,
        closeOpenThinkingBlock: Bool
    ) -> LLMVisibleThinkingExtractionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return LLMVisibleThinkingExtractionResult(
                normalizedText: "",
                thinkingText: nil,
                answerText: nil,
                mode: "none",
                isOpenEnded: false
            )
        }

        let model = modelName.flatMap { ModelConfiguration.getModelByName($0) }
        if let tagged = extractTaggedThinking(from: trimmed, closeOpenThinkingBlock: closeOpenThinkingBlock) {
            return tagged
        }

        guard let model, model.supportsVisibleThinking else {
            return LLMVisibleThinkingExtractionResult(
                normalizedText: trimmed,
                thinkingText: nil,
                answerText: trimmed,
                mode: "none",
                isOpenEnded: false
            )
        }

        if let plainText = extractPlainTextThinking(from: trimmed, closeOpenThinkingBlock: closeOpenThinkingBlock) {
            return plainText
        }

        return LLMVisibleThinkingExtractionResult(
            normalizedText: trimmed,
            thinkingText: nil,
            answerText: trimmed,
            mode: "none",
            isOpenEnded: false
        )
    }

    static func stripVisibleThinkingForPromptHistory(
        from text: String,
        modelName: String?
    ) -> (text: String, removed: Bool) {
        let extraction = extract(from: text, modelName: modelName, closeOpenThinkingBlock: true)
        guard extraction.hasVisibleThinking else {
            return (text, false)
        }
        let answerOnly = extraction.answerText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (answerOnly, true)
    }

    private static func extractTaggedThinking(
        from text: String,
        closeOpenThinkingBlock: Bool
    ) -> LLMVisibleThinkingExtractionResult? {
        guard let startRange = text.range(of: "<think>") else { return nil }

        if let endRange = text.range(of: "</think>") {
            let thinking = String(text[startRange.upperBound ..< endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = stripInlineAnswerRolePrefixes(
                String(text[endRange.upperBound...])
            )
            let normalized = composeNormalizedText(
                thinking: thinking,
                answer: answer,
                closeOpenThinkingBlock: true
            )
            return LLMVisibleThinkingExtractionResult(
                normalizedText: normalized,
                thinkingText: thinking.isEmpty ? nil : thinking,
                answerText: answer.isEmpty ? nil : answer,
                mode: "tagged",
                isOpenEnded: false
            )
        }

        let thinking = String(text[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = composeNormalizedText(
            thinking: thinking,
            answer: nil,
            closeOpenThinkingBlock: closeOpenThinkingBlock
        )
        return LLMVisibleThinkingExtractionResult(
            normalizedText: normalized,
            thinkingText: thinking.isEmpty ? nil : thinking,
            answerText: nil,
            mode: "tagged",
            isOpenEnded: closeOpenThinkingBlock == false
        )
    }

    private static func extractPlainTextThinking(
        from text: String,
        closeOpenThinkingBlock: Bool
    ) -> LLMVisibleThinkingExtractionResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        guard plainTextThinkingPrefixes.contains(where: { lowercased.hasPrefix($0) }) else {
            return nil
        }

        for marker in plainTextAnswerMarkers {
            if let range = lowercased.range(of: "\n\(marker)") ?? lowercased.range(of: marker) {
                let prefixDistance = lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
                let splitIndex = trimmed.index(trimmed.startIndex, offsetBy: prefixDistance)
                let thinking = String(trimmed[..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let markerRangeLength = lowercased.distance(from: range.lowerBound, to: range.upperBound)
                let markerStart = trimmed.index(trimmed.startIndex, offsetBy: prefixDistance)
                let answerStart = trimmed.index(markerStart, offsetBy: markerRangeLength)
                let answer = stripInlineAnswerRolePrefixes(String(trimmed[answerStart...]))
                let normalized = composeNormalizedText(
                    thinking: thinking,
                    answer: answer,
                    closeOpenThinkingBlock: true
                )
                return LLMVisibleThinkingExtractionResult(
                    normalizedText: normalized,
                    thinkingText: thinking.isEmpty ? nil : thinking,
                    answerText: answer.isEmpty ? nil : answer,
                    mode: "plaintext",
                    isOpenEnded: false
                )
            }
        }

        let normalized = composeNormalizedText(
            thinking: trimmed,
            answer: nil,
            closeOpenThinkingBlock: closeOpenThinkingBlock
        )
        return LLMVisibleThinkingExtractionResult(
            normalizedText: normalized,
            thinkingText: trimmed,
            answerText: nil,
            mode: "plaintext",
            isOpenEnded: closeOpenThinkingBlock == false
        )
    }

    private static func composeNormalizedText(
        thinking: String?,
        answer: String?,
        closeOpenThinkingBlock: Bool
    ) -> String {
        let trimmedThinking = thinking?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer?.trimmingCharacters(in: .whitespacesAndNewlines)

        var sections: [String] = []
        if let trimmedThinking, trimmedThinking.isEmpty == false {
            if closeOpenThinkingBlock {
                sections.append("<think>\n\(trimmedThinking)\n</think>")
            } else {
                sections.append("<think>\n\(trimmedThinking)")
            }
        }
        if let trimmedAnswer, trimmedAnswer.isEmpty == false {
            sections.append(trimmedAnswer)
        }
        return sections.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripInlineAnswerRolePrefixes(_ text: String) -> String {
        var stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "<｜Assistant｜>",
            "<｜assistant｜>",
            "<|im_start|>assistant",
            "<|im_start|>"
        ]

        while true {
            let current = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let prefix = prefixes.first(where: { current.lowercased().hasPrefix($0.lowercased()) }) else {
                return current
            }
            stripped = String(current.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

enum LLMChatTextSanitizer {
    struct Result {
        let text: String
        let removedReasoningBlocks: Bool
        let removedTemplateArtifacts: Bool
    }

    static func sanitize(
        _ text: String,
        stripReasoningBlocks: Bool,
        stripTemplateArtifacts: Bool,
        modelName: String? = nil,
        preserveThinkingBlocks: Bool = false
    ) -> Result {
        let compatibilityProfile = LLMTemplateCompatibility.profile(for: modelName)
        var sanitized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var removedReasoningBlocks = false
        var removedTemplateArtifacts = false

        if stripTemplateArtifacts {
            let stripped = stripLeadingTemplateRolePrefixes(
                from: sanitized,
                profile: compatibilityProfile
            )
            sanitized = stripped.text
            removedTemplateArtifacts = stripped.removed
        }

        if stripReasoningBlocks && preserveThinkingBlocks == false {
            let stripped = stripThinkBlocks(from: sanitized)
            sanitized = stripped.text
            removedReasoningBlocks = stripped.removed

            let plainTextThinking = LLMVisibleThinkingExtractor.stripVisibleThinkingForPromptHistory(
                from: sanitized,
                modelName: modelName
            )
            sanitized = plainTextThinking.text
            removedReasoningBlocks = removedReasoningBlocks || plainTextThinking.removed
        }

        if stripTemplateArtifacts {
            let stripped = stripTrailingTemplateControlArtifacts(
                from: sanitized,
                profile: compatibilityProfile
            )
            sanitized = stripped.text
            removedTemplateArtifacts = removedTemplateArtifacts || stripped.removed
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
        stripReasoningBlocks: Bool,
        modelName: String? = nil
    ) -> String? {
        var sanitized = sanitize(
            text,
            stripReasoningBlocks: stripReasoningBlocks,
            stripTemplateArtifacts: true,
            modelName: modelName
        ).text

        if stripReasoningBlocks {
            sanitized = LLMVisibleThinkingExtractor.stripVisibleThinkingForPromptHistory(
                from: sanitized,
                modelName: modelName
            ).text
        }

        let collapsed = sanitized
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.isEmpty == false else { return nil }
        return collapsed
    }

    static func sanitizeForDisplay(_ text: String, modelName: String? = nil) -> String {
        sanitize(
            text,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true,
            modelName: modelName,
            preserveThinkingBlocks: true
        ).text
    }

    static func salvageRecoverableText(
        _ text: String,
        stripReasoningBlocks: Bool,
        modelName: String? = nil
    ) -> String {
        let compatibilityProfile = LLMTemplateCompatibility.profile(for: modelName)
        var sanitized = stripLeadingTemplateRolePrefixes(
            from: text.replacingOccurrences(of: "\r\n", with: "\n"),
            profile: compatibilityProfile
        ).text

        if stripReasoningBlocks {
            sanitized = stripThinkBlocks(from: sanitized).text
        }

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func stripTrailingTemplateControlArtifacts(
        from text: String,
        profile: LLMTemplateCompatibilityProfile
    ) -> (text: String, removed: Bool) {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var removed = false

        while let boundary = trailingTemplateArtifactBoundary(in: sanitized, profile: profile) {
            sanitized = String(sanitized[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            removed = true
        }

        let fenceCount = sanitized.components(separatedBy: "```").count - 1
        if let fenceRange = sanitized.range(of: "```", options: .backwards),
           (fenceCount % 2) != 0 {
            sanitized = String(sanitized[..<fenceRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            removed = true
        }

        while let boundary = trailingTemplateArtifactBoundary(in: sanitized, profile: profile) {
            sanitized = String(sanitized[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            removed = true
        }

        return (sanitized, removed)
    }

    private static func stripLeadingTemplateRolePrefixes(
        from text: String,
        profile: LLMTemplateCompatibilityProfile
    ) -> (text: String, removed: Bool) {
        var sanitized = text
        var didStrip = false

        while true {
            let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return (trimmed, didStrip) }

            if let suffix = stripInitialRolePrefix(from: trimmed, profile: profile) {
                didStrip = true
                sanitized = suffix
                continue
            }

            break
        }

        return (sanitized, didStrip)
    }

    private static func stripInitialRolePrefix(
        from text: String,
        profile: LLMTemplateCompatibilityProfile
    ) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if trimmed.hasPrefix("<|im_start|>") {
            var suffix = String(trimmed.dropFirst("<|im_start|>".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedSuffix = suffix.lowercased()
            let rolePrefixes = ["assistant", "user", "system", "tool"]
            for role in rolePrefixes where lowercasedSuffix.hasPrefix(role) {
                suffix = String(suffix.dropFirst(role.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
            return suffix
        }

        for marker in profile.leadingRolePreambles where marker.hasPrefix("<|im_start|>") == false {
            if trimmed.lowercased().hasPrefix(marker.lowercased()) {
                return String(trimmed.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func trailingTemplateArtifactBoundary(
        in text: String,
        profile: LLMTemplateCompatibilityProfile
    ) -> String.Index? {
        profile.terminalControlMarkers
            .compactMap { marker -> String.Index? in
                guard let markerRange = text.range(of: marker, options: .backwards) else { return nil }
                let suffix = String(text[markerRange.lowerBound...])
                guard shouldTrimTrailingSuffix(suffix, profile: profile) else { return nil }
                return markerRange.lowerBound
            }
            .min()
    }

    private static func shouldTrimTrailingSuffix(
        _ suffix: String,
        profile: LLMTemplateCompatibilityProfile
    ) -> Bool {
        var remaining = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        var consumedTerminalMarker = false

        while true {
            let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            if let marker = profile.terminalControlMarkers.first(where: { trimmed.hasPrefix($0) }) {
                consumedTerminalMarker = true
                remaining = String(trimmed.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            break
        }

        guard consumedTerminalMarker else { return false }
        if remaining.isEmpty {
            return true
        }

        return stripInitialRolePrefix(from: remaining, profile: profile) != nil
    }
}

enum LLMVisibleOutputFormatter {
    static func formatVisibleText(
        _ rawText: String,
        profile: LLMGenerationProfile,
        modelName: String? = nil
    ) -> String {
        formatVisibleTextResult(rawText, profile: profile, modelName: modelName).text
    }

    static func formatVisibleTextResult(
        _ rawText: String,
        profile: LLMGenerationProfile,
        modelName: String? = nil,
        closeOpenThinkingBlock: Bool = false
    ) -> LLMVisibleTextFormattingResult {
        let sanitized = LLMChatTextSanitizer.sanitize(
            rawText,
            stripReasoningBlocks: profile.stripReasoningBlocks,
            stripTemplateArtifacts: profile.stripTemplateArtifacts,
            modelName: modelName,
            preserveThinkingBlocks: profile.preservesVisibleThinking
        )

        var visibleText = sanitized.text
        var trimmedToVisibleLines = false
        var trimmedToVisibleCharacters = false

        if profile.preservesVisibleThinking {
            let extraction = LLMVisibleThinkingExtractor.extract(
                from: visibleText,
                modelName: modelName,
                closeOpenThinkingBlock: closeOpenThinkingBlock
            )
            if let maxVisibleCharacters = profile.maxVisibleCharacters,
               extraction.hasVisibleThinking {
                let trimmedThinking = extraction.thinkingText.map {
                    trimVisibleCharacters($0, maxVisibleCharacters: maxVisibleCharacters)
                }
                let trimmedAnswer = extraction.answerText.map {
                    trimVisibleCharacters($0, maxVisibleCharacters: maxVisibleCharacters)
                }
                trimmedToVisibleCharacters = trimmedThinking?.wasTrimmed == true || trimmedAnswer?.wasTrimmed == true
                visibleText = normalizedVisibleThinkingText(
                    thinking: trimmedThinking?.text ?? extraction.thinkingText,
                    answer: trimmedAnswer?.text ?? extraction.answerText,
                    closeOpenThinkingBlock: closeOpenThinkingBlock
                )
            } else {
                visibleText = extraction.normalizedText
            }
        }

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

    private static func trimVisibleCharacters(
        _ text: String,
        maxVisibleCharacters: Int
    ) -> (text: String, wasTrimmed: Bool) {
        guard text.count > maxVisibleCharacters else {
            return (text, false)
        }
        return (
            String(text.prefix(maxVisibleCharacters)).trimmingCharacters(in: .whitespacesAndNewlines),
            true
        )
    }

    private static func normalizedVisibleThinkingText(
        thinking: String?,
        answer: String?,
        closeOpenThinkingBlock: Bool
    ) -> String {
        var sections: [String] = []
        if let thinking, thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let trimmed = thinking.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(
                closeOpenThinkingBlock
                    ? "<think>\n\(trimmed)\n</think>"
                    : "<think>\n\(trimmed)"
            )
        }
        if let answer, answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            sections.append(answer.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return sections.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
    private(set) var lastStopStage: String?

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
            lastStopStage = "post_answer"
            return currentTokenCount > maxRawTokens ? "answer_floor_reached" : "raw_cap"
        }

        let graceLimit = maxRawTokens + max(0, minAnswerTokensAfterAnswerPhase)
        if currentTokenCount >= graceLimit {
            lastStopStage = "pre_answer"
            return "raw_cap"
        }
        return nil
    }
}
