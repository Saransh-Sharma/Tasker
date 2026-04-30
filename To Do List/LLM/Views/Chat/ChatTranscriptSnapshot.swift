import Foundation

enum ChatPendingResponsePhase: String, Equatable {
    case idle
    case buildingContext
    case assemblingPrompt
    case preparingModel
    case generating

    var isActive: Bool {
        self != .idle
    }
}

enum ChatPendingResponseStatusText {
    static func status(
        for phase: ChatPendingResponsePhase,
        isActivationPresentation: Bool
    ) -> String? {
        guard phase.isActive else { return nil }

        if isActivationPresentation {
            switch phase {
            case .idle:
                return nil
            case .buildingContext:
                return "Looking at your tasks and goals..."
            case .assemblingPrompt:
                return "Building your first plan..."
            case .preparingModel:
                return "Getting Eva ready..."
            case .generating:
                return "Writing your recommendation..."
            }
        }

        switch phase {
        case .idle:
            return nil
        case .buildingContext:
            return "Checking the forecast..."
        case .assemblingPrompt:
            return "Sorting your timeline..."
        case .preparingModel:
            return "Getting the model ready..."
        case .generating:
            return "Protecting routines..."
        }
    }
}

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
    let sourceModelName: String?

    init(message: Message) {
        self.id = message.id
        self.role = message.role
        self.originalContent = message.content
        self.generatingTime = message.generatingTime
        self.cardPayload = AssistantCardCodec.decode(from: message.content)
        self.sourceModelName = message.sourceModelName

        let cardFingerprint = Self.cardFingerprint(from: self.cardPayload)

        let displayContent: String
        if message.role == .assistant {
            displayContent = LLMChatTextSanitizer.sanitizeForDisplay(
                message.content,
                modelName: message.sourceModelName
            )
        } else {
            displayContent = message.content
        }
        self.displayContent = displayContent

        let thinkingSplit = Self.processThinkingContent(displayContent, modelName: message.sourceModelName)
        self.thinkingText = thinkingSplit.thinking
        self.answerText = thinkingSplit.answer
        self.isThinkingOpenEnded = thinkingSplit.isOpenEnded

        var hasher = Hasher()
        hasher.combine(message.role.rawValue)
        hasher.combine(displayContent)
        hasher.combine(cardFingerprint)
        hasher.combine(self.sourceModelName ?? "")
        self.markdownSourceHash = hasher.finalize()
    }

    init(
        id: UUID = UUID(),
        role: Role,
        originalContent: String,
        displayContent: String,
        generatingTime: TimeInterval? = nil,
        sourceModelName: String? = nil
    ) {
        self.id = id
        self.role = role
        self.originalContent = originalContent
        self.displayContent = displayContent
        self.generatingTime = generatingTime
        self.sourceModelName = sourceModelName
        self.cardPayload = AssistantCardCodec.decode(from: originalContent)
        let cardFingerprint = Self.cardFingerprint(from: self.cardPayload)
        let thinkingSplit = Self.processThinkingContent(displayContent, modelName: sourceModelName)
        self.thinkingText = thinkingSplit.thinking
        self.answerText = thinkingSplit.answer
        self.isThinkingOpenEnded = thinkingSplit.isOpenEnded

        var hasher = Hasher()
        hasher.combine(role.rawValue)
        hasher.combine(displayContent)
        hasher.combine(cardFingerprint)
        hasher.combine(sourceModelName ?? "")
        self.markdownSourceHash = hasher.finalize()
    }

    private static func processThinkingContent(_ content: String) -> (
        thinking: String?,
        answer: String?,
        isOpenEnded: Bool
    ) {
        processThinkingContent(content, modelName: nil)
    }

    private static func processThinkingContent(
        _ content: String,
        modelName: String?
    ) -> (
        thinking: String?,
        answer: String?,
        isOpenEnded: Bool
    ) {
        let extraction = LLMVisibleThinkingExtractor.extract(
            from: content,
            modelName: modelName,
            closeOpenThinkingBlock: false
        )
        if extraction.hasVisibleThinking {
            if EvaThinkingVisibilityPolicy.showsVisibleThinking == false {
                let answer = extraction.answerText?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (
                    nil,
                    answer?.isEmpty == false ? answer : nil,
                    extraction.isOpenEnded
                )
            }
            return (
                extraction.thinkingText,
                extraction.answerText,
                extraction.isOpenEnded
            )
        }
        let answer = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return (nil, answer.isEmpty ? nil : answer, false)
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
    let responseID: UUID?
    let threadID: UUID?
    let text: String
    let sourceModelName: String?
    let runtimePhase: LLMChatRuntimePhase
    let isRunning: Bool
    let pendingPhase: ChatPendingResponsePhase
    let pendingStatusText: String?

    static let empty = ChatLiveOutputState(
        responseID: nil,
        threadID: nil,
        text: "",
        sourceModelName: nil,
        runtimePhase: .idle,
        isRunning: false,
        pendingPhase: .idle,
        pendingStatusText: nil
    )

    var isPreparingResponse: Bool {
        pendingPhase.isActive
    }

    var shouldRender: Bool {
        threadID != nil && (isRunning || isPreparingResponse)
    }

    var renderModel: ChatMessageRenderModel {
        ChatMessageRenderModel(
            id: responseID ?? threadID ?? UUID(),
            role: .assistant,
            originalContent: text,
            displayContent: text,
            sourceModelName: sourceModelName
        )
    }
}
