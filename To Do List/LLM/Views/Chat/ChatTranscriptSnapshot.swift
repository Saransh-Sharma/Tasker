import Foundation

struct ChatMessageRenderModel: Identifiable, Equatable {
    let id: UUID
    let role: Role
    let originalContent: String
    let displayContent: String
    let generatingTime: TimeInterval?
    let cardPayload: AssistantCardPayload?
    let thinkingText: String?
    let answerText: String?
    let isThinkingOpenEnded: Bool
    let markdownSourceHash: Int

    init(message: Message) {
        self.id = message.id
        self.role = message.role
        self.originalContent = message.content
        self.generatingTime = message.generatingTime
        self.cardPayload = AssistantCardCodec.decode(from: message.content)

        let cardFingerprint = Self.cardFingerprint(from: self.cardPayload)

        let displayContent: String
        if message.role == .assistant {
            displayContent = LLMChatTextSanitizer.sanitizeForDisplay(message.content)
        } else {
            displayContent = message.content
        }
        self.displayContent = displayContent

        let thinkingSplit = Self.processThinkingContent(displayContent)
        self.thinkingText = thinkingSplit.thinking
        self.answerText = thinkingSplit.answer
        self.isThinkingOpenEnded = thinkingSplit.isOpenEnded

        var hasher = Hasher()
        hasher.combine(message.role.rawValue)
        hasher.combine(displayContent)
        hasher.combine(cardFingerprint)
        self.markdownSourceHash = hasher.finalize()
    }

    init(
        id: UUID = UUID(),
        role: Role,
        originalContent: String,
        displayContent: String,
        generatingTime: TimeInterval? = nil
    ) {
        self.id = id
        self.role = role
        self.originalContent = originalContent
        self.displayContent = displayContent
        self.generatingTime = generatingTime
        self.cardPayload = AssistantCardCodec.decode(from: originalContent)
        let cardFingerprint = Self.cardFingerprint(from: self.cardPayload)
        let thinkingSplit = Self.processThinkingContent(displayContent)
        self.thinkingText = thinkingSplit.thinking
        self.answerText = thinkingSplit.answer
        self.isThinkingOpenEnded = thinkingSplit.isOpenEnded

        var hasher = Hasher()
        hasher.combine(role.rawValue)
        hasher.combine(displayContent)
        hasher.combine(cardFingerprint)
        self.markdownSourceHash = hasher.finalize()
    }

    private static func processThinkingContent(_ content: String) -> (
        thinking: String?,
        answer: String?,
        isOpenEnded: Bool
    ) {
        guard let startRange = content.range(of: "<think>") else {
            let answer = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return (nil, answer.isEmpty ? nil : answer, false)
        }
        guard let endRange = content.range(of: "</think>") else {
            let thinking = String(content[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (thinking.isEmpty ? nil : thinking, nil, true)
        }

        let thinking = String(content[startRange.upperBound ..< endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = String(content[endRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            thinking.isEmpty ? nil : thinking,
            answer.isEmpty ? nil : answer,
            false
        )
    }

    private static func cardFingerprint(from payload: AssistantCardPayload?) -> String? {
        guard let payload else { return nil }
        return AssistantCardCodec.encode(payload)
    }
}

struct ChatTranscriptSnapshot: Equatable {
    let threadID: UUID?
    let title: String
    let recentUserMessageFragments: [String]
    let messages: [ChatMessageRenderModel]
    let containsUndoCard: Bool
    let identityHash: Int

    static let empty = ChatTranscriptSnapshot(
        threadID: nil,
        title: "chat",
        recentUserMessageFragments: [],
        messages: [],
        containsUndoCard: false,
        identityHash: 0
    )

    init(thread: Thread?) {
        guard let thread else {
            self = .empty
            return
        }

        let sortedMessages = thread.sortedMessagesSnapshot()
        let renderMessages = sortedMessages.map(ChatMessageRenderModel.init(message:))
        let firstTitle = sortedMessages.first?.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let recentUserMessageFragments = sortedMessages
            .filter { $0.role == .user }
            .suffix(2)
            .map { $0.content.lowercased() }

        var hasher = Hasher()
        hasher.combine(thread.id)
        for renderMessage in renderMessages {
            hasher.combine(renderMessage.id)
            hasher.combine(renderMessage.markdownSourceHash)
            hasher.combine(renderMessage.generatingTime?.bitPattern ?? 0)
        }

        self.threadID = thread.id
        self.title = firstTitle?.isEmpty == false ? firstTitle! : "chat"
        self.recentUserMessageFragments = recentUserMessageFragments
        self.messages = renderMessages
        self.containsUndoCard = renderMessages.contains { $0.cardPayload?.cardType == .undo }
        self.identityHash = hasher.finalize()
    }

    private init(
        threadID: UUID?,
        title: String,
        recentUserMessageFragments: [String],
        messages: [ChatMessageRenderModel],
        containsUndoCard: Bool,
        identityHash: Int
    ) {
        self.threadID = threadID
        self.title = title
        self.recentUserMessageFragments = recentUserMessageFragments
        self.messages = messages
        self.containsUndoCard = containsUndoCard
        self.identityHash = identityHash
    }
}

struct ChatLiveOutputState: Equatable {
    let threadID: UUID?
    let text: String
    let runtimePhase: LLMChatRuntimePhase
    let isRunning: Bool
    let isPreparingResponse: Bool

    static let empty = ChatLiveOutputState(
        threadID: nil,
        text: "",
        runtimePhase: .idle,
        isRunning: false,
        isPreparingResponse: false
    )

    var shouldRender: Bool {
        threadID != nil && (isRunning || isPreparingResponse) && text.isEmpty == false
    }

    var renderModel: ChatMessageRenderModel {
        ChatMessageRenderModel(
            role: .assistant,
            originalContent: text,
            displayContent: text
        )
    }
}
