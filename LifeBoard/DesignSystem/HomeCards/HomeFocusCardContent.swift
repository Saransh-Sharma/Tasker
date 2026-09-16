import SwiftUI

struct HomeFocusCardContent: View {
    let title: String
    let primary: String
    let reason: String?
    let symbol: String
    let actionTitle: String
    let actionHint: String
    let preset: WidgetSizePreset
    let palette: DaypartPalette
    var onOpen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .homeCardEvidence("focus.title", role: "title", copy: title, typography: .init(role: "caption", points: 12, weight: "semibold", alignment: "leading"))
                Text(primary)
                    .lifeboardFont(.headline)
                    .lineLimit(preset == .standard ? 2 : 4)
                    .homeCardEvidence("focus.primary", role: "text", copy: primary, typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
                if let reason {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .homeCardEvidence("focus.reason", role: "text", copy: reason, typography: .init(role: "caption2", points: 11, weight: "regular", alignment: "leading"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onOpen()
            } label: {
                Text(actionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Color(SemanticColorTokens.inkPrimary), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 112)
            .accessibilityHint(actionHint)
            .homeCardEvidence("focus.open", role: "control", copy: actionTitle, typography: .init(role: "subheadline", points: 15, weight: "semibold", alignment: "center"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 104)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero")
    }
}
