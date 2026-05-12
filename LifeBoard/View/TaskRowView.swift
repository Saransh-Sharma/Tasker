//
//  TaskRowView.swift
//  LifeBoard
//
//  Compact Home row optimized for scan speed and low-friction completion.
//

import SwiftUI

struct TaskRowMetadataPolicy: Equatable {
    let showDueTodayTime: Bool
    let showInboxProject: Bool

    static let `default` = TaskRowMetadataPolicy(
        showDueTodayTime: true,
        showInboxProject: true
    )

    static let homeUnifiedList = TaskRowMetadataPolicy(
        showDueTodayTime: false,
        showInboxProject: false
    )
}

enum TaskRowChromeStyle: Equatable {
    case card
    case flatHomeList
}

struct TaskRowDisplayModel: Equatable {
    let xpValue: Int
    let descriptionText: String?
    let metadataText: String?
    let statusChip: TaskRowStatusChip?

    var hasDescription: Bool {
        descriptionText != nil
    }

    var hasSecondaryContent: Bool {
        descriptionText != nil || metadataText != nil
    }

    /// Executes from.
    static func from(
        task: TaskDefinition,
        showTypeBadge: Bool,
        now: Date = Date(),
        isInOverdueSection: Bool = false,
        tagNameByID: [UUID: String] = [:],
        metadataPolicy: TaskRowMetadataPolicy = .default
    ) -> TaskRowDisplayModel {
        let _ = showTypeBadge
        let descriptionText = smartDescription(for: task, now: now)
        let metadataText = metadataText(
            for: task,
            now: now,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID,
            metadataPolicy: metadataPolicy
        )
        let statusChip: TaskRowStatusChip? = dueSoonStatus(for: task, now: now)

        return TaskRowDisplayModel(
            xpValue: task.priority.scorePoints,
            descriptionText: descriptionText,
            metadataText: metadataText,
            statusChip: statusChip
        )
    }

    /// Executes dueSoonStatus.
    private static func dueSoonStatus(for task: TaskDefinition, now: Date) -> TaskRowStatusChip? {
        guard !task.isComplete, let dueDate = task.dueDate else { return nil }
        guard OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) == nil else { return nil }
        let remaining = dueDate.timeIntervalSince(now)
        guard remaining > 0, remaining <= (2 * 60 * 60) else { return nil }
        return .dueSoon
    }

    /// Executes metadataText.
    private static func metadataText(
        for task: TaskDefinition,
        now: Date,
        isInOverdueSection: Bool,
        tagNameByID: [UUID: String],
        metadataPolicy: TaskRowMetadataPolicy
    ) -> String? {
        var tokens: [String] = []
        let calendar = Calendar.current

        if !task.isComplete, let dueDate = task.dueDate {
            if let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
                tokens.append(lateLabel)
            } else if metadataPolicy.showDueTodayTime && calendar.isDate(dueDate, inSameDayAs: now) {
                tokens.append(dueDate.formatted(date: .omitted, time: .shortened))
            }
        }

        if let projectToken = projectToken(for: task, metadataPolicy: metadataPolicy) {
            tokens.append(projectToken)
        }

        if let recurrence = compactRecurrenceToken(for: task.repeatPattern) {
            tokens.append(recurrence)
        }

        if isInOverdueSection, let tagName = firstTagName(for: task, tagNameByID: tagNameByID) {
            tokens.append(tagName)
        }

        return tokens.joined(separator: " • ").nilIfEmpty
    }

    /// Executes projectToken.
    private static func projectToken(for task: TaskDefinition, metadataPolicy: TaskRowMetadataPolicy) -> String? {
        let trimmedProjectName = task.projectName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        if let trimmedProjectName {
            if !metadataPolicy.showInboxProject,
               trimmedProjectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame {
                return nil
            }
            return trimmedProjectName
        }

        if metadataPolicy.showInboxProject, task.projectID == ProjectConstants.inboxProjectID {
            return ProjectConstants.inboxProjectName
        }

        return nil
    }

    /// Executes firstTagName.
    private static func firstTagName(for task: TaskDefinition, tagNameByID: [UUID: String]) -> String? {
        guard let firstTagID = task.tagIDs.first else { return nil }
        let tagName = tagNameByID[firstTagID]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return tagName?.nilIfEmpty
    }

    /// Executes compactRecurrenceToken.
    private static func compactRecurrenceToken(for pattern: TaskRepeatPattern?) -> String? {
        guard let pattern else { return nil }
        switch pattern {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Biweekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .custom(let custom):
            return "Every \(custom.intervalDays)d"
        }
    }

    /// Executes smartDescription.
    private static func smartDescription(for task: TaskDefinition, now: Date) -> String? {
        guard !task.isComplete else { return nil }
        guard let description = task.details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        if normalizedForDedup(description) == normalizedForDedup(task.title) {
            return nil
        }

        let isOverdueRelativeToNow = task.dueDate.map {
            OverdueAgeFormatter.lateLabel(dueDate: $0, now: now) != nil
        } ?? false
        let hasStrongSignal = isOverdueRelativeToNow
            || task.priority.isHighPriority
            || !task.dependencies.isEmpty
            || !task.subtasks.isEmpty
        if hasStrongSignal {
            return description
        }

        return isContextRich(description) ? description : nil
    }

    /// Executes isContextRich.
    private static func isContextRich(_ text: String) -> Bool {
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        let hasLongStructuredText = wordCount >= 6 && text.count >= 24
        let hasStructure = text.rangeOfCharacter(from: CharacterSet(charactersIn: ":;,-/()")) != nil
        return hasLongStructuredText || hasStructure
    }

    /// Executes normalizedForDedup.
    private static func normalizedForDedup(_ text: String) -> String {
        let lowered = text.lowercased()
        let stripped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return " "
        }
        return String(stripped)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

enum TaskRowStatusChip: Equatable {
    case dueSoon

    var text: String {
        switch self {
        case .dueSoon: return "Due soon"
        }
    }
}

struct TaskRowDerivedState: Equatable {
    let displayModel: TaskRowDisplayModel
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityStateValue: String
    let xpPreview: XPCompletionPreview?
    let tagDisplaySignature: [String]
}

private struct TaskRowDerivedStateCacheKey: Hashable {
    let taskID: UUID
    let updatedAt: Date
    let isComplete: Bool
    let dateCompleted: Date?
    let title: String
    let details: String?
    let displayedIconSymbolName: String?
    let dueDate: Date?
    let priorityRaw: Int32
    let estimatedDuration: TimeInterval?
    let showTypeBadge: Bool
    let isInOverdueSection: Bool
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    let hasTapAction: Bool
    let hasToggleAction: Bool
    let hasDeleteAction: Bool
    let hasRescheduleAction: Bool
    let hasPromoteAction: Bool
    let showDueTodayTime: Bool
    let showInboxProject: Bool
    let tagDisplaySignature: [String]
}

private final class TaskRowDerivedStateCacheStorage: @unchecked Sendable {
    let lock = NSLock()
    var cache: [TaskRowDerivedStateCacheKey: TaskRowDerivedState] = [:]
    var insertionOrder: [TaskRowDerivedStateCacheKey] = []
}

private enum TaskRowDerivedStateCache {
    private static let storage = TaskRowDerivedStateCacheStorage()
    private static let cacheLimit = 512

    static func resolve(
        task: TaskDefinition,
        showTypeBadge: Bool,
        isInOverdueSection: Bool,
        tagNameByID: [UUID: String],
        todayXPSoFar: Int?,
        isGamificationV2Enabled: Bool,
        isTaskDragEnabled: Bool,
        hasTapAction: Bool,
        hasToggleAction: Bool,
        hasDeleteAction: Bool,
        hasRescheduleAction: Bool,
        hasPromoteAction: Bool,
        fallbackIconSymbolName: String?,
        metadataPolicy: TaskRowMetadataPolicy
    ) -> TaskRowDerivedState {
        let tagDisplaySignature = task.tagIDs.compactMap { tagNameByID[$0] }.sorted()
        let displayedIconSymbolName = task.iconSymbolName ?? fallbackIconSymbolName
        let key = TaskRowDerivedStateCacheKey(
            taskID: task.id,
            updatedAt: task.updatedAt,
            isComplete: task.isComplete,
            dateCompleted: task.dateCompleted,
            title: task.title,
            details: task.details,
            displayedIconSymbolName: displayedIconSymbolName,
            dueDate: task.dueDate,
            priorityRaw: task.priority.rawValue,
            estimatedDuration: task.estimatedDuration,
            showTypeBadge: showTypeBadge,
            isInOverdueSection: isInOverdueSection,
            todayXPSoFar: todayXPSoFar,
            isGamificationV2Enabled: isGamificationV2Enabled,
            isTaskDragEnabled: isTaskDragEnabled,
            hasTapAction: hasTapAction,
            hasToggleAction: hasToggleAction,
            hasDeleteAction: hasDeleteAction,
            hasRescheduleAction: hasRescheduleAction,
            hasPromoteAction: hasPromoteAction,
            showDueTodayTime: metadataPolicy.showDueTodayTime,
            showInboxProject: metadataPolicy.showInboxProject,
            tagDisplaySignature: tagDisplaySignature
        )

        storage.lock.lock()
        if let cached = storage.cache[key] {
            storage.lock.unlock()
            return cached
        }
        storage.lock.unlock()

        let displayModel = TaskRowDisplayModel.from(
            task: task,
            showTypeBadge: showTypeBadge,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID,
            metadataPolicy: metadataPolicy
        )
        let xpPreview: XPCompletionPreview?
        if isGamificationV2Enabled {
            if let todayXPSoFar {
                xpPreview = XPCalculationEngine.completionXPIfCompletedNow(
                    priorityRaw: task.priority.rawValue,
                    estimatedDuration: task.estimatedDuration,
                    dueDate: task.dueDate,
                    dailyEarnedSoFar: todayXPSoFar,
                    isGamificationV2Enabled: true
                )
            } else {
                xpPreview = nil
            }
        } else {
            xpPreview = XPCalculationEngine.completionXPIfCompletedNow(
                priorityRaw: task.priority.rawValue,
                estimatedDuration: task.estimatedDuration,
                dueDate: task.dueDate,
                dailyEarnedSoFar: 0,
                isGamificationV2Enabled: false
            )
        }

        let accessibilityStateValue = task.isComplete ? "done" : "open"
        var labelParts: [String] = ["Task: \(task.title)"]
        if let displayedIconSymbolName {
            labelParts.append("Icon: \(DefaultTaskIconResolver.humanizedDisplayName(for: displayedIconSymbolName))")
        }
        if task.isComplete {
            labelParts.append("completed")
        }
        if let descriptionText = displayModel.descriptionText {
            labelParts.append(descriptionText)
        }
        if let metadataText = displayModel.metadataText {
            labelParts.append(metadataText)
        }
        if let statusChip = displayModel.statusChip {
            labelParts.append(statusChip.text.lowercased())
        }

        var hintParts: [String] = []
        if hasToggleAction {
            hintParts.append("Double tap to toggle completion")
        }
        if hasTapAction {
            hintParts.append("Tap to view details")
        }
        if hasDeleteAction || hasRescheduleAction {
            hintParts.append("Swipe for actions")
        }
        if hasPromoteAction {
            hintParts.append("Move to Focus Now available")
        }
        if isTaskDragEnabled {
            hintParts.append("Long press and drag to move task to Focus")
        }

        let resolved = TaskRowDerivedState(
            displayModel: displayModel,
            accessibilityLabel: labelParts.joined(separator: ", "),
            accessibilityHint: hintParts.joined(separator: ", "),
            accessibilityStateValue: accessibilityStateValue,
            xpPreview: xpPreview,
            tagDisplaySignature: tagDisplaySignature
        )

        storage.lock.lock()
        storage.cache[key] = resolved
        storage.insertionOrder.append(key)
        if storage.insertionOrder.count > cacheLimit, let oldest = storage.insertionOrder.first {
            storage.insertionOrder.removeFirst()
            storage.cache.removeValue(forKey: oldest)
        }
        storage.lock.unlock()
        return resolved
    }
}

struct TaskRowView: View, Equatable {
    let task: TaskDefinition
    let fallbackIconSymbolName: String?
    let accentHex: String?
    let showTypeBadge: Bool
    let isInOverdueSection: Bool
    let tagNameByID: [UUID: String]
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    let highlightedTaskID: UUID?
    let metadataPolicy: TaskRowMetadataPolicy
    let chromeStyle: TaskRowChromeStyle
    private let derivedState: TaskRowDerivedState
    private let hasTapAction: Bool
    private let hasToggleAction: Bool
    private let hasDeleteAction: Bool
    private let hasRescheduleAction: Bool
    private let hasPromoteAction: Bool
    var onTap: (() -> Void)? = nil
    var onToggleComplete: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onReschedule: (() -> Void)? = nil
    var onPromoteToFocus: (() -> Void)? = nil
    var onTaskDragStarted: ((TaskDefinition) -> Void)? = nil

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightPulse = false

    /// Initializes a new instance.
    init(
        task: TaskDefinition,
        fallbackIconSymbolName: String? = nil,
        accentHex: String? = nil,
        showTypeBadge: Bool,
        isInOverdueSection: Bool = false,
        tagNameByID: [UUID: String] = [:],
        todayXPSoFar: Int? = nil,
        isGamificationV2Enabled: Bool = V2FeatureFlags.gamificationV2Enabled,
        isTaskDragEnabled: Bool,
        highlightedTaskID: UUID? = nil,
        metadataPolicy: TaskRowMetadataPolicy = .default,
        chromeStyle: TaskRowChromeStyle = .card,
        onTap: (() -> Void)? = nil,
        onToggleComplete: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onReschedule: (() -> Void)? = nil,
        onPromoteToFocus: (() -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil
    ) {
        self.task = task
        self.fallbackIconSymbolName = fallbackIconSymbolName
        self.accentHex = accentHex
        self.showTypeBadge = showTypeBadge
        self.isInOverdueSection = isInOverdueSection
        self.tagNameByID = tagNameByID
        self.todayXPSoFar = todayXPSoFar
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.isTaskDragEnabled = isTaskDragEnabled
        self.highlightedTaskID = highlightedTaskID
        self.metadataPolicy = metadataPolicy
        self.chromeStyle = chromeStyle
        self.hasTapAction = onTap != nil
        self.hasToggleAction = onToggleComplete != nil
        self.hasDeleteAction = onDelete != nil
        self.hasRescheduleAction = onReschedule != nil
        self.hasPromoteAction = onPromoteToFocus != nil
        self.derivedState = TaskRowDerivedStateCache.resolve(
            task: task,
            showTypeBadge: showTypeBadge,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID,
            todayXPSoFar: todayXPSoFar,
            isGamificationV2Enabled: isGamificationV2Enabled,
            isTaskDragEnabled: isTaskDragEnabled,
            hasTapAction: hasTapAction,
            hasToggleAction: hasToggleAction,
            hasDeleteAction: hasDeleteAction,
            hasRescheduleAction: hasRescheduleAction,
            hasPromoteAction: hasPromoteAction,
            fallbackIconSymbolName: fallbackIconSymbolName,
            metadataPolicy: metadataPolicy
        )
        self.onTap = onTap
        self.onToggleComplete = onToggleComplete
        self.onDelete = onDelete
        self.onReschedule = onReschedule
        self.onPromoteToFocus = onPromoteToFocus
        self.onTaskDragStarted = onTaskDragStarted
    }

    private var displayModel: TaskRowDisplayModel {
        derivedState.displayModel
    }

    private var themeColors: LifeBoardColorTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).color
    }

    nonisolated static func == (lhs: TaskRowView, rhs: TaskRowView) -> Bool {
        return lhs.task.id == rhs.task.id &&
        lhs.task.updatedAt == rhs.task.updatedAt &&
        lhs.task.isComplete == rhs.task.isComplete &&
        lhs.task.dateCompleted == rhs.task.dateCompleted &&
        lhs.fallbackIconSymbolName == rhs.fallbackIconSymbolName &&
        lhs.accentHex == rhs.accentHex &&
        lhs.showTypeBadge == rhs.showTypeBadge &&
        lhs.isInOverdueSection == rhs.isInOverdueSection &&
        lhs.tagNameByID == rhs.tagNameByID &&
        lhs.todayXPSoFar == rhs.todayXPSoFar &&
        lhs.isGamificationV2Enabled == rhs.isGamificationV2Enabled &&
        lhs.isTaskDragEnabled == rhs.isTaskDragEnabled &&
        lhs.highlightedTaskID == rhs.highlightedTaskID &&
        lhs.metadataPolicy == rhs.metadataPolicy &&
        lhs.chromeStyle == rhs.chromeStyle &&
        lhs.hasTapAction == rhs.hasTapAction &&
        lhs.hasToggleAction == rhs.hasToggleAction &&
        lhs.hasDeleteAction == rhs.hasDeleteAction &&
        lhs.hasRescheduleAction == rhs.hasRescheduleAction &&
        lhs.hasPromoteAction == rhs.hasPromoteAction
    }

    private var rowBase: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture {
                logDebug("HOME_TAP_UI row_tap id=\(task.id.uuidString)")
                onTap?()
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    onToggleComplete?()
                } label: {
                    Label(task.isComplete ? "Reopen" : "Complete", systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(task.isComplete ? Color.lifeboard.accentSecondary : Color.lifeboard.statusSuccess)

                if !task.isComplete, let onPromoteToFocus {
                    Button {
                        onPromoteToFocus()
                    } label: {
                        Label("Focus", systemImage: "scope")
                    }
                    .tint(Color.lifeboard.accentPrimary)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !task.isComplete {
                    if let onPromoteToFocus {
                        Button {
                            onPromoteToFocus()
                        } label: {
                            Label("Move to Focus Now", systemImage: "scope")
                        }
                        .tint(Color.lifeboard.accentPrimary)
                    }

                    Button {
                        onReschedule?()
                    } label: {
                        Label("Reschedule", systemImage: "calendar")
                    }
                    .tint(Color.lifeboard.accentPrimary)
                }

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .modifier(TaskRowChromeModifier(
                chromeStyle: chromeStyle,
                rowBackground: rowBackground,
                highlightStrokeColor: highlightStrokeColor,
                isOnboardingHighlighted: isOnboardingHighlighted
            ))
            .taskCompletionTransition(isComplete: task.isComplete)
            .scaleEffect(isOnboardingHighlighted && !reduceMotion ? (highlightPulse ? 1.01 : 0.992) : 1)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.taskRow.\(task.id.uuidString)")
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityStateValue)
            .accessibilityHint(accessibilityHint)
            .hoverEffect(.highlight)
            .onAppear {
                updateHighlightAnimation()
            }
            .onChange(of: isOnboardingHighlighted) { _, _ in
                updateHighlightAnimation()
            }
            .contextMenu {
                Button {
                    onToggleComplete?()
                } label: {
                    Label(
                        task.isComplete ? "Mark Incomplete" : "Mark Complete",
                        systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark.circle"
                    )
                }

                if !task.isComplete {
                    if let onPromoteToFocus {
                        Button {
                            onPromoteToFocus()
                        } label: {
                            Label("Move to Focus Now", systemImage: "scope")
                        }
                    }

                    Button {
                        onReschedule?()
                    } label: {
                        Label("Reschedule", systemImage: "calendar")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    @ViewBuilder
    var body: some View {
        if isTaskDragEnabled {
            rowBase.onDrag {
                onTaskDragStarted?(task)
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
        } else {
            rowBase
        }
    }

    private var isPad: Bool { layoutClass.isPad }
    private var isOnboardingHighlighted: Bool { highlightedTaskID == task.id && task.isComplete == false }
    private var highlightStrokeColor: Color {
        isOnboardingHighlighted ? Color.lifeboard.accentPrimary : Color.lifeboard.strokeHairline
    }

    private var resolvedIconTint: Color {
        LifeBoardHexColor.color(accentHex, fallback: Color.lifeboard.accentPrimary)
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            priorityStripe

            HStack(alignment: .center, spacing: isPad ? LifeBoardTheme.Spacing.sm : LifeBoardTheme.Spacing.xs) {
                CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                    onToggleComplete?()
                }
                .accessibilityIdentifier("home.taskCheckbox.\(task.id.uuidString)")
                .accessibilityLabel("Toggle completion for \(task.title)")
                .accessibilityHint(task.isComplete ? "Double tap to mark as open" : "Double tap to mark as completed")
                .accessibilityValue(accessibilityStateValue)

                if let iconSymbolName = task.iconSymbolName ?? fallbackIconSymbolName {
                    Image(systemName: iconSymbolName)
                        .font(.system(size: isPad ? 16 : 15, weight: .semibold))
                        .foregroundStyle(task.isComplete ? Color.lifeboard.textQuaternary : resolvedIconTint)
                        .frame(width: 20, alignment: .center)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: isPad ? 3 : 1) {
                    Text(task.title)
                        .font(.lifeboard(.body))
                        .foregroundColor(task.isComplete ? Color.lifeboard.textTertiary : Color.lifeboard.textPrimary)
                        .lineLimit(displayModel.hasDescription ? 1 : 2)
                        .multilineTextAlignment(.leading)

                    if isPad, let description = task.details?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty, !task.isComplete {
                        // iPad: always show description if available
                        Text(description)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(Color.lifeboard.textTertiary)
                            .lineLimit(1)
                    } else if let descriptionText = displayModel.descriptionText {
                        Text(descriptionText)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(task.isComplete ? Color.lifeboard.textQuaternary : Color.lifeboard.textTertiary)
                            .lineLimit(1)
                    }

                    if let metadataText = displayModel.metadataText {
                        Text(metadataText)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(task.isComplete ? Color.lifeboard.textQuaternary : Color.lifeboard.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if isPad {
                        iPadTrailingMetadata
                    }

                    if let statusChip = displayModel.statusChip {
                        statusChipView(statusChip)
                    }

                    compactXPBadge
                }
            }
            .padding(.vertical, isPad ? 8 : (displayModel.hasSecondaryContent ? 6 : 4))
            .padding(.trailing, LifeBoardTheme.Spacing.md)
            .padding(.leading, LifeBoardTheme.Spacing.xs)
            .frame(minHeight: isPad ? 60 : (displayModel.hasDescription ? 56 : 50))
        }
        .animation(LifeBoardAnimation.quick, value: task.isComplete)
        .overlay {
            if isOnboardingHighlighted {
                taskRowHighlightShape
                    .fill(Color.lifeboard.accentPrimary.opacity(reduceMotion ? 0.08 : (highlightPulse ? 0.12 : 0.04)))
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
    }

    private func updateHighlightAnimation() {
        guard isOnboardingHighlighted, !reduceMotion else {
            highlightPulse = false
            return
        }
        withAnimation(LifeBoardAnimation.gentle.repeatForever(autoreverses: true)) {
            highlightPulse = true
        }
    }

    @ViewBuilder
    private var iPadTrailingMetadata: some View {
        if let dueDate = task.dueDate, !task.isComplete {
            Text(dueDate, style: .date)
                .font(.lifeboard(.caption2))
                .foregroundColor(task.isOverdue ? Color.lifeboard.statusDanger : Color.lifeboard.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(task.isOverdue ? Color.lifeboard.statusDanger.opacity(0.1) : Color.lifeboard.surfaceSecondary)
                )
                .fixedSize()
        }
    }

    private var rowBackground: Color {
        if task.isComplete {
            return Color.lifeboard.surfacePrimary.opacity(0.7)
        }
        if task.isOverdue {
            return Color.lifeboard.statusDanger.opacity(0.03)
        }
        return Color.lifeboard.surfacePrimary
    }

    @ViewBuilder
    private var priorityStripe: some View {
        let stripe = priorityStripeShape
            .fill(stripeFill)
            .frame(width: 4)

        if !task.isComplete && !task.isOverdue && task.priority == .max {
            stripe.breathingPulse(min: 0.75, max: 1.0)
        } else {
            stripe
        }
    }

    private var stripeFill: some ShapeStyle {
        if task.isComplete {
            return AnyShapeStyle(Color.lifeboard.textQuaternary.opacity(0.3))
        }
        if task.isOverdue {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(uiColor: themeColors.taskOverdue), Color(uiColor: themeColors.taskOverdue).opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        switch task.priority {
        case .max:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.lifeboard.priorityMax, Color.lifeboard.priorityMax.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .high:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.lifeboard.priorityHigh, Color.lifeboard.priorityHigh.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .low:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.lifeboard.priorityLow, Color.lifeboard.priorityLow.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .none:
            return AnyShapeStyle(Color.lifeboard.priorityNone.opacity(0.5))
        }
    }

    private var accessibilityLabel: String {
        derivedState.accessibilityLabel
    }

    private var accessibilityHint: String {
        derivedState.accessibilityHint
    }

    private var accessibilityStateValue: String {
        derivedState.accessibilityStateValue
    }

    private var taskRowHighlightShape: AnyShape {
        switch chromeStyle {
        case .card:
            return AnyShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md))
        case .flatHomeList:
            return AnyShape(Rectangle())
        }
    }

    private var priorityStripeShape: AnyShape {
        switch chromeStyle {
        case .card:
            return AnyShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: LifeBoardTheme.CornerRadius.md,
                    bottomLeadingRadius: LifeBoardTheme.CornerRadius.md,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
        case .flatHomeList:
            return AnyShape(Rectangle())
        }
    }

    /// Executes statusChipView.
    @ViewBuilder
    private func statusChipView(_ statusChip: TaskRowStatusChip) -> some View {
        Text(statusChip.text)
            .font(.lifeboard(.caption2))
            .fontWeight(.medium)
            .foregroundColor(Color.lifeboard.statusWarning)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.lifeboard.statusWarning.opacity(0.15)))
            .fixedSize()
            .transition(.scale.combined(with: .opacity))
            .animation(LifeBoardAnimation.bouncy, value: displayModel.statusChip)
    }

    private var compactXPBadge: some View {
        let preview = derivedState.xpPreview

        return Text(preview?.compactLabel ?? "XP pending")
            .font(.lifeboard(.caption2))
            .fontWeight(task.priority == .max || task.priority == .high ? .bold : .medium)
            .foregroundColor(task.priority == .max || task.priority == .high ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(task.priority == .max || task.priority == .high ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(task.priority == .max || task.priority == .high ? Color.lifeboard.accentPrimary.opacity(0.3) : .clear, lineWidth: 1)
            )
            .fixedSize()
            .scaleEffect(task.isComplete ? 1.15 : 1.0)
            .animation(LifeBoardAnimation.bouncy, value: task.isComplete)
            .accessibilityLabel(preview.map { "Reward \($0.shortLabel)" } ?? "Reward pending")
            .accessibilityHint(
                "Reward factors: \(XPCalculationEngine.estimateReasonHints(estimatedDuration: task.estimatedDuration, isFocusSessionActive: false, isPinnedInFocusStrip: false))"
            )
    }
}

private struct TaskRowChromeModifier: ViewModifier {
    let chromeStyle: TaskRowChromeStyle
    let rowBackground: Color
    let highlightStrokeColor: Color
    let isOnboardingHighlighted: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch chromeStyle {
        case .card:
            content
                .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md))
                .lifeboardDenseSurface(
                    cornerRadius: LifeBoardTheme.CornerRadius.md,
                    fillColor: rowBackground,
                    strokeColor: highlightStrokeColor,
                    lineWidth: isOnboardingHighlighted ? 2 : 1
                )
        case .flatHomeList:
            content
                .background(rowBackground)
                .overlay {
                    if isOnboardingHighlighted {
                        Rectangle()
                            .stroke(highlightStrokeColor, lineWidth: 2)
                    }
                }
        }
    }
}

#if DEBUG
struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 6) {
            TaskRowView(
                task: TaskDefinition(
                    title: "Review pull requests",
                    details: "Prioritize API migration and checkout fixes",
                    priority: .high,
                    type: .morning,
                    dueDate: Date()
                ),
                showTypeBadge: true,
                isTaskDragEnabled: true
            )

            TaskRowView(
                task: TaskDefinition(
                    title: "Completed task example",
                    priority: .low,
                    type: .morning,
                    isComplete: true,
                    dateCompleted: Date()
                ),
                showTypeBadge: false,
                isTaskDragEnabled: false
            )
        }
        .padding(.horizontal, 20)
        .background(Color.lifeboard.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
