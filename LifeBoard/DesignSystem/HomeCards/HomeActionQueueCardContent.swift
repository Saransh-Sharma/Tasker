import SwiftUI

struct HomeActionQueueCardContent: View {
    let title: String
    let symbol: String
    let rows: [HomeCardQueueRow]
    let limit: Int
    let statusMessage: String?
    let statusSymbol: String
    let actionTitle: String
    let identifier: String
    let palette: DaypartPalette
    var titleIsAction = false
    var onOpen: () -> Void = {}
    var onOpenRow: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if titleIsAction {
                Button(action: onOpen) {
                    HomeWidgetTitle(title, symbol: symbol, palette: palette)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
                .accessibilityIdentifier("home.widget.\(identifier)")
                    .homeCardEvidence("queue.title", role: "title", copy: title, typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            } else {
                HomeWidgetTitle(title, symbol: symbol, palette: palette)
                    .accessibilityIdentifier("home.widget.\(identifier)")
                    .homeCardEvidence("queue.title", role: "title", copy: title, typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            }
            if let statusMessage {
                HomeEmptyStateRow(statusMessage, symbol: statusSymbol, palette: palette)
            } else {
                ForEach(rows.prefix(limit)) { row in
                    Button { onOpenRow(row.id) } label: {
                        HStack(spacing: 11) {
                            Image(systemName: row.symbol)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title).font(.subheadline.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .homeCardEvidence("queue.\(row.id).title", role: "text", copy: row.title, typography: .init(role: "subheadline", points: 15, weight: "medium", alignment: "leading"))
                                if let detail = row.detail {
                                    Text(detail).font(.caption)
                                        .homeCardEvidence("queue.\(row.id).detail", role: "text", copy: detail, typography: .init(role: "caption", points: 12, weight: "regular", alignment: "leading"))
                                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(row.accessibilityIdentifier ?? "home.\(identifier).event.\(row.id.uuidString)")
                    .homeCardEvidence("queue.\(row.id).open", role: "control", copy: row.title)
                }
            }
            Button(actionTitle, action: onOpen)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.\(identifier).open")
                .homeCardEvidence("queue.open", role: "control", copy: actionTitle, typography: .init(role: "subheadline", points: 15, weight: "semibold", alignment: "leading"))
        }
        .padding(16)
    }
}
