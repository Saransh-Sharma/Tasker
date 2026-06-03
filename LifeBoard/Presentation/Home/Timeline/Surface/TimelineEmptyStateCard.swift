import SwiftUI

struct TimelineEmptyStateCard: View {
    let model: VisualTimelineElement.EmptyStateModel
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Spacer(minLength: 0)

            actionButtons
        }
        .padding(14)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.showsCalendarAction ? "home.timeline.calendarHidden" : "home.timeline.emptyDay")
    }

    @MainActor
    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            SunriseDecorImage(
                asset: model.showsCalendarAction ? .happySun : .cloud,
                size: 44,
                opacity: 0.9
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(model.subtitle)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    @MainActor
    var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            actionButtonColumn
        } else {
            ViewThatFits(in: .horizontal) {
                actionButtonRow
                actionButtonColumn
            }
        }
    }

    @MainActor
    var actionButtonRow: some View {
        HStack(spacing: 10) {
            emptyStateActionButton(
                title: model.primaryTitle,
                tone: .secondary,
                action: primaryAction
            )
            emptyStateActionButton(
                title: model.secondaryTitle,
                tone: .primary,
                action: secondaryAction
            )
        }
    }

    @MainActor
    var actionButtonColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            emptyStateActionButton(
                title: model.primaryTitle,
                tone: .secondary,
                action: primaryAction
            )
            emptyStateActionButton(
                title: model.secondaryTitle,
                tone: .primary,
                action: secondaryAction
            )
        }
    }

    @MainActor
    func emptyStateActionButton(
        title: String,
        tone: TimelineEmptyStateActionTone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.lifeboard(.buttonSmall))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .foregroundStyle(tone.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 34)
                .background(tone.background, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(tone.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}
