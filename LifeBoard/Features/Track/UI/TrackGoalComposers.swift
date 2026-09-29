import SwiftUI
import UIKit

struct GoalComposer: View {
    let existing: GoalDefinition?
    let save: (GoalDraft) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var type: GoalType
    @State private var target: Double
    @State private var hasBaseline: Bool
    @State private var baseline: Double
    @State private var unit: String
    @State private var targetDate: Date
    @State private var intent: GoalIntent
    @State private var confidence: GoalConfidence?
    @State private var whyItMatters: String
    @State private var checkInCadence: GoalCheckInCadence
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(
        existing: GoalDefinition? = nil,
        save: @escaping (GoalDraft) async -> Bool
    ) {
        self.existing = existing
        self.save = save
        _title = State(initialValue: existing?.title ?? "")
        _type = State(initialValue: existing?.type ?? .completion)
        let storedTarget = existing?.targetValue ?? 1
        _target = State(initialValue: existing?.type == .duration ? storedTarget / 60 : storedTarget)
        _hasBaseline = State(initialValue: existing?.baselineValue != nil)
        _baseline = State(initialValue: existing?.type == .duration
            ? (existing?.baselineValue ?? 0) / 60
            : existing?.baselineValue ?? 0)
        _unit = State(initialValue: existing?.unitLabel == "seconds" ? "" : existing?.unitLabel ?? "")
        _targetDate = State(initialValue: existing?.targetDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
        _intent = State(initialValue: existing?.effectiveIntent ?? .outcome)
        _confidence = State(initialValue: existing?.confidenceRaw.flatMap(GoalConfidence.init(rawValue:)))
        _whyItMatters = State(initialValue: existing?.whyItMatters ?? "")
        _checkInCadence = State(initialValue: existing?.checkInCadenceRaw.flatMap(GoalCheckInCadence.init(rawValue:)) ?? .weekly)
    }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? String(localized: "New goal") : String(localized: "Edit goal"),
            identifier: "track.goal.composer"
        ) {
            GoalIdentitySection(title: $title, type: $type, intent: $intent)
            GoalTargetSection(
                type: type,
                target: $target,
                hasBaseline: $hasBaseline,
                baseline: $baseline,
                unit: $unit,
                targetDate: $targetDate
            )
            GoalCadenceSection(confidence: $confidence, checkInCadence: $checkInCadence)
            GoalMeaningSection(whyItMatters: $whyItMatters)
        } commit: {
            ComposerCommitBar(
                title: existing == nil ? "Create goal" : "Save goal",
                phase: commitPhase,
                isEnabled: canCommit,
                identifier: "track.goal.commit",
                action: commit
            )
        }
        // No completion burst: this is a reversible log, and DESIGN.md keeps
        // the burst for completions. The commit bar's success is the feedback.
    }

    private var usesNumericTarget: Bool { type == .count || type == .quantity || type == .duration }
    private var canCommit: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (usesNumericTarget == false || target > 0)
    }

    private func commit() {
        if case .running = commitPhase { return }
        let draft = GoalDraft(
            areaID: existing?.areaID,
            title: title,
            type: type,
            intent: intent,
            targetValue: usesNumericTarget ? (type == .duration ? target * 60 : target) : nil,
            baselineValue: usesNumericTarget && hasBaseline
                ? (type == .duration ? baseline * 60 : baseline)
                : nil,
            unitLabel: type == .quantity ? unit : type == .duration ? "seconds" : nil,
            targetDate: type == .targetDate ? targetDate : nil,
            confidence: confidence,
            whyItMatters: whyItMatters,
            checkInCadence: checkInCadence
        )
        commitPhase = .running(progress: nil)
        Task {
            if await save(draft) {
                commitPhase = .success(receipt: .init())
                successTrigger &+= 1
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: String(localized: "Couldn’t save goal."),
                    recovery: .retry
                ))
            }
        }
    }
    // The type, intent and check-in names live in `GoalComposerCopy` below;
    // three unused private copies of them used to sit here and had drifted.
}

private struct GoalIdentitySection: View {
    @Binding var title: String
    @Binding var type: GoalType
    @Binding var intent: GoalIntent

    var body: some View {
        ComposerSection("Goal") {
            ComposerField(
                "Goal title",
                prompt: "Goal name",
                text: $title,
                showsLabel: false,
                identifier: "track.goal.title"
            )
            OptionRail(
                "Goal type",
                selection: $type,
                values: GoalType.allCases,
                identifierPrefix: "track.goal.type",
                title: GoalComposerCopy.typeTitle,
                pressBloomTint: Color(SemanticColorTokens.foundationSunAccent)
            )
            OptionRail(
                "Intent",
                selection: $intent,
                values: GoalIntent.allCases,
                identifierPrefix: "track.goal.intent",
                title: GoalComposerCopy.intentTitle
            )
        }
    }
}

private struct GoalTargetSection: View {
    let type: GoalType
    @Binding var target: Double
    @Binding var hasBaseline: Bool
    @Binding var baseline: Double
    @Binding var unit: String
    @Binding var targetDate: Date

    private var usesNumericTarget: Bool { type == .count || type == .quantity || type == .duration }

    var body: some View {
        if usesNumericTarget || type == .targetDate {
            ComposerSection("Target") {
                if usesNumericTarget {
                    ValueDrum(
                        "Target",
                        value: $target,
                        in: 0...1_000,
                        step: 1,
                        coarseStep: 10,
                        unit: type == .duration
                            ? String(localized: "min")
                            : (unit.isEmpty ? String(localized: "units") : unit),
                        fractionDigits: 0,
                        identifier: "track.goal.target"
                    )
                    Toggle("Use a baseline", isOn: $hasBaseline)
                        .toggleStyle(.lifeBoardClay)
                    if hasBaseline {
                        ComposerNumberField(
                            type == .duration ? String(localized: "Baseline (min)") : String(localized: "Baseline"),
                            value: $baseline
                        )
                    }
                    if type == .quantity {
                        ComposerField("Unit", prompt: "km, pages…", text: $unit)
                    }
                }
                if type == .targetDate {
                    DateCapsuleRow("Target date", selection: $targetDate, components: [.date])
                }
            }
        }
    }
}

private struct GoalCadenceSection: View {
    @Binding var confidence: GoalConfidence?
    @Binding var checkInCadence: GoalCheckInCadence

    var body: some View {
        ComposerSection("Check-ins") {
            OptionRail(
                "Confidence",
                selection: $confidence,
                values: [GoalConfidence?.none] + GoalConfidence.allCases.map(Optional.some),
                identifierPrefix: "track.goal.confidence",
                title: { $0.map(\.displayName) ?? String(localized: "Not set") }
            )
            MenuRow(
                "How often",
                selection: $checkInCadence,
                values: GoalCheckInCadence.allCases,
                title: GoalComposerCopy.checkInTitle,
                identifier: "track.goal.checkIn"
            )
        }
    }
}

private struct GoalMeaningSection: View {
    @Binding var whyItMatters: String

    var body: some View {
        ComposerSection(
            "Why it matters",
            footer: "Link progress after saving."
        ) {
            ComposerField(
                "Why it matters",
                prompt: "Add a reason",
                text: $whyItMatters,
                shape: .prose(lineLimit: 3...8),
                showsLabel: false
            )
        }
    }
}

/// Shared display copy so the sections and the parent agree on one spelling.
/// Type and intent defer to the model's `displayName`, which the goal rows
/// already show, so the composer and the list name a goal the same way.
private enum GoalComposerCopy {
    static func typeTitle(_ type: GoalType) -> String {
        type.displayName
    }

    static func intentTitle(_ intent: GoalIntent) -> String {
        intent.displayName
    }

    static func checkInTitle(_ cadence: GoalCheckInCadence) -> String {
        switch cadence {
        case .weekly: String(localized: "Weekly")
        case .biweekly: String(localized: "Every 2 weeks")
        case .monthly: String(localized: "Monthly")
        case .manual: String(localized: "No schedule")
        }
    }
}

struct GoalLinkComposer: View {
    let goal: GoalDefinition
    let sourcePickerRepository: any TypedSourcePickerRepository
    let save: (GoalLinkSource, UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: TypedSourcePickerItem?
    @State private var showsPicker = false

    var body: some View {
        ComposerScaffold(
            title: String(localized: "Link progress"),
            confirmTitle: String(localized: "Link"),
            isConfirmEnabled: selection != nil,
            identifier: "goal.link.composer",
            onConfirm: {
                guard let selection else { return }
                save(Self.goalSource(for: selection.kind), selection.id)
                dismiss()
            }
        ) {
            GoalLinkSourceSection(selection: selection) { showsPicker = true }
        }
        .sheet(isPresented: $showsPicker) {
            TypedSourcePickerView(
                title: String(localized: "Choose a source"),
                kinds: TypedSourceKind.allCases,
                repository: sourcePickerRepository
            ) { item in selection = item }
        }
    }

    private static func goalSource(for kind: TypedSourceKind) -> GoalLinkSource {
        switch kind {
        case .task: .task
        case .project: .project
        case .habit: .habit
        case .routine: .routine
        case .trackerMeasure: .trackerMeasure
        }
    }
}

private struct GoalLinkSourceSection: View {
    let selection: TypedSourcePickerItem?
    let choose: () -> Void

    var body: some View {
        ComposerSection(
            "Progress source",
            footer: "Only linked items count toward this goal."
        ) {
            Button(action: choose) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection?.kind.title ?? String(localized: "Choose a source"))
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        if let selection {
                            Text(selection.title)
                                .font(.lifeboard(.bodyStrong))
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.compact + 2))
            .accessibilityIdentifier("goal.link.chooseSource")
        }
    }
}
