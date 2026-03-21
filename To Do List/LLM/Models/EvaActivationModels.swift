import Foundation

enum ChatPresentationMode: Equatable {
    case normal
    case activation(config: EvaActivationChatConfiguration)
}

struct EvaActivationChatConfiguration: Equatable {
    let starterPrompts: [EvaStarterPrompt]
    let showsCompletionObserver: Bool
    let progressTitle: String
    let progressStep: Int
    let totalSteps: Int
    let hideUtilityActions: Bool
    let recommendedStarterID: String?
    let visibleStarterLimit: Int
    let helperCopy: String
    let collapsesCoachingAfterFirstAssistantReply: Bool
}

struct EvaActivationInstallSample: Equatable {
    let timestamp: TimeInterval
    let progress: Double
}

enum EvaActivationInstallETAState: Equatable {
    case calculating
    case ready(secondsRemaining: Int)

    var text: String {
        switch self {
        case .calculating:
            return "Calculating time remaining..."
        case .ready(let secondsRemaining):
            if secondsRemaining < 60 {
                return "About \(max(1, secondsRemaining)) sec remaining"
            }

            let minutes = Int(ceil(Double(secondsRemaining) / 60.0))
            return "About \(minutes) min remaining"
        }
    }
}

struct EvaActivationInstallPresentation: Equatable {
    let modeTitle: String
    let statusText: String
    let progress: Double
    let percentComplete: Int
    let etaState: EvaActivationInstallETAState
    let transferText: String?

    var progressText: String {
        "\(percentComplete)% complete"
    }

    var etaText: String {
        etaState.text
    }
}

enum EvaActivationInstallEstimator {
    static func etaState(
        for samples: [EvaActivationInstallSample],
        latestProgress: Double
    ) -> EvaActivationInstallETAState {
        let clampedProgress = max(0, min(latestProgress, 1))
        guard clampedProgress >= 0.08 else { return .calculating }
        guard let first = samples.first, let last = samples.last else { return .calculating }

        let deltaProgress = last.progress - first.progress
        let deltaTime = last.timestamp - first.timestamp
        guard deltaProgress > 0.015, deltaTime >= 1.2 else { return .calculating }

        let progressPerSecond = deltaProgress / deltaTime
        guard progressPerSecond.isFinite, progressPerSecond > 0 else { return .calculating }

        let secondsRemaining = Int(((1 - clampedProgress) / progressPerSecond).rounded())
        guard secondsRemaining > 0 else { return .ready(secondsRemaining: 1) }
        return .ready(secondsRemaining: min(secondsRemaining, 60 * 30))
    }

    static func transferText(
        for approximateSizeGB: Decimal?,
        progress: Double
    ) -> String? {
        guard let approximateSizeGB else { return nil }

        let totalMB = NSDecimalNumber(decimal: approximateSizeGB).doubleValue * 1024
        guard totalMB.isFinite, totalMB > 0 else { return nil }

        let clampedProgress = max(0, min(progress, 1))
        let downloadedMB = totalMB * clampedProgress
        return "\(Int(downloadedMB.rounded())) MB of \(Int(totalMB.rounded())) MB"
    }
}

struct EvaStarterPrompt: Identifiable, Equatable {
    enum Style: Equatable {
        case naturalLanguage
        case slashCommand
    }

    let id: String
    let title: String
    let submissionText: String
    let style: Style
    let isRecommended: Bool

    static let activationDefaults: [EvaStarterPrompt] = [
        EvaStarterPrompt(
            id: "plan_today",
            title: "Help me plan today",
            submissionText: "Help me plan today.",
            style: .naturalLanguage,
            isRecommended: true
        ),
        EvaStarterPrompt(
            id: "focus_first",
            title: "What should I focus on first?",
            submissionText: "What should I focus on first today?",
            style: .naturalLanguage,
            isRecommended: false
        ),
        EvaStarterPrompt(
            id: "break_top_priority",
            title: "Break down my top priority",
            submissionText: "Help me break down my top priority into next steps.",
            style: .naturalLanguage,
            isRecommended: false
        ),
        EvaStarterPrompt(
            id: "slash_today",
            title: "/today",
            submissionText: "/today",
            style: .slashCommand,
            isRecommended: false
        ),
        EvaStarterPrompt(
            id: "slash_project_inbox",
            title: "/project Inbox",
            submissionText: "/project Inbox",
            style: .slashCommand,
            isRecommended: false
        )
    ]
}

enum EvaActivationInstallResult: Equatable {
    case success(
        preparedModelName: String,
        selectedModelRetryCount: Int,
        attemptedFastFallback: Bool
    )
    case failed(
        failedModelName: String,
        selectedModelRetryCount: Int,
        attemptedFastFallback: Bool
    )
}

enum EvaActivationChatEvent: Equatable {
    case threadAttached(UUID)
    case userMessagePersisted(threadID: UUID)
    case assistantReplyPersisted(threadID: UUID, countsForCompletion: Bool)
}
