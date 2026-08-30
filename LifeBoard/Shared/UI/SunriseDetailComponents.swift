//
//  SunriseDetailComponents.swift
//  LifeBoard
//

import SwiftUI

extension AnyTransition {
    /// Shared reveal idiom for collapsible detail surfaces (`DetailDisclosureCard`
    /// and `CalmInlineReveal`): content slides down on insertion, fades on removal.
    static var sunriseDisclosureReveal: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        )
    }
}

/// A quiet autosave indicator shared by the task and habit detail screens: a
/// small dot plus label that stays out of the way. "Saving" only surfaces if
/// the save runs longer than ~400ms; "Saved" fades away after a beat; a
/// failure stays put until the next successful save.
struct AutosaveWhisper: View {
    let state: TaskDetailAutosaveState

    @State private var visible = false
    @State private var savingDelayTask: Task<Void, Never>?
    @State private var savedFadeTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if visible {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(ClayTypography.meta)
                        .foregroundStyle(labelColor)
                }
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(label)
            }
        }
        .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.stateChange, value: visible)
        .onChange(of: state) { _, newValue in handle(newValue) }
        .onAppear { handle(state) }
    }

    private var label: String {
        switch state {
        case .idle, .debouncing, .saving: return "Saving…"
        case .saved: return "Saved"
        case .failed: return "Couldn't save"
        }
    }

    private var tint: Color {
        switch state {
        case .failed: return DetailTonePalette.dangerText
        case .saved: return DetailTonePalette.successText
        default: return ClayColorTokens.textTertiary
        }
    }

    private var labelColor: Color {
        if case .failed = state {
            return DetailTonePalette.dangerText
        }
        return ClayColorTokens.textTertiary
    }

    private func handle(_ newValue: TaskDetailAutosaveState) {
        savingDelayTask?.cancel()
        savedFadeTask?.cancel()
        switch newValue {
        case .idle, .debouncing:
            visible = false
        case .saving:
            // Only reveal a "Saving…" whisper if the work outlasts a blink.
            savingDelayTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard Task.isCancelled == false, case .saving = state else { return }
                visible = true
            }
        case .saved:
            visible = true
            savedFadeTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard Task.isCancelled == false, case .saved = state else { return }
                visible = false
            }
        case .failed:
            visible = true
        }
    }
}

struct DetailDisclosureCard<Content: View>: View {
    let title: String
    let systemImage: String
    let summary: String
    let isExpanded: Bool
    var accessibilityIdentifier: String?
    let action: () -> Void
    let content: Content

    @Environment(\.lifeboardTokens) private var tokens
    private var spacing: SemanticSpacingTokens { tokens.spacing }

    init(
        title: String,
        systemImage: String,
        summary: String,
        isExpanded: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.summary = summary
        self.isExpanded = isExpanded
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? spacing.s12 : 0) {
            Button(action: action) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    Image(systemName: systemImage)
                        .lifeboardFont(.headline)
                        .foregroundStyle(isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(isExpanded ? Color.lifeboard.accentWash : Color.lifeboard.surfacePrimary.opacity(0.78), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        Text(summary)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .lifeboardFont(.eyebrow)
                        .foregroundStyle(isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(Color.lifeboard.surfacePrimary.opacity(0.7), in: Circle())
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title). \(summary)")
            .accessibilityHint(isExpanded ? "Collapse section" : "Expand section")
            .accessibilityIdentifier(accessibilityIdentifier ?? "")

            if isExpanded {
                content
                    .transition(.sunriseDisclosureReveal)
            }
        }
        .padding(spacing.s12)
        .lifeboardChromeSurface(
            cornerRadius: Theme.CornerRadius.card,
            accentColor: isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.accentSecondary,
            level: isExpanded ? .e1 : .e0
        )
        .animation(LifeBoardAnimation.stateChange, value: isExpanded)
    }
}

/// A status-toned secondary action.
///
/// The tone is the reason this exists rather than being `.lifeBoardChip`: it
/// carries recorded state, and `DESIGN.md` is explicit that status colour means
/// something. What it should not have carried is its own *material* — it drew a
/// flat capsule with its own stroke, one of nine ways this app had to draw a
/// surface. It is clay now, tinted by its tone.
///
/// It also dropped `.minimumScaleFactor(0.82)`. `DESIGN.md`: "Never shrink type
/// to preserve a card grid or one-line toolbar." At accessibility sizes the
/// label takes a second line instead.
struct DetailCapsuleButtonStyle: ButtonStyle {
    let tone: StatusPillTone

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lifeboardFont(.buttonSmall)
            .foregroundStyle(tone.textColor)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .lifeBoardClaySurface(
                .resting,
                cornerRadius: Radius.pill,
                fill: tone.fillColor,
                isPressed: configuration.isPressed
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(LifeBoardAnimation.press, value: configuration.isPressed)
    }
}

/// A bare text action. No material by design — this is the "quiet alternative"
/// beside a primary, and `DESIGN.md` allows a screen at most one of those.
struct TextButtonStyle: ButtonStyle {
    let tone: StatusPillTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lifeboardFont(.buttonSmall)
            .foregroundStyle(tone.textColor)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

// MARK: - Calm Canvas kit
//
// Shared primitives for the "Calm Canvas" creation/detail surfaces: a single focal
// input, a living preview, a rail of tappable summary chips, and one quiet reveal for
// depth. All built from existing tokens — no new shadow / system fonts.

/// A calm, tappable summary pill used in the essentials rail. Shows a value with a quiet
/// empty state, fills with accent when set, and lifts into an "active" look while its
/// inline editor is open.
struct CalmSummaryChip: View {
    enum FillState {
        case empty
        case filled
        case active
    }

    let icon: String
    let label: String
    let state: FillState
    var accentColor: Color = ClayColorTokens.violet
    var showsChevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.lifeboard(.caption1).weight(.semibold))
                Text(label)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .lineLimit(1)
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.lifeboard(.caption2).weight(.bold))
                        .rotationEffect(.degrees(state == .active ? 180 : 0))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(background)
            .overlay(border)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(LifeBoardAnimation.stateChange, value: state)
        .accessibilityLabel("\(label)")
    }

    private var foreground: Color {
        switch state {
        case .empty: return ClayColorTokens.textTertiary
        case .filled, .active: return accentColor
        }
    }

    @ViewBuilder private var background: some View {
        switch state {
        case .empty:
            Capsule().fill(ClayColorTokens.glassStrong.opacity(0.5))
        case .filled:
            Capsule().fill(accentColor.opacity(0.10))
        case .active:
            Capsule().fill(accentColor.opacity(0.16))
        }
    }

    @ViewBuilder private var border: some View {
        switch state {
        case .empty:
            Capsule().strokeBorder(ClayColorTokens.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        case .filled:
            Capsule().strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
        case .active:
            Capsule().strokeBorder(accentColor.opacity(0.40), lineWidth: 1.5)
        }
    }
}

/// One quiet "door" that replaces a stack of competing disclosure cards. Collapsed by
/// default; reveals grouped depth on tap. Carries an optional accessibility identifier so
/// existing UI-test contracts (e.g. `addTask.detailsDisclosure`) keep resolving.
struct CalmInlineReveal<Content: View>: View {
    let title: String
    let collapsedHint: String
    @Binding var isExpanded: Bool
    var accessibilityID: String?
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? ClayLayoutMetrics.md : 0) {
            Button(action: onToggle) {
                HStack(spacing: ClayLayoutMetrics.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.lifeboard(.callout).weight(.semibold))
                            .foregroundStyle(isExpanded ? ClayColorTokens.violet : ClayColorTokens.navy)
                        if isExpanded == false {
                            Text(collapsedHint)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(ClayColorTokens.navyMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(isExpanded ? ClayColorTokens.violet : ClayColorTokens.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityID ?? "")

            if isExpanded {
                content()
                    .transition(.sunriseDisclosureReveal)
            }
        }
        .padding(ClayLayoutMetrics.md)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ClayColorTokens.glass.opacity(isExpanded ? 0.9 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .stroke(ClayColorTokens.glassBorder, lineWidth: 1)
        )
        .animation(LifeBoardAnimation.stateChange, value: isExpanded)
    }
}

/// A quiet labelled group used inside `CalmInlineReveal`. A small caption over a content
/// stack — no heavy card chrome — with each row gently staggered in.
struct CalmFieldGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ClayLayoutMetrics.sm) {
            Text(title.uppercased())
                .font(.lifeboard(.meta))
                .tracking(0.8)
                .foregroundStyle(ClayColorTokens.textTertiary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Calm Canvas kit") {
    CalmCanvasKitPreview()
}

private struct CalmCanvasKitPreview: View {
    @State private var refineExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClayLayoutMetrics.lg) {
                HStack(spacing: ClayLayoutMetrics.xs) {
                    CalmSummaryChip(icon: "clock", label: "Choose time", state: .empty) {}
                    CalmSummaryChip(icon: "leaf", label: "Health", state: .filled, accentColor: .green) {}
                    CalmSummaryChip(icon: "circle.dashed", label: "Any area", state: .active) {}
                }

                CalmInlineReveal(
                    title: "Refine",
                    collapsedHint: "Notes · Project · Priority",
                    isExpanded: $refineExpanded,
                    accessibilityID: "preview.refine",
                    onToggle: { refineExpanded.toggle() }
                ) {
                    VStack(alignment: .leading, spacing: ClayLayoutMetrics.md) {
                        CalmFieldGroup(title: "Notes") {
                            Text("Add the details that don't need to be up front.")
                                .font(.lifeboard(.callout))
                                .foregroundStyle(ClayColorTokens.navyMuted)
                        }
                        CalmFieldGroup(title: "Organize") {
                            Text("Project · Priority · Tags")
                                .font(.lifeboard(.callout))
                                .foregroundStyle(ClayColorTokens.navyMuted)
                        }
                    }
                }
            }
            .padding()
        }
        .background(ClayColorTokens.canvas)
    }
}
