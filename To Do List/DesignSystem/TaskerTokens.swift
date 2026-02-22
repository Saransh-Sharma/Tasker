import UIKit

public protocol TaskerTokenGroup {}

public protocol TaskerTokenContainer {
    var color: TaskerColorTokens { get }
    var typography: TaskerTypographyTokens { get }
    var spacing: TaskerSpacingTokens { get }
    var elevation: TaskerElevationTokens { get }
    var corner: TaskerCornerTokens { get }
    var interaction: TaskerInteractionTokens { get }
    var iconSize: TaskerIconSizeTokens { get }
    var motion: TaskerMotionTokens { get }
    var transition: TaskerTransitionTokens { get }
    var priorityIndicator: TaskerPriorityIndicatorTokens { get }
}

public enum TaskerTextStyle: String, CaseIterable {
    case display
    case title1
    case title2
    case title3
    case headline
    case body
    case bodyEmphasis
    case callout
    case caption1
    case caption2
    case button
    case buttonSmall
}

public enum TaskerColorRole: String, CaseIterable {
    case bgCanvas
    case bgElevated
    case surfacePrimary
    case surfaceSecondary
    case surfaceTertiary
    case divider
    case strokeHairline
    case strokeStrong
    case textPrimary
    case textSecondary
    case textTertiary
    case textQuaternary
    case textInverse
    case accentPrimary
    case accentPrimaryPressed
    case accentMuted
    case accentWash
    case accentOnPrimary
    case accentRing
    case accentSecondary
    case accentSecondaryPressed
    case accentSecondaryMuted
    case accentSecondaryWash
    case statusSuccess
    case statusWarning
    case statusDanger
    case overlayScrim
    case overlayGlassTint
    case taskCheckboxBorder
    case taskCheckboxFill
    case taskOverdue
    case chartPrimary
    case chartSecondary
    case chipSelectedBackground
    case chipUnselectedBackground
    case priorityMax
    case priorityHigh
    case priorityLow
    case priorityNone
}

public enum TaskerSpacingToken: CGFloat, CaseIterable {
    case s2 = 2
    case s4 = 4
    case s8 = 8
    case s12 = 12
    case s16 = 16
    case s20 = 20
    case s24 = 24
    case s32 = 32
    case s40 = 40
}

public enum TaskerElevationLevel: String, CaseIterable {
    case e0
    case e1
    case e2
    case e3
}

public enum TaskerCornerToken: String, CaseIterable {
    case r0
    case r1
    case r2
    case r3
    case r4
    case pill
    case circle

    public var value: CGFloat {
        switch self {
        case .r0: return 0
        case .r1: return 8
        case .r2: return 12
        case .r3: return 16
        case .r4: return 24
        case .pill: return 999
        case .circle: return 999
        }
    }

    /// Executes value.
    public func value(forHeight height: CGFloat) -> CGFloat {
        if self == .circle {
            return max(0, height / 2)
        }
        return value
    }
}

public enum TaskerNavButtonContext: String, CaseIterable {
    case onGradient
    case onSurface
}

public enum TaskerNavButtonEmphasis: String, CaseIterable {
    case normal
    case done
    case filled
}

public enum TaskerChipSelectionStyle: String, CaseIterable {
    case tinted
    case filled
}

public struct TaskerInteractionTokens: TaskerTokenGroup {
    public let minInteractiveSize: CGFloat
    public let focusRingWidth: CGFloat
    public let focusRingOffset: CGFloat
    public let pressScale: CGFloat
    public let pressOpacity: CGFloat
    public let reducedMotionPressScale: CGFloat

    public static let `default` = TaskerInteractionTokens(
        minInteractiveSize: 44,
        focusRingWidth: 2,
        focusRingOffset: 2,
        pressScale: 0.97,
        pressOpacity: 0.92,
        reducedMotionPressScale: 1.0
    )
}

public struct TaskerIconSizeTokens: TaskerTokenGroup {
    public let small: CGFloat
    public let medium: CGFloat
    public let large: CGFloat
    public let hero: CGFloat

    public static let `default` = TaskerIconSizeTokens(
        small: 16,
        medium: 20,
        large: 24,
        hero: 32
    )
}

public enum TaskerMotionCurve: String {
    case easeInOut
}

public struct TaskerMotionTokens: TaskerTokenGroup {
    public let gradientCycleDuration: TimeInterval
    public let gradientCycleRandomness: TimeInterval
    public let gradientHueShiftDegrees: CGFloat
    public let gradientSaturationShiftPercent: CGFloat
    public let gradientOpacityDeltaMax: CGFloat
    public let gradientCurve: TaskerMotionCurve
    public let maxAnimatedGradientLayers: Int
    public let maxAnimatedElementsPerView: Int
    public let reduceMotionUsesStaticGradient: Bool
    public let reduceMotionUsesOpacityPressFeedback: Bool

    public static let `default` = TaskerMotionTokens(
        gradientCycleDuration: 15,
        gradientCycleRandomness: 2,
        gradientHueShiftDegrees: 8,
        gradientSaturationShiftPercent: 5,
        gradientOpacityDeltaMax: 0.08,
        gradientCurve: .easeInOut,
        maxAnimatedGradientLayers: 2,
        maxAnimatedElementsPerView: 2,
        reduceMotionUsesStaticGradient: true,
        reduceMotionUsesOpacityPressFeedback: true
    )
}

public struct TaskerTransitionTokens: TaskerTokenGroup {
    public let pushPopDuration: TimeInterval
    public let modalDuration: TimeInterval
    public let sheetSpringDamping: CGFloat
    public let reduceMotionCrossfadeDuration: TimeInterval

    public static let `default` = TaskerTransitionTokens(
        pushPopDuration: 0.30,
        modalDuration: 0.35,
        sheetSpringDamping: 0.85,
        reduceMotionCrossfadeDuration: 0.20
    )
}

public struct TaskerPriorityIndicatorDescriptor: Equatable {
    public let symbolName: String
    public let shortLabel: String
    public let accessibilityLabel: String
}

public struct TaskerPriorityIndicatorTokens: TaskerTokenGroup {
    public let max: TaskerPriorityIndicatorDescriptor
    public let high: TaskerPriorityIndicatorDescriptor
    public let low: TaskerPriorityIndicatorDescriptor
    public let none: TaskerPriorityIndicatorDescriptor

    public static let `default` = TaskerPriorityIndicatorTokens(
        max: TaskerPriorityIndicatorDescriptor(
            symbolName: "exclamationmark.triangle.fill",
            shortLabel: "Max",
            accessibilityLabel: "Maximum priority"
        ),
        high: TaskerPriorityIndicatorDescriptor(
            symbolName: "arrow.up.circle.fill",
            shortLabel: "High",
            accessibilityLabel: "High priority"
        ),
        low: TaskerPriorityIndicatorDescriptor(
            symbolName: "arrow.down.circle.fill",
            shortLabel: "Low",
            accessibilityLabel: "Low priority"
        ),
        none: TaskerPriorityIndicatorDescriptor(
            symbolName: "minus.circle",
            shortLabel: "None",
            accessibilityLabel: "No priority"
        )
    )

    public func descriptor(for priority: TaskPriorityConfig.Priority) -> TaskerPriorityIndicatorDescriptor {
        switch priority {
        case .max: return max
        case .high: return high
        case .low: return low
        case .none: return none
        }
    }
}

public struct TaskerTokens: TaskerTokenContainer {
    public let color: TaskerColorTokens
    public let typography: TaskerTypographyTokens
    public let spacing: TaskerSpacingTokens
    public let elevation: TaskerElevationTokens
    public let corner: TaskerCornerTokens
    public let interaction: TaskerInteractionTokens
    public let iconSize: TaskerIconSizeTokens
    public let motion: TaskerMotionTokens
    public let transition: TaskerTransitionTokens
    public let priorityIndicator: TaskerPriorityIndicatorTokens

    /// Initializes a new instance.
    public init(
        color: TaskerColorTokens,
        typography: TaskerTypographyTokens,
        spacing: TaskerSpacingTokens,
        elevation: TaskerElevationTokens,
        corner: TaskerCornerTokens,
        interaction: TaskerInteractionTokens,
        iconSize: TaskerIconSizeTokens,
        motion: TaskerMotionTokens,
        transition: TaskerTransitionTokens,
        priorityIndicator: TaskerPriorityIndicatorTokens
    ) {
        self.color = color
        self.typography = typography
        self.spacing = spacing
        self.elevation = elevation
        self.corner = corner
        self.interaction = interaction
        self.iconSize = iconSize
        self.motion = motion
        self.transition = transition
        self.priorityIndicator = priorityIndicator
    }
}

public enum TaskerCopy {
    public enum EmptyStates {
        public static let allClearTitle = "All clear"
        public static let noTasksYet = "No tasks yet. Add one when you're ready."
        public static let today = "No tasks for today. Add one when you're ready."
        public static let morning = "No morning tasks yet. Add one when you're ready."
        public static let evening = "No evening tasks yet. Add one when you're ready."
        public static let upcoming = "No upcoming tasks in the next 14 days."
        public static let done = "No completed tasks in the last 30 days."
        public static let searchStartTitle = "Start searching"
        public static let searchStartBody = "Type to search your tasks or choose filters."
        public static let searchNoResultsTitle = "No matching tasks"
        public static let searchNoResultsBody = "Try a different word or adjust your filters."
        public static let legacyInboxTitle = "Inbox is empty"
        public static let legacyInboxBody = "New tasks you capture quickly will show up here."
        public static let legacyWeekTitle = "No tasks this week"
        public static let legacyWeekBody = "Add tasks to plan your week when you're ready."
        public static let legacyUpcomingTitle = "No upcoming tasks"
        public static let legacyUpcomingBody = "Add a due date to surface tasks here."
    }

    public enum Actions {
        public static let addTask = "Add task"
        public static let done = "Done"
        public static let undo = "Undo"
        public static let close = "Close"
        public static let cancel = "Cancel"
        public static let addAnother = "Add another"
        public static let acceptAll = "Apply suggestion"
    }

    public enum Confirmations {
        public static let taskCompleted = "Task completed"
        public static let movedToTomorrow = "Moved to tomorrow"
        public static let projectCreated = "Project created"
    }

    public enum Errors {
        public static let genericSave = "Couldn't save. Please try again."
        public static let taskCreateFailed = "Task couldn't be created. Please try again."
        public static let projectCreateFailed = "Project couldn't be created. Please try again."
    }

    public enum Onboarding {
        public static let welcomeTitle = "Meet Eva"
        public static let welcomeSubtitle = "Your task assistant, built for focus."
        public static let getStarted = "Get started"
    }

    public enum Assistant {
        public static let suggestions = "Eva suggestions"
        public static let helpChoose = "Help me choose"
        public static let instantSuggestion = "Instant suggestion"
        public static let refinedSuggestion = "AI refined suggestion"
        public static let trustHint = "Review before applying changes."
    }
}
