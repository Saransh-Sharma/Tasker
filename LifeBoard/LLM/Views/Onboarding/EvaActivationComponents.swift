import SwiftUI

struct EvaActivationMetrics {
    let spacing: TaskerSpacingTokens
    let corner: TaskerCornerTokens
    let layoutClass: TaskerLayoutClass

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
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            if let eyebrow, eyebrow.isEmpty == false {
                Text(eyebrow)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .tracking(1.1)
            }

            Text(title)
                .font(.tasker(.title1).weight(.bold))
                .foregroundStyle(Color.tasker(.textPrimary))

            Text(bodyText)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EvaSectionCard<Content: View>: View {
    @Environment(\.taskerLayoutClass) private var layoutClass

    let title: String
    let subtitle: String?
    let accessibilityIdentifier: String?
    @ViewBuilder let content: () -> Content

    private var metrics: EvaActivationMetrics {
        EvaActivationMetrics(
            spacing: TaskerThemeManager.shared.tokens(for: layoutClass).spacing,
            corner: TaskerThemeManager.shared.tokens(for: layoutClass).corner,
            layoutClass: layoutClass
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.cardGap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                }
            }
            .ifLet(accessibilityIdentifier) { view, value in
                view.accessibilityIdentifier(value)
            }

            content()
        }
        .padding(metrics.cardPadding)
        .taskerPremiumSurface(
            cornerRadius: metrics.cardRadius,
            fillColor: Color.tasker(.surfacePrimary).opacity(0.98),
            strokeColor: Color.tasker(.strokeHairline),
            accentColor: Color.tasker(.accentSecondary).opacity(0.45),
            level: .e1,
            useNativeGlass: false
        )
    }
}

struct EvaInfoPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundStyle(Color.tasker(.accentPrimary))
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(Color.tasker(.surfaceSecondary))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.tasker(.accentMuted).opacity(0.42), lineWidth: 1)
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
                .font(.tasker(.callout))
                .foregroundStyle(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.textPrimary))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 40, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                        .fill(isSelected ? Color.tasker(.accentWash) : Color.tasker(.surfaceSecondary))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                        .stroke(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .taskerPressFeedback(reduceMotion: reduceMotion)
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isSelected)
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
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            if isExpanded {
                Text(title)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))

                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .padding(TaskerTheme.Spacing.md)
                    .frame(minHeight: 72, alignment: .topLeading)
                    .background(Color.tasker(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                            .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                    )
                    .accessibilityIdentifier("\(accessibilityIdentifier).field")
            } else {
                Button {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.quick) {
                        isExpanded = true
                    }
                } label: {
                    Label(collapsedTitle, systemImage: "plus")
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker(.textSecondary))
                        .padding(.horizontal, TaskerTheme.Spacing.md)
                        .padding(.vertical, TaskerTheme.Spacing.sm)
                        .background(Color.tasker(.surfaceSecondary))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .taskerPressFeedback(reduceMotion: reduceMotion)
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
        HStack(spacing: TaskerTheme.Spacing.xs) {
            Text(title)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker(.textPrimary))
                .multilineTextAlignment(.leading)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.tasker(.surfacePrimary)))
            }
            .buttonStyle(.plain)
            .taskerPressFeedback(reduceMotion: reduceMotion)
            .accessibilityIdentifier("\(accessibilityIdentifier).remove")
        }
        .padding(.leading, TaskerTheme.Spacing.md)
        .padding(.trailing, TaskerTheme.Spacing.sm)
        .padding(.vertical, 10)
        .background(Color.tasker(.accentWash))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.tasker(.accentMuted), lineWidth: 1)
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

        HStack(alignment: .center, spacing: TaskerTheme.Spacing.sm) {
            TextField(placeholder, text: $draftText)
                .textFieldStyle(.plain)
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker(.textPrimary))
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .padding(.vertical, TaskerTheme.Spacing.md)
                .frame(minHeight: 52)
                .accessibilityIdentifier("\(accessibilityIdentifier).field")

            if canCommit {
                Button(action: onCommit) {
                    Text("Add outcome")
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker(.accentOnPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.md)
                        .padding(.vertical, TaskerTheme.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.tasker(.accentPrimary))
                        )
                }
                .buttonStyle(.plain)
                .taskerPressFeedback(reduceMotion: reduceMotion)
                .accessibilityIdentifier("\(accessibilityIdentifier).button")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color.tasker(.surfaceSecondary))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
        )
    }
}

struct EvaReviewCard: View {
    let draft: EvaProfileDraft
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    var body: some View {
        EvaSectionCard(
            title: "\(assistantIdentity.snapshot.displayName) will remember",
            subtitle: nil,
            accessibilityIdentifier: "eva.activation.review"
        ) {
            reviewRow(
                label: "Working style",
                value: joinedValue(
                    selectedValues: draft.selectedWorkingStyleIDs.compactMap { EvaWorkingStyleID(rawValue: $0)?.title },
                    customValue: draft.customWorkingStyleNote
                )
            )
            reviewRow(
                label: "Friction points",
                value: joinedValue(
                    selectedValues: draft.selectedMomentumBlockerIDs.compactMap { EvaMomentumBlockerID(rawValue: $0)?.title },
                    customValue: draft.customMomentumNote
                )
            )
            reviewRow(
                label: "Current goals",
                value: draft.goals
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
                    .joined(separator: " • "),
                emptyValue: "No outcomes added yet"
            )

            Text("Saved only on this device. You can edit this later in Personal Memory.")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .padding(.top, 2)
        }
    }

    private func reviewRow(label: String, value: String, emptyValue: String = "Not set yet") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker(.textSecondary))
            Text(value.isEmpty ? emptyValue : value)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker(.textPrimary))
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
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker(.textPrimary))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous)
                        .fill(Color.tasker(.surfaceTertiary))
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.tasker(.accentPrimary), Color.tasker(.accentSecondary)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0, min(progress, 1)))
                }
            }
            .frame(height: 10)

            Text(subtitle)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .monospacedDigit()
        }
        .padding(TaskerTheme.Spacing.lg)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.xl,
            fillColor: Color.tasker(.surfacePrimary),
            strokeColor: Color.tasker(.strokeHairline),
            accentColor: Color.tasker(.accentSecondary),
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
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                Text(title)
                    .font(.tasker(.title2))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text(bodyText)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: TaskerTheme.Spacing.sm) {
                Button(primaryTitle, action: onPrimary)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.tasker(.accentPrimary))
                    .accessibilityIdentifier("eva.activation.recovery.retry")

                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(.bordered)
                    .tint(Color.tasker(.accentPrimary))
                    .accessibilityIdentifier("eva.activation.recovery.switch_fast")

                Button(tertiaryTitle, action: onTertiary)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .accessibilityIdentifier("eva.activation.recovery.open_models")
            }

            Text(footerText)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
        }
        .padding(TaskerTheme.Spacing.xl)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.modal,
            fillColor: Color.tasker(.surfacePrimary),
            strokeColor: Color.tasker(.strokeHairline),
            accentColor: Color.tasker(.accentSecondary),
            level: .e2,
            useNativeGlass: false
        )
    }
}

struct EvaFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = arrangeRows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map { row in row.width }.max() ?? 0
        let height = rows.reduce(0) { partialResult, row in
            partialResult + row.height
        } + max(0, CGFloat(rows.count - 1) * rowSpacing)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = arrangeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                let proposal = ProposedViewSize(width: element.size.width, height: element.size.height)
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: proposal
                )
                x += element.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func arrangeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        guard subviews.isEmpty == false else { return [] }

        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.elements.isEmpty ? size.width : current.width + spacing + size.width

            if current.elements.isEmpty == false && nextWidth > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.elements.append(Row.Element(index: index, size: size))
            current.width = current.elements.dropFirst().reduce(current.elements.first?.size.width ?? 0) { partialResult, element in
                partialResult + spacing + element.size.width
            }
            current.height = max(current.height, size.height)
        }

        if current.elements.isEmpty == false {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        struct Element {
            let index: Int
            let size: CGSize
        }

        var elements: [Element] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}
