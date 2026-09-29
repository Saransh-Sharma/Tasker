import SwiftUI

struct EvaActivationMetrics {
    let spacing: SemanticSpacingTokens
    let corner: CornerTokens
    let layoutClass: LayoutClass

    var sectionGap: CGFloat { spacing.s20 }
    var cardGap: CGFloat { spacing.s16 }
    var chipGap: CGFloat { spacing.s8 }
    var screenTop: CGFloat { spacing.s16 }
    var screenBottom: CGFloat { spacing.s24 }
    var horizontalPadding: CGFloat { max(spacing.screenHorizontal, layoutClass.isPad ? 28 : spacing.screenHorizontal) }
    var cardPadding: CGFloat { spacing.s20 }
    var cardRadius: CGFloat { max(corner.r4, 28) }
    var chipRadius: CGFloat { max(corner.r3, 22) }
    var buttonHeight: CGFloat { 56 }
    var noteCollapsedHeight: CGFloat { 52 }
    var noteExpandedMinHeight: CGFloat { 72 }
}

struct EvaContentHeader: View {
    let title: String
    let bodyText: String
    let eyebrow: String?

    init(
        title: String,
        bodyText: String,
        eyebrow: String? = nil
    ) {
        self.title = title
        self.bodyText = bodyText
        self.eyebrow = eyebrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let eyebrow, eyebrow.isEmpty == false {
                Text(eyebrow)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .tracking(1.1)
            }

            Text(title)
                .font(.lifeboard(.title1).weight(.bold))
                .foregroundStyle(Color.lifeboard(.textPrimary))

            Text(bodyText)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EvaSectionCard<Content: View>: View {
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    let title: String
    let subtitle: String?
    let accessibilityIdentifier: String?
    @ViewBuilder let content: () -> Content

    private var metrics: EvaActivationMetrics {
        EvaActivationMetrics(
            spacing: tokens.spacing,
            corner: tokens.corner,
            layoutClass: layoutClass
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.cardGap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
            }
            .ifLet(accessibilityIdentifier) { view, value in
                view.accessibilityIdentifier(value)
            }

            content()
        }
        .padding(metrics.cardPadding)
        .lifeboardPremiumSurface(
            cornerRadius: metrics.cardRadius,
            fillColor: Color.lifeboard(.surfacePrimary).opacity(0.98),
            strokeColor: Color.lifeboard(.strokeHairline),
            accentColor: Color.lifeboard(.accentSecondary).opacity(0.45),
            level: .e1,
            useNativeGlass: false
        )
    }
}

struct EvaInfoPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(Color.lifeboard(.accentPrimary))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 12)
            .background(Color.lifeboard(.surfaceSecondary))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.lifeboard(.accentMuted).opacity(0.42), lineWidth: 1)
            )
    }
}

struct EvaSelectionChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.lifeboard(.callout))
                .foregroundStyle(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textPrimary))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 40, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                        .fill(isSelected ? Color.lifeboard(.accentWash) : Color.lifeboard(.surfaceSecondary))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                        .stroke(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .lifeboardPressFeedback()
        .animation(reduceMotion ? nil : LifeBoardAnimation.feedbackFast, value: isSelected)
    }
}

struct EvaCollapsedNoteField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let collapsedTitle: String
    let placeholder: String
    let accessibilityIdentifier: String
    @Binding var text: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if isExpanded {
                Text(title)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))

                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .padding(Theme.Spacing.md)
                    .frame(minHeight: 72, alignment: .topLeading)
                    .background(Color.lifeboard(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                            .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                    )
                    .accessibilityIdentifier("\(accessibilityIdentifier).field")
            } else {
                Button {
                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                        isExpanded = true
                    }
                } label: {
                    Label(collapsedTitle, systemImage: "plus")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.lifeboard(.surfaceSecondary))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .lifeboardPressFeedback()
                .accessibilityIdentifier("\(accessibilityIdentifier).toggle")
            }
        }
    }
}

struct EvaGoalChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let accessibilityIdentifier: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .multilineTextAlignment(.leading)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .lifeboardFont(.eyebrow)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.lifeboard(.surfacePrimary)))
            }
            .buttonStyle(.plain)
        .lifeboardPressFeedback()
            .accessibilityIdentifier("\(accessibilityIdentifier).remove")
        }
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.sm)
        .padding(.vertical, 12)
        .background(Color.lifeboard(.accentWash))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.lifeboard(.accentMuted), lineWidth: 1)
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct EvaGoalComposer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let placeholder: String
    let accessibilityIdentifier: String
    @Binding var draftText: String
    let isDisabled: Bool
    let onCommit: () -> Void

    var body: some View {
        let canCommit = draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isDisabled

        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            TextField(placeholder, text: $draftText)
                .textFieldStyle(.plain)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .frame(minHeight: 52)
                .accessibilityIdentifier("\(accessibilityIdentifier).field")

            if canCommit {
                Button(action: onCommit) {
                    Text("Add outcome")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.lifeboard(.accentPrimary))
                        )
                }
                .buttonStyle(.plain)
                .lifeboardPressFeedback()
                .accessibilityIdentifier("\(accessibilityIdentifier).button")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color.lifeboard(.surfaceSecondary))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
        )
    }
}

struct EvaReviewCard: View {
    let draft: EvaProfileDraft
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    var body: some View {
        EvaSectionCard(
            title: String(localized: "\(assistantIdentity.snapshot.displayName) will remember"),
            subtitle: nil,
            accessibilityIdentifier: "eva.activation.review"
        ) {
            reviewRow(
                label: String(localized: "Working style"),
                value: joinedValue(
                    selectedValues: draft.selectedWorkingStyleIDs.compactMap { EvaWorkingStyleID(rawValue: $0)?.title },
                    customValue: draft.customWorkingStyleNote
                )
            )
            reviewRow(
                label: String(localized: "Blockers"),
                value: joinedValue(
                    selectedValues: draft.selectedMomentumBlockerIDs.compactMap { EvaMomentumBlockerID(rawValue: $0)?.title },
                    customValue: draft.customMomentumNote
                )
            )
            reviewRow(
                label: String(localized: "Outcomes"),
                value: draft.goals
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
                    .joined(separator: " • "),
                emptyValue: String(localized: "None yet")
            )

            Text("Saved on \(DeviceNoun.this). Edit it in Settings.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .padding(.top, 2)
        }
    }

    private func reviewRow(label: String, value: String, emptyValue: String = String(localized: "Not set")) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Text(value.isEmpty ? emptyValue : value)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func joinedValue(selectedValues: [String], customValue: String?) -> String {
        var segments = selectedValues
        if let trimmedCustomValue = customValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           trimmedCustomValue.isEmpty == false {
            segments.append(trimmedCustomValue)
        }
        return segments.joined(separator: ", ")
    }
}

struct EvaInstallProgressCard: View {
    let title: String
    let progress: Double
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard(.textPrimary))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous)
                        .fill(Color.lifeboard(.surfaceTertiary))
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.lifeboard(.accentPrimary), Color.lifeboard(.accentSecondary)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0, min(progress, 1)))
                }
            }
            .frame(height: 10)

            Text(subtitle)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .monospacedDigit()
        }
        .padding(Theme.Spacing.lg)
        .lifeboardPremiumSurface(
            cornerRadius: Theme.CornerRadius.xl,
            fillColor: Color.lifeboard(.surfacePrimary),
            strokeColor: Color.lifeboard(.strokeHairline),
            accentColor: Color.lifeboard(.accentSecondary),
            level: .e1,
            useNativeGlass: false
        )
    }
}

struct EvaRecoveryCard: View {
    let title: String
    let bodyText: String
    let footerText: String
    let primaryTitle: String
    let secondaryTitle: String
    let tertiaryTitle: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onTertiary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.lifeboard(.title2))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(bodyText)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Button(primaryTitle, action: onPrimary)
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .tint(Color.lifeboard(.accentPrimary))
                    .accessibilityIdentifier("eva.activation.recovery.retry")

                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(.bordered)
                    .tint(Color.lifeboard(.accentPrimary))
                    .accessibilityIdentifier("eva.activation.recovery.switch_fast")

                Button(tertiaryTitle, action: onTertiary)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .accessibilityIdentifier("eva.activation.recovery.open_models")
            }

            Text(footerText)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .padding(Theme.Spacing.xl)
        .lifeboardPremiumSurface(
            cornerRadius: Theme.CornerRadius.modal,
            fillColor: Color.lifeboard(.surfacePrimary),
            strokeColor: Color.lifeboard(.strokeHairline),
            accentColor: Color.lifeboard(.accentSecondary),
            level: .e2,
            useNativeGlass: false
        )
    }
}

extension View {
    /// Applies `transform` when `value` is non-nil.
    ///
    /// Moved here from the deleted `FocusZone.swift`; this file is its only
    /// caller. It branches, so the transformed view gets a new identity when
    /// `value` appears or disappears — fine for a static label, wrong for
    /// anything holding state.
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, @ViewBuilder transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
