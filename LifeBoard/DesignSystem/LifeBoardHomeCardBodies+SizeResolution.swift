import SwiftUI

extension HomeCardBody {
    var chartHeight: CGFloat {
        switch preset {
        case .compact: 24
        case .standard: 42
        case .wide: 70
        case .tall: 104
        case .expanded: 132
        }
    }

    var ringDiameter: CGFloat {
        switch preset {
        case .compact: 38
        case .standard: 52
        case .wide: 64
        case .tall, .expanded: 76
        }
    }

    var streakDayCount: Int {
        switch preset {
        case .compact, .standard: 7
        case .wide: 14
        case .tall, .expanded: 28
        }
    }

    var streakHeight: CGFloat {
        let rows = ceil(Double(streakDayCount) / 7)
        return CGFloat(rows) * 16
    }

    var excerptLineLimit: Int {
        switch preset {
        case .compact: 2
        case .standard: 3
        case .wide: 4
        case .tall, .expanded: 8
        }
    }

    var overdueTint: Color {
        Color(SemanticColorTokens.foundationDanger)
    }

    func itemNoun(_ count: Int) -> String {
        count == 1 ? "item" : "items"
    }

    func stateSymbol(_ state: HomeQueueItem.State) -> String {
        switch state {
        case .pending: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        case .overdue: "exclamationmark.circle"
        case .skipped: "minus.circle"
        }
    }

    func stateDescription(_ state: HomeQueueItem.State) -> String {
        switch state {
        case .pending: String(localized: "Not started")
        case .inProgress: String(localized: "In progress")
        case .done: String(localized: "Done")
        case .overdue: String(localized: "From earlier")
        case .skipped: String(localized: "Skipped")
        }
    }
}

extension HomeCardBody {
    // MARK: States

    @ViewBuilder
    func emptyBody(_ snapshot: HomeCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.value ?? "Nothing yet")
                .lifeboardFont(.body)
                .foregroundStyle(palette.color(for: .foreground))
                .lineLimit(2)
            if let detail = snapshot.detail {
                Text(detail)
                    .lifeboardFont(.caption1)
                    .homeCardEvidence("body.detail", role: "text", copy: detail, typography: .init(role: "caption1", points: 13, weight: "regular"))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    func statusBody(_ snapshot: HomeCardSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: snapshot.availability == .redacted ? "lock.fill" : "exclamationmark.triangle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.value ?? (snapshot.availability == .redacted ? "Hidden here" : "Not available"))
                    .lifeboardFont(.body)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(2)
                if let detail = snapshot.detail {
                    Text(detail)
                        .lifeboardFont(.caption1)
                        .homeCardEvidence("body.detail", role: "text", copy: detail, typography: .init(role: "caption1", points: 13, weight: "regular"))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Payload absent or the wrong shape for this archetype. Falls back to the
    /// provider's own strings rather than drawing nothing.
    @ViewBuilder
    func fallbackSummary(_ snapshot: HomeCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let value = snapshot.value {
                Text(value)
                    .lifeboardFont(.bodyStrong)
                    .homeCardEvidence("body.value", role: "text", copy: value, typography: .init(role: "bodyStrong", points: 17, weight: "semibold"))
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail = snapshot.detail, preset != .compact {
                Text(detail)
                    .lifeboardFont(.caption1)
                    .homeCardEvidence("body.detail", role: "text", copy: detail, typography: .init(role: "caption1", points: 13, weight: "regular"))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
