import SwiftUI

// Where 'now' is, and the marks that say so.

// MARK: - TimelineNowBeadPresentation

struct TimelineNowBeadPresentation: Equatable {
    static func clampedY(_ y: CGFloat, contentHeight: CGFloat, verticalInset: CGFloat = 14) -> CGFloat {
        let upper = max(contentHeight - verticalInset, verticalInset)
        return min(max(y, verticalInset), upper)
    }

    static func shouldPulse(reduceMotion: Bool) -> Bool {
        reduceMotion == false
    }
}

// MARK: - TimelineNowBeadView

struct TimelineNowBeadView: View {
    let time: Date
    let railMetrics: TimelineRailMetrics
    let beadX: CGFloat
    let reduceMotion: Bool
    @State var pulseIsExpanded = false

    var body: some View {
        ZStack(alignment: .leading) {
            Text("Now · \(TimelineRailTimeFormatter.railText(for: time, kind: .current))")
                .font(TimelineRailTypography.font(for: .current, isEmphasized: true))
                .monospacedDigit()
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.lifeboard.surfacePrimary.opacity(0.94), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.lifeboard.accentPrimary.opacity(0.36), lineWidth: 1)
                }
                .offset(x: max(railMetrics.labelLeadingX, beadX - 58), y: -14)

            if TimelineNowBeadPresentation.shouldPulse(reduceMotion: reduceMotion) {
                Circle()
                    .stroke(Color.lifeboard.accentPrimary.opacity(pulseIsExpanded ? 0 : 0.28), lineWidth: 1.4)
                    .frame(width: 25, height: 25)
                    .scaleEffect(pulseIsExpanded ? 1.28 : 1)
                    .offset(x: beadX - 12.5, y: -12.5)
            }

            Circle()
                .fill(Color.lifeboard.accentPrimary.opacity(reduceMotion ? 0.18 : 0.26))
                .frame(width: 24, height: 24)
                .offset(x: beadX - 12, y: -12)

            Circle()
                .fill(Color.lifeboard.accentPrimary)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(ClayColorTokens.whiteStroke.opacity(0.76), lineWidth: 1)
                }
                .offset(x: beadX - 5.5, y: -5.5)
        }
        .frame(height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current time")
        .accessibilityValue(time.formatted(date: .omitted, time: .shortened))
        .onAppear {
            guard TimelineNowBeadPresentation.shouldPulse(reduceMotion: reduceMotion) else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulseIsExpanded = true
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue {
                pulseIsExpanded = false
            } else {
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    pulseIsExpanded = true
                }
            }
        }
    }
}

// MARK: - TimelineCurrentTimeMarker

struct TimelineCurrentTimeMarker: View {
    let time: Date
    let railMetrics: TimelineRailMetrics
    let startX: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            TimelineRailLabel(
                text: TimelineRailTimeFormatter.railText(for: time, kind: .current),
                kind: .current,
                isEmphasized: true,
                color: Color.lifeboard.statusDanger,
                metrics: railMetrics
            )
                .offset(y: -8)

            Circle()
                .fill(Color.lifeboard.statusDanger)
                .frame(width: 8, height: 8)
                .offset(x: startX - 4, y: -4)
        }
        .frame(width: startX + 4, height: 1, alignment: .leading)
    }
}

// MARK: - TimelineCurrentTimeRule

struct TimelineCurrentTimeRule: View {
    let startX: CGFloat
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.lifeboard.statusDanger.opacity(0.16))
            .frame(width: min(max(width - startX, 0), 92), height: 1)
            .offset(x: startX, y: -0.5)
            .frame(width: width, height: 1, alignment: .leading)
    }
}

// MARK: - TimelineEndAddMarker

struct TimelineEndAddMarker: View {
    let suggestedDate: Date
    let accessibilityValue: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(TimelineVisualTokens.utilityText.opacity(0.55))
                .frame(width: TimelineCanvasLayoutPlan.endMarkerHitArea, height: TimelineCanvasLayoutPlan.endMarkerHitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task after timeline")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens Add Task with a suggested timeline time.")
        .accessibilityIdentifier("home.timeline.endAdd")
    }
}

// MARK: - TimelineCompletionRing

struct TimelineCompletionRing: View {
    let color: Color
    let isCompleted: Bool
    let isInteractive: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Group {
            if isInteractive {
                Button(action: action) {
                    ringBody
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityValue(isCompleted ? "Completed" : "Not completed")
            } else {
                ringBody
                    .accessibilityHidden(true)
            }
        }
    }

    var ringBody: some View {
        Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(color)
            .symbolRenderingMode(.hierarchical)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - TimelineSpineEndView

struct TimelineSpineEndView: View {
    let extent: TimelineCanvasLayoutPlan.SpineExtent
    let lineWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(TimelineVisualTokens.neutralStem)
                .frame(width: lineWidth, height: max(extent.solidEndY - extent.startY, 0))
                .offset(y: extent.startY)

            LinearGradient(
                colors: [
                    TimelineVisualTokens.neutralStem,
                    TimelineVisualTokens.neutralStem.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: lineWidth, height: max(extent.fadeEndY - extent.fadeStartY, 0))
            .offset(y: extent.fadeStartY)
        }
    }
}

// MARK: - TimelineSpineMounting

enum TimelineSpineMounting {
    static func centerX(for geometry: TimelineStreamGeometry, atY y: CGFloat) -> CGFloat {
        geometry.x(atY: y)
    }

    static func routineTextLeadingX(
        for geometry: TimelineStreamGeometry,
        atY y: CGFloat,
        iconSize: CGFloat,
        railMetrics: TimelineRailMetrics
    ) -> CGFloat {
        railMetrics.routineTextLeadingX(
            iconSize: iconSize,
            mountedSpineX: centerX(for: geometry, atY: y)
        )
    }
}

// MARK: - TimelineStemSegments

struct TimelineStemSegments: View {
    let leading: TimelineStemSegmentState
    let trailing: TimelineStemSegmentState
    let fallbackPalette: TimelinePalette
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(timelineStemColor(for: leading, fallbackPalette: fallbackPalette))
                .frame(width: width, height: height / 2)
            Rectangle()
                .fill(timelineStemColor(for: trailing, fallbackPalette: fallbackPalette))
                .frame(width: width, height: height / 2)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - timelineDisplayedNow

func timelineDisplayedNow(for projection: TimelineDayProjection, timelineDate: Date) -> Date {
    Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
}
