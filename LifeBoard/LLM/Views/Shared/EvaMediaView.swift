import Combine
import SwiftUI

#if os(iOS) || os(visionOS)
import Lottie
#elseif os(macOS)
import AppKit
#endif

public enum AssistantMascotID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case eva
    case cloudlet
    case dude
    case elon
    case friday
    case johnny
    case maddie
    case paperclip
    case punch
    case retriever
    case sato
    case steve
    case theo
    case yesman

    public var id: String { rawValue }
}

struct AssistantMascotPersona: Identifiable, Equatable, Sendable {
    let id: AssistantMascotID
    let displayName: String
    let shortDescription: String
    let resourceFolderName: String?
    let usesSprites: Bool

    static let all: [AssistantMascotPersona] = [
        AssistantMascotPersona(id: .eva, displayName: "Eva", shortDescription: "Calm planning support with the original LifeBoard look.", resourceFolderName: nil, usesSprites: false),
        AssistantMascotPersona(id: .cloudlet, displayName: "Cloudlet", shortDescription: "Soft, calm prompts for keeping the day light and clear.", resourceFolderName: "Cloudlet", usesSprites: true),
        AssistantMascotPersona(id: .dude, displayName: "Dude", shortDescription: "Relaxed, low-pressure guidance for steady follow-through.", resourceFolderName: "Dude", usesSprites: true),
        AssistantMascotPersona(id: .elon, displayName: "Elon", shortDescription: "Bold, direct energy for ambitious planning and fast decisions.", resourceFolderName: "Elon", usesSprites: true),
        AssistantMascotPersona(id: .friday, displayName: "Friday", shortDescription: "Bright, direct nudges for keeping the week moving.", resourceFolderName: "Friday", usesSprites: true),
        AssistantMascotPersona(id: .johnny, displayName: "Johnny", shortDescription: "High-energy focus for decisive work sessions.", resourceFolderName: "Johnny", usesSprites: true),
        AssistantMascotPersona(id: .maddie, displayName: "Maddie", shortDescription: "Grounded reflection for deliberate planning.", resourceFolderName: "Maddie", usesSprites: true),
        AssistantMascotPersona(id: .paperclip, displayName: "Paperclip", shortDescription: "Tidy office-minded support for lists, notes, and loose ends.", resourceFolderName: "Paperclip", usesSprites: true),
        AssistantMascotPersona(id: .punch, displayName: "Punch", shortDescription: "Playful momentum for getting unstuck and moving again.", resourceFolderName: "Punch", usesSprites: true),
        AssistantMascotPersona(id: .retriever, displayName: "Retriever", shortDescription: "Loyal follow-up support for fetching the next right task.", resourceFolderName: "Retriever", usesSprites: true),
        AssistantMascotPersona(id: .sato, displayName: "Sato", shortDescription: "Compact signal for turning complexity into next steps.", resourceFolderName: "Sato", usesSprites: true),
        AssistantMascotPersona(id: .steve, displayName: "Steve", shortDescription: "Crisp product-minded coaching for prioritization.", resourceFolderName: "Steve", usesSprites: true),
        AssistantMascotPersona(id: .theo, displayName: "Theo", shortDescription: "Curious builder energy for shaping ideas into action.", resourceFolderName: "Theo", usesSprites: true),
        AssistantMascotPersona(id: .yesman, displayName: "YesMan", shortDescription: "Cheerful momentum when tasks need a helpful push.", resourceFolderName: "YesMan", usesSprites: true)
    ]

    static func persona(for id: AssistantMascotID) -> AssistantMascotPersona {
        all.first { $0.id == id } ?? all[0]
    }
}

struct AssistantIdentitySnapshot: Equatable {
    let mascotID: AssistantMascotID
    let persona: AssistantMascotPersona

    init(mascotID: AssistantMascotID) {
        self.mascotID = mascotID
        self.persona = AssistantMascotPersona.persona(for: mascotID)
    }

    var displayName: String { persona.displayName }
    var uppercaseName: String { displayName.uppercased() }
    var askAction: String { "Ask \(displayName)" }
    var openAction: String { "Open \(displayName)" }
    var readyStatus: String { "\(displayName) is ready" }
}

final class AssistantIdentityModel: ObservableObject {
    @Published var snapshot: AssistantIdentitySnapshot

    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore
    private var cancellable: AnyCancellable?

    init(workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared) {
        self.workspacePreferencesStore = workspacePreferencesStore
        self.snapshot = AssistantIdentitySnapshot(
            mascotID: workspacePreferencesStore.load().chiefOfStaffMascotID
        )
        self.cancellable = NotificationCenter.default.publisher(for: LifeBoardWorkspacePreferencesStore.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                if let preferences = notification.object as? LifeBoardWorkspacePreferences {
                    self.snapshot = AssistantIdentitySnapshot(mascotID: preferences.chiefOfStaffMascotID)
                } else {
                    self.snapshot = AssistantIdentitySnapshot(
                        mascotID: self.workspacePreferencesStore.load().chiefOfStaffMascotID
                    )
                }
            }
    }
}

enum AssistantIdentityText {
    static func snapshot(for id: AssistantMascotID) -> AssistantIdentitySnapshot {
        AssistantIdentitySnapshot(mascotID: id)
    }

    static func currentSnapshot() -> AssistantIdentitySnapshot {
        AssistantIdentitySnapshot(mascotID: LifeBoardWorkspacePreferencesStore.shared.load().chiefOfStaffMascotID)
    }

    static func displayName(for id: AssistantMascotID) -> String {
        AssistantMascotPersona.persona(for: id).displayName
    }

    static func displayName(for snapshot: AssistantIdentitySnapshot) -> String {
        snapshot.displayName
    }

    static func uppercaseName(for id: AssistantMascotID) -> String {
        displayName(for: id).uppercased()
    }

    static func uppercaseName(for snapshot: AssistantIdentitySnapshot) -> String {
        snapshot.uppercaseName
    }

    static func askAction(for id: AssistantMascotID) -> String {
        "Ask \(displayName(for: id))"
    }

    static func askAction(for snapshot: AssistantIdentitySnapshot) -> String {
        snapshot.askAction
    }

    static func openAction(for id: AssistantMascotID) -> String {
        "Open \(displayName(for: id))"
    }

    static func openAction(for snapshot: AssistantIdentitySnapshot) -> String {
        snapshot.openAction
    }

    static func readyStatus(for id: AssistantMascotID) -> String {
        "\(displayName(for: id)) is ready"
    }

    static func readyStatus(for snapshot: AssistantIdentitySnapshot) -> String {
        snapshot.readyStatus
    }

}

enum MascotAnimation: String, CaseIterable, Equatable, Sendable {
    case idle
    case runRight
    case runLeft
    case waving
    case jumping
    case failed
    case waiting
    case running
    case review

    var rowIndex: Int {
        switch self {
        case .idle: return 0
        case .runRight: return 1
        case .runLeft: return 2
        case .waving: return 3
        case .jumping: return 4
        case .failed: return 5
        case .waiting: return 6
        case .running: return 7
        case .review: return 8
        }
    }

    var frameCount: Int {
        switch self {
        case .idle: return 6
        case .runRight, .runLeft: return 8
        case .waving: return 4
        case .jumping: return 5
        case .failed: return 8
        case .waiting, .running, .review: return 6
        }
    }
}

enum EvaMediaAsset {
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

    static func animation(for placement: EvaMascotPlacement) -> MascotAnimation {
        switch placement {
        case .chatEmptyHeader, .homeEntry, .settingsIdentity, .onboardingWelcome, .habitEmpty, .restReminder:
            return .idle
        case .onboardingNextStep:
            return .runRight
        case .featureDiscovery:
            return .runLeft
        case .chatHelp, .onboardingNotificationPermission:
            return .waving
        case .proposalApplied, .habitWin, .weeklyComplete, .focusComplete, .habitStreakWin, .onboardingSuccess, .habitMilestone:
            return .jumping
        case .homeOverload, .habitRecovery, .taskDeadlineRisk:
            return .failed
        case .chatThinking, .onboardingProcessing, .calendarRescheduleThinking:
            return .waiting
        case .focusStart, .timelineStartPlan:
            return .running
        case .chiefOfStaffGuide, .proposalReview, .taskTriage, .weeklyChecklist, .onboardingEvaValue,
             .dayOverview, .homeInsight, .weeklySuggestion, .calendarPlanning, .onboardingCalendarPermission,
             .timelineEmptySchedule, .calendarConflict, .timelineConflict, .timelineFreeSlot, .taskCapture,
             .onboardingCaptureSetup, .weeklyReflection, .focusRationale, .focusNextAction:
            return .review
        }
    }
}

struct EvaMascotView: View {
    let asset: EvaMascotAsset
    let placement: EvaMascotPlacement?
    let mascotID: AssistantMascotID?
    let size: EvaMascotSize
    let decorative: Bool
    let accessibilityLabel: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedMascotID = LifeBoardWorkspacePreferencesStore.shared.load().chiefOfStaffMascotID

    init(
        _ asset: EvaMascotAsset,
        size: EvaMascotSize = .inline,
        decorative: Bool = true,
        accessibilityLabel: String = AssistantIdentityText.currentSnapshot().displayName,
        mascotID: AssistantMascotID? = nil
    ) {
        self.asset = asset
        self.placement = nil
        self.mascotID = mascotID
        self.size = size
        self.decorative = decorative
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        placement: EvaMascotPlacement,
        size: EvaMascotSize = .inline,
        decorative: Bool = true,
        accessibilityLabel: String = AssistantIdentityText.currentSnapshot().displayName,
        mascotID: AssistantMascotID? = nil
    ) {
        self.asset = EvaMascotPlacementResolver.asset(for: placement)
        self.placement = placement
        self.mascotID = mascotID
        self.size = size
        self.decorative = decorative
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        mascotBody
            .frame(width: size.points, height: size.points)
            .accessibilityHidden(decorative)
            .accessibilityLabel(accessibilityLabel)
            .onReceive(NotificationCenter.default.publisher(for: LifeBoardWorkspacePreferencesStore.didChangeNotification)) { notification in
                guard mascotID == nil else { return }
                if let preferences = notification.object as? LifeBoardWorkspacePreferences {
                    selectedMascotID = preferences.chiefOfStaffMascotID
                } else {
                    selectedMascotID = LifeBoardWorkspacePreferencesStore.shared.load().chiefOfStaffMascotID
                }
            }
    }

    @ViewBuilder
    private var mascotBody: some View {
        let resolvedID = mascotID ?? selectedMascotID
        let persona = AssistantMascotPersona.persona(for: resolvedID)
        if persona.usesSprites, let placement {
            MascotSpriteAnimationView(
                persona: persona,
                animation: EvaMascotPlacementResolver.animation(for: placement),
                animate: shouldAnimate(placement: placement)
            )
        } else if persona.usesSprites {
            MascotSpriteAnimationView(persona: persona, animation: .idle, animate: shouldAnimate(animation: .idle))
        } else {
            Image(asset.rawValue)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
        }
    }

    private func shouldAnimate(placement: EvaMascotPlacement) -> Bool {
        guard reduceMotion == false else { return false }
        let animation = EvaMascotPlacementResolver.animation(for: placement)
        if size.points >= EvaMascotSize.inline.points { return true }
        switch animation {
        case .waiting, .running, .review, .jumping, .failed:
            return true
        case .idle, .runRight, .runLeft, .waving:
            return false
        }
    }

    private func shouldAnimate(animation: MascotAnimation) -> Bool {
        guard reduceMotion == false else { return false }
        if size.points >= EvaMascotSize.inline.points { return true }
        return animation == .waiting || animation == .running
    }
}

struct MascotPersonaSelector: View {
    let selectedID: AssistantMascotID
    var title: String = "Choose your chief of staff"
    var subtitle: String = "Pick the companion style LifeBoard should use across assistant surfaces."
    var cardAccessibilityPrefix: String
    let onSelect: (AssistantMascotID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 138), spacing: 10, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(subtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AssistantMascotPersona.all) { persona in
                    Button {
                        onSelect(persona.id)
                    } label: {
                        MascotPersonaChoiceContent(
                            persona: persona,
                            isSelected: persona.id == selectedID
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(cardAccessibilityPrefix).\(persona.id.rawValue)")
                    .accessibilityLabel(persona.displayName)
                    .accessibilityValue(persona.id == selectedID ? "selected" : "not selected")
                }
            }
        }
    }
}

private struct MascotPersonaChoiceContent: View {
    let persona: AssistantMascotPersona
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.lifeboard(.accentWash))
                    EvaMascotView(
                        placement: .settingsIdentity,
                        size: .custom(42),
                        accessibilityLabel: persona.displayName,
                        mascotID: persona.id
                    )
                }
                .frame(width: 52, height: 52)

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textTertiary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(persona.displayName)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .lineLimit(1)
                Text(persona.shortDescription)
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

#if canImport(UIKit)
struct MascotSpriteAnimationView: View {
    let persona: AssistantMascotPersona
    let animation: MascotAnimation
    let animate: Bool

    @ViewBuilder
    var body: some View {
        if animate {
            TimelineView(.periodic(from: .now, by: 0.13)) { timeline in
                frameView(index: frameIndex(for: timeline.date))
            }
        } else {
            frameView(index: 0)
        }
    }

    private func frameIndex(for date: Date) -> Int {
        let tick = Int(date.timeIntervalSinceReferenceDate / 0.13)
        return tick % animation.frameCount
    }

    @ViewBuilder
    private func frameView(index: Int) -> some View {
        if let image = MascotSpriteFrameProvider.shared.frame(persona: persona, animation: animation, index: index) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .scaledToFit()
        } else {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.lifeboard(.accentPrimary))
        }
    }
}

@MainActor
final class MascotSpriteFrameProvider {
    static let shared = MascotSpriteFrameProvider()

    static let sheetPixelWidth = 1536
    static let sheetPixelHeight = 1872
    static let columns = 8
    static let rows = 9
    static let cellWidth = 192
    static let cellHeight = 208

    private var sheetCache: [AssistantMascotID: CGImage] = [:]
    private var frameCache: [String: UIImage] = [:]
    private let lock = NSLock()

    func frame(persona: AssistantMascotPersona, animation: MascotAnimation, index: Int) -> UIImage? {
        guard let sheet = sheet(for: persona) else { return nil }
        let clampedIndex = max(0, min(index, animation.frameCount - 1))
        let cacheKey = "\(persona.id.rawValue)-\(animation.rawValue)-\(clampedIndex)"

        lock.lock()
        if let cached = frameCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let rect = CGRect(
            x: clampedIndex * Self.cellWidth,
            y: animation.rowIndex * Self.cellHeight,
            width: Self.cellWidth,
            height: Self.cellHeight
        )
        guard let cropped = sheet.cropping(to: rect) else { return nil }
        let image = UIImage(cgImage: cropped, scale: UIScreen.main.scale, orientation: .up)

        lock.lock()
        frameCache[cacheKey] = image
        lock.unlock()
        return image
    }

    func metadataURL(for persona: AssistantMascotPersona) -> URL? {
        guard let folder = persona.resourceFolderName else { return nil }
        return Bundle.main.url(forResource: "pet", withExtension: "json", subdirectory: "MascotSprites/\(folder)")
            ?? Bundle.main.url(forResource: "pet", withExtension: "json", subdirectory: "LLM/MascotSprites/\(folder)")
    }

    func spritesheetURL(for persona: AssistantMascotPersona) -> URL? {
        guard let folder = persona.resourceFolderName else { return nil }
        return Bundle.main.url(forResource: "spritesheet", withExtension: "webp", subdirectory: "MascotSprites/\(folder)")
            ?? Bundle.main.url(forResource: "spritesheet", withExtension: "webp", subdirectory: "LLM/MascotSprites/\(folder)")
    }

    private func sheet(for persona: AssistantMascotPersona) -> CGImage? {
        lock.lock()
        if let cached = sheetCache[persona.id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let url = spritesheetURL(for: persona),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)?.cgImage else {
            return nil
        }

        lock.lock()
        sheetCache[persona.id] = image
        lock.unlock()
        return image
    }
}
#else
struct MascotSpriteAnimationView: View {
    let persona: AssistantMascotPersona
    let animation: MascotAnimation
    let animate: Bool

    var body: some View {
        Image(systemName: "sparkles")
            .resizable()
            .scaledToFit()
    }
}
#endif

#if os(iOS) || os(visionOS)
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
#endif

struct EvaLoopingLottieContainer: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.lifeboard(.bgCanvas).opacity(0.78))
                .overlay(Circle().stroke(Color.lifeboard(.strokeHairline), lineWidth: 1))
            if reduceMotion {
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
            } else {
                #if os(iOS) || os(visionOS)
                EvaLoopingLottieView(animationName: EvaMediaAsset.introLottieName)
                    .padding(size * 0.14)
                #else
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
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
                .stroke(Color.lifeboard(.surfaceTertiary), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    LinearGradient(
                        colors: [Color.lifeboard(.accentPrimary), Color.lifeboard(.accentSecondary)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(LifeBoardAnimation.heroReveal, value: progress)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(Color.lifeboard(.statusSuccess))
            } else {
                ZStack {
                    EvaLoopingLottieContainer(size: 92)
                    Circle()
                        .fill(Color.clear)
                        .overlay(
                            Circle()
                                .stroke(Color.lifeboard(.accentMuted).opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .frame(width: 140, height: 140)
    }
}
