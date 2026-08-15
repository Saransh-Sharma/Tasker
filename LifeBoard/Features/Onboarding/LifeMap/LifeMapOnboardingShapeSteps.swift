import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// Capacity, connections, and the one real thing the user routes. These three
// beats turn preferences into a working system: honest hours, the modules that
// serve the stated goal, and proof that capture lands somewhere sensible.

// MARK: - Capacity

struct LifeMapCapacityStep: View {
    let dayShape: OnboardingDayShapeDraft
    let onUpdate: ((inout OnboardingDayShapeDraft) -> Void) -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "When does life actually fit?",
            support: "A realistic boundary makes every plan more honest."
        ) {
            LifeMapCapacityRow(
                title: "Weekdays",
                start: dayShape.weekdayStartMinute,
                end: dayShape.weekdayEndMinute,
                onStart: { value in
                    onUpdate { $0.weekdayStartMinute = min(value, $0.weekdayEndMinute - 30) }
                },
                onEnd: { value in
                    onUpdate { $0.weekdayEndMinute = max(value, $0.weekdayStartMinute + 30) }
                }
            )

            Toggle("I make time on weekends", isOn: Binding(
                get: { dayShape.worksWeekends },
                set: { value in onUpdate { $0.worksWeekends = value } }
            ))
            .font(.lifeboard(.bodyStrong))
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .tint(Color.lifeboard(.accentPrimary))
            .padding(Theme.Spacing.lg)
            .lifeBoardClaySurface(.resting, cornerRadius: 18)
            .accessibilityIdentifier(LifeMapAccessibilityID.worksWeekends)

            if dayShape.worksWeekends {
                LifeMapCapacityRow(
                    title: "Weekend",
                    start: dayShape.weekendStartMinute,
                    end: dayShape.weekendEndMinute,
                    onStart: { value in
                        onUpdate { $0.weekendStartMinute = min(value, $0.weekendEndMinute - 30) }
                    },
                    onEnd: { value in
                        onUpdate { $0.weekendEndMinute = max(value, $0.weekendStartMinute + 30) }
                    }
                )
            }

            Picker("Week starts", selection: Binding(
                get: { dayShape.weekStartsOn },
                set: { value in onUpdate { $0.weekStartsOn = value } }
            )) {
                Text("Monday").tag(Weekday.monday)
                Text("Sunday").tag(Weekday.sunday)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(LifeMapAccessibilityID.weekStartsOn)
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.capacity))
    }
}

private struct LifeMapCapacityRow: View {
    let title: String
    let start: Int
    let end: Int
    let onStart: (Int) -> Void
    let onEnd: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color.lifeboard(.textPrimary))
            HStack(spacing: Theme.Spacing.sm) {
                LifeMapTimeStepper(label: "Start", value: start, action: onStart)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                LifeMapTimeStepper(label: "End", value: end, action: onEnd)
            }
        }
        .padding(Theme.Spacing.lg)
        .lifeBoardClaySurface(.resting, cornerRadius: 20)
        .lifeboardValueDrumWarp(grip: 0.22)
    }
}

/// Steppers rather than a slider: 30-minute detents are the real granularity of
/// a working day, and buttons are reachable by Switch Control and VoiceOver
/// without a custom rotor.
private struct LifeMapTimeStepper: View {
    let label: String
    let value: Int
    let action: (Int) -> Void

    var body: some View {
        VStack(spacing: 7) {
            Text(label)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
            HStack(spacing: Theme.Spacing.sm) {
                Button { action(max(0, value - 30)) } label: {
                    Image(systemName: "minus")
                }
                .accessibilityLabel("\(label) earlier")
                Text(OnboardingDayShapeDraft.label(forMinute: value))
                    .font(.lifeboard(.bodyStrong))
                    .monospacedDigit()
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .frame(minWidth: 74)
                Button { action(min(24 * 60, value + 30)) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("\(label) later")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .lifeBoardClaySurface(.well, cornerRadius: 14)
        .accessibilityElement(children: .contain)
        .accessibilityValue(OnboardingDayShapeDraft.label(forMinute: value))
    }
}

// MARK: - Connections

struct LifeMapConnectionsStep: View {
    let selectedGroups: Set<LifeMapModuleGroup>
    let onToggle: (LifeMapModuleGroup) -> Void
    let onTune: () -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "Here’s how LifeBoard will work for you.",
            support: "Recommended from what you shared. Tap a root in the map for a live preview."
        ) {
            ForEach(LifeMapModuleGroup.allCases) { group in
                LifeMapChoiceRow(
                    title: group.title,
                    subtitle: group.subtitle,
                    symbol: group.symbol,
                    isSelected: selectedGroups.contains(group)
                ) {
                    onToggle(group)
                }
                .accessibilityIdentifier(LifeMapAccessibilityID.moduleGroup(group.id))
            }
            Button("Tune individual modules", action: onTune)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier(LifeMapAccessibilityID.tuneModules)
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.connections))
    }
}

// MARK: - Capture

struct LifeMapCaptureStep: View {
    @Binding var text: String
    let staged: LifeMapStagedCapture?
    let areaTemplates: [StarterLifeAreaTemplate]
    let isResolving: Bool
    let cardMorphTrigger: Int
    let onInterpret: () -> Void
    let onReview: (LifeMapCaptureKind, String?) -> Void
    let onSkip: () -> Void

    private var canInterpret: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && isResolving == false
    }

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What’s taking up mental space?",
            support: "One real thing. LifeBoard suggests where it belongs; nothing is saved until you approve it."
        ) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                TextField("e.g. Book the dentist appointment", text: $text, axis: .vertical)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .padding(Theme.Spacing.lg)
                    .lifeBoardClaySurface(.well, cornerRadius: 20)
                    .accessibilityIdentifier(LifeMapAccessibilityID.captureField)
                Button(action: onInterpret) {
                    Group {
                        if isResolving {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up")
                        }
                    }
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                    .frame(width: 48, height: 48)
                    .background(Color.lifeboard(.accentPrimary), in: Circle())
                }
                .disabled(canInterpret == false)
                .accessibilityLabel("Interpret")
                .accessibilityIdentifier(LifeMapAccessibilityID.captureInterpret)
            }

            if let staged {
                LifeMapCaptureReviewCard(
                    capture: staged,
                    areaTemplates: areaTemplates,
                    cardMorphTrigger: cardMorphTrigger,
                    onReview: onReview
                )
            }

            Button("Not now", action: onSkip)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier(LifeMapAccessibilityID.captureSkip)
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.capture))
    }
}

/// The screen's one hero.
///
/// This is the moment the flow asks for a decision about the user's own data, so
/// it is the object that earns Regular Glass here. The dock is floating chrome
/// and does not compete; nothing else on this step claims a hero.
private struct LifeMapCaptureReviewCard: View {
    let capture: LifeMapStagedCapture
    let areaTemplates: [StarterLifeAreaTemplate]
    let cardMorphTrigger: Int
    let onReview: (LifeMapCaptureKind, String?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Review the route", systemImage: "scope")
                .font(.lifeboard(.eyebrow))
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Text(capture.text)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)

            Picker("Type", selection: Binding(
                get: { capture.kind },
                set: { onReview($0, capture.lifeAreaTemplateID) }
            )) {
                ForEach(LifeMapCaptureKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(LifeMapAccessibilityID.captureKindPicker)

            Picker("Life area", selection: Binding<String?>(
                get: { capture.lifeAreaTemplateID },
                set: { onReview(capture.kind, $0) }
            )) {
                Text("Inbox").tag(String?.none)
                ForEach(areaTemplates) { area in
                    Text(area.name).tag(Optional(area.id))
                }
            }
            .pickerStyle(.menu)
            .tint(Color.lifeboard(.accentPrimary))
            .accessibilityIdentifier(LifeMapAccessibilityID.captureAreaPicker)

            Button(capture.isReviewed ? "Route approved" : "Approve this route") {
                onReview(capture.kind, capture.lifeAreaTemplateID)
            }
            .buttonStyle(LifeMapPrimaryButtonStyle())
            .accessibilityIdentifier(LifeMapAccessibilityID.captureApprove)
            .accessibilityAddTraits(capture.isReviewed ? .isSelected : [])
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(
            palette: DaypartTokens.appearancePalette(for: .morning, colorScheme: colorScheme),
            cornerRadius: 22
        )
        .lifeboardCardMorphWarp(origin: .topTrailing, trigger: cardMorphTrigger)
        .lifeboardContextLens(center: .topTrailing, trigger: cardMorphTrigger)
    }
}
