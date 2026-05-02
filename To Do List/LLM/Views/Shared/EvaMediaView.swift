import AVKit
import SwiftUI

#if os(iOS) || os(visionOS)
import Lottie
#elseif os(macOS)
import AppKit
#endif

enum EvaMediaAsset {
    static let introVideoName = "EvaIntroVideo"
    static let introLottieName = "EvaLottie00-lite"
}

enum EvaMascotAsset: String, CaseIterable, Equatable {
    case neutral = "eva_neutral"
    case pointRight = "eva_point_right"
    case pointLeft = "eva_point_left"
    case celebration = "eva_celebration"
    case clipboard = "eva_clipboard"
    case calendar = "eva_calendar"
    case pencil = "eva_pencil"
    case thinking = "eva_thinking"
    case excited = "eva_excited"
    case focused = "eva_focused"
    case surprised = "eva_surprised"
    case sleepy = "eva_sleepy"
    case worried = "eva_worried"
    case meditate = "eva_meditate"
    case running = "eva_running"
    case sitting = "eva_sitting"
    case idea = "eva_idea"
    case peek = "eva_peek"
}

enum EvaMascotSize: Equatable {
    case avatar
    case chip
    case inline
    case card
    case hero
    case custom(CGFloat)

    var points: CGFloat {
        switch self {
        case .avatar:
            return 40
        case .chip:
            return 32
        case .inline:
            return 56
        case .card:
            return 104
        case .hero:
            return 184
        case .custom(let points):
            return points
        }
    }
}

enum EvaMascotPlacement: Equatable {
    case onboardingWelcome
    case onboardingNextStep
    case onboardingEvaValue
    case onboardingCaptureSetup
    case onboardingProcessing
    case onboardingCalendarPermission
    case onboardingNotificationPermission
    case onboardingSuccess
    case chatEmptyHeader
    case chatHelp
    case chatThinking
    case chiefOfStaffGuide
    case dayOverview
    case proposalReview
    case proposalApplied
    case homeEntry
    case focusRationale
    case homeInsight
    case homeOverload
    case calendarPlanning
    case calendarConflict
    case calendarRescheduleThinking
    case taskCapture
    case taskTriage
    case taskDeadlineRisk
    case habitEmpty
    case habitWin
    case habitRecovery
    case habitStreakWin
    case habitMilestone
    case weeklyReflection
    case weeklyChecklist
    case weeklySuggestion
    case weeklyComplete
    case restReminder
    case focusStart
    case focusNextAction
    case focusComplete
    case settingsIdentity
    case timelineEmptySchedule
    case timelineConflict
    case timelineFreeSlot
    case timelineStartPlan
    case featureDiscovery
}

enum EvaMascotPlacementResolver {
    static func asset(for placement: EvaMascotPlacement) -> EvaMascotAsset {
        switch placement {
        case .chatEmptyHeader, .homeEntry, .settingsIdentity:
            return .neutral
        case .onboardingWelcome, .habitEmpty:
            return .sitting
        case .onboardingNextStep:
            return .pointRight
        case .featureDiscovery:
            return .pointLeft
        case .chatHelp, .onboardingNotificationPermission:
            return .peek
        case .chatThinking, .onboardingProcessing, .calendarRescheduleThinking:
            return .thinking
        case .chiefOfStaffGuide, .proposalReview, .taskTriage, .weeklyChecklist, .onboardingEvaValue:
            return .clipboard
        case .dayOverview, .homeInsight, .weeklySuggestion:
            return .idea
        case .proposalApplied, .habitWin, .weeklyComplete, .focusComplete, .habitStreakWin:
            return .celebration
        case .onboardingSuccess, .habitMilestone:
            return .excited
        case .focusRationale, .focusNextAction:
            return .focused
        case .homeOverload, .habitRecovery, .taskDeadlineRisk:
            return .worried
        case .calendarPlanning, .onboardingCalendarPermission, .timelineEmptySchedule:
            return .calendar
        case .calendarConflict, .timelineConflict, .timelineFreeSlot:
            return .surprised
        case .taskCapture, .onboardingCaptureSetup:
            return .pencil
        case .weeklyReflection:
            return .meditate
        case .restReminder:
            return .sleepy
        case .focusStart, .timelineStartPlan:
            return .running
        }
    }
}

struct EvaMascotView: View {
    let asset: EvaMascotAsset
    let size: EvaMascotSize
    let decorative: Bool
    let accessibilityLabel: String

    init(
        _ asset: EvaMascotAsset,
        size: EvaMascotSize = .inline,
        decorative: Bool = true,
        accessibilityLabel: String = "Eva"
    ) {
        self.asset = asset
        self.size = size
        self.decorative = decorative
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        placement: EvaMascotPlacement,
        size: EvaMascotSize = .inline,
        decorative: Bool = true,
        accessibilityLabel: String = "Eva"
    ) {
        self.init(
            EvaMascotPlacementResolver.asset(for: placement),
            size: size,
            decorative: decorative,
            accessibilityLabel: accessibilityLabel
        )
    }

    var body: some View {
        Image(asset.rawValue)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size.points, height: size.points)
            .accessibilityHidden(decorative)
            .accessibilityLabel(accessibilityLabel)
    }
}

#if os(iOS) || os(visionOS)
struct EvaLoopingVideoView: UIViewRepresentable {
    let videoName: String

    func makeUIView(context: Context) -> EvaLoopingPlayerUIView {
        EvaLoopingPlayerUIView(videoName: videoName)
    }

    func updateUIView(_ uiView: EvaLoopingPlayerUIView, context: Context) {
        uiView.update(videoName: videoName)
    }

    static func dismantleUIView(_ uiView: EvaLoopingPlayerUIView, coordinator: ()) {
        uiView.tearDownPlayback()
    }
}

final class EvaLoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private let player = AVQueuePlayer()
    private var currentVideoName: String?

    init(videoName: String) {
        super.init(frame: .zero)
        layer.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        update(videoName: videoName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    deinit {
        tearDownPlayback()
    }

    func update(videoName: String) {
        guard currentVideoName != videoName else { return }
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            player.pause()
            player.removeAllItems()
            playerLooper = nil
            currentVideoName = nil
            assertionFailure("Missing Eva media asset: \(videoName).mp4")
            logWarning(
                event: "eva_media_missing_video_asset",
                message: "Missing bundled Eva media asset",
                fields: ["video_name": videoName]
            )
            return
        }
        currentVideoName = videoName
        let url = URL(fileURLWithPath: path)
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        player.removeAllItems()
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    func tearDownPlayback() {
        player.pause()
        player.removeAllItems()
        playerLooper = nil
        playerLayer.player = nil
        currentVideoName = nil
    }
}

struct EvaLoopingLottieView: UIViewRepresentable {
    let animationName: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let configuration = LottieConfiguration(renderingEngine: .coreAnimation)
        let animationView = LottieAnimationView(name: animationName, configuration: configuration)
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.isAnimationPlaying == false {
            uiView.play()
        }
    }

    static func dismantleUIView(_ uiView: LottieAnimationView, coordinator: ()) {
        uiView.stop()
    }
}
#elseif os(macOS)
struct EvaLoopingVideoView: NSViewRepresentable {
    let videoName: String

    func makeNSView(context: Context) -> EvaLoopingPlayerNSView {
        EvaLoopingPlayerNSView(videoName: videoName)
    }

    func updateNSView(_ nsView: EvaLoopingPlayerNSView, context: Context) {
        nsView.update(videoName: videoName)
    }

    static func dismantleNSView(_ nsView: EvaLoopingPlayerNSView, coordinator: ()) {
        nsView.tearDownPlayback()
    }
}

final class EvaLoopingPlayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private let player = AVQueuePlayer()
    private var currentVideoName: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }

    convenience init(videoName: String) {
        self.init(frame: .zero)
        update(videoName: videoName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    deinit {
        tearDownPlayback()
    }

    func update(videoName: String) {
        guard currentVideoName != videoName else { return }
        guard let path = Bundle.main.path(forResource: videoName, ofType: "mp4") else {
            player.pause()
            player.removeAllItems()
            playerLooper = nil
            currentVideoName = nil
            assertionFailure("Missing Eva media asset: \(videoName).mp4")
            logWarning(
                event: "eva_media_missing_video_asset",
                message: "Missing bundled Eva media asset",
                fields: ["video_name": videoName]
            )
            return
        }
        currentVideoName = videoName
        let url = URL(fileURLWithPath: path)
        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        player.removeAllItems()
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    func tearDownPlayback() {
        player.pause()
        player.removeAllItems()
        playerLooper = nil
        playerLayer.player = nil
        currentVideoName = nil
    }
}
#endif

enum EvaHeroMediaPresentationStyle {
    case card
    case fullBleed
}

struct EvaHeroMediaView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: EvaHeroMediaPresentationStyle

    init(style: EvaHeroMediaPresentationStyle = .card) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .card:
            cardBody
        case .fullBleed:
            fullBleedBody
        }
    }

    private var cardBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker(.surfacePrimary),
                            Color.tasker(.accentWash).opacity(0.62),
                            Color.tasker(.surfacePrimary)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if reduceMotion {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            } else {
                EvaLoopingVideoView(videoName: EvaMediaAsset.introVideoName)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.tasker(.bgCanvas).opacity(0.02),
                                Color.tasker(.bgCanvas).opacity(0.08),
                                Color.tasker(.bgCanvas).opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous))
                    )
                    .overlay(alignment: .bottomTrailing) {
                        EvaLoopingLottieContainer(size: 76)
                            .padding(TaskerTheme.Spacing.md)
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.modal, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
        )
        .shadow(color: Color.tasker(.accentPrimary).opacity(0.12), radius: 18, y: 10)
    }

    private var fullBleedBody: some View {
        ZStack {
            if reduceMotion {
                LinearGradient(
                    colors: [
                        Color.tasker(.surfacePrimary),
                        Color.tasker(.accentWash).opacity(0.62),
                        Color.tasker(.surfacePrimary)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            } else {
                EvaLoopingVideoView(videoName: EvaMediaAsset.introVideoName)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.tasker(.bgCanvas).opacity(0.02),
                                Color.tasker(.bgCanvas).opacity(0.08),
                                Color.tasker(.bgCanvas).opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        EvaLoopingLottieContainer(size: 76)
                            .padding(TaskerTheme.Spacing.md)
                    }
            }
        }
    }
}

struct EvaLoopingLottieContainer: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.tasker(.bgCanvas).opacity(0.78))
                .overlay(Circle().stroke(Color.tasker(.strokeHairline), lineWidth: 1))
            if reduceMotion {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            } else {
                #if os(iOS) || os(visionOS)
                EvaLoopingLottieView(animationName: EvaMediaAsset.introLottieName)
                    .padding(size * 0.14)
                #else
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                #endif
            }
        }
        .frame(width: size, height: size)
    }
}

struct EvaInstallStatusView: View {
    let isComplete: Bool
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.tasker(.surfaceTertiary), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    LinearGradient(
                        colors: [Color.tasker(.accentPrimary), Color.tasker(.accentSecondary)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(TaskerAnimation.heroReveal, value: progress)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(Color.tasker(.statusSuccess))
            } else {
                ZStack {
                    EvaLoopingLottieContainer(size: 92)
                    Circle()
                        .fill(Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.tasker(.accentMuted).opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .frame(width: 140, height: 140)
    }
}
