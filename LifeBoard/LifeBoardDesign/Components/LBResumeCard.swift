import SwiftUI

/// Calm "pick up where you left off" prompt shown at the top of Home after a break.
/// Time-of-day aware and always dismissible — designed to orient, never to pressure.
struct LBResumeCard: View {
    let context: HomeResumeContext
    let onResume: (HomeResumeContext) -> Void
    let onDismiss: () -> Void

    var body: some View {
        LBGlassCard {
            VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LBColorTokens.violet)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(LBTypographyTokens.cardTitle)
                            .foregroundStyle(LBColorTokens.navy)
                        Text(subtitle)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: LBSpacingTokens.sm) {
                    LBPrimaryButton(title: primaryTitle, systemImage: primarySymbol) {
                        onResume(context)
                    }

                    Button(action: onDismiss) {
                        Text("Not now")
                            .font(LBTypographyTokens.chip)
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .frame(minHeight: 48)
                            .padding(.horizontal, LBSpacingTokens.md)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LBSpacingTokens.md)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private var iconName: String {
        switch context.mode {
        case .morningBrief: return "sun.max.fill"
        case .resumeTask: return "arrow.uturn.left.circle.fill"
        case .eveningWrap: return "moon.stars.fill"
        }
    }

    private var title: String {
        switch context.mode {
        case .morningBrief: return "Good morning"
        case .resumeTask: return "Pick up where you left off"
        case .eveningWrap: return "Wrap up the day"
        }
    }

    private var subtitle: String {
        switch context.mode {
        case let .morningBrief(taskCount, nextItem):
            let base = taskCount == 1 ? "1 task on your plate today" : "\(taskCount) tasks on your plate today"
            if let nextItem, nextItem.isEmpty == false {
                return "\(base) · Next: \(nextItem)"
            }
            return base
        case let .resumeTask(taskTitle, minutes, _):
            return "\(taskTitle) · paused \(minutes) min ago"
        case let .eveningWrap(doneCount, openCount):
            let done = doneCount == 1 ? "1 done today" : "\(doneCount) done today"
            if openCount > 0 {
                return "\(done) · \(openCount) still open"
            }
            return done
        }
    }

    private var primaryTitle: String {
        switch context.mode {
        case .morningBrief: return "Plan the day"
        case .resumeTask: return "Resume"
        case .eveningWrap: return "Review"
        }
    }

    private var primarySymbol: String {
        switch context.mode {
        case .morningBrief: return "list.bullet"
        case .resumeTask: return "play.fill"
        case .eveningWrap: return "checkmark.circle"
        }
    }
}
