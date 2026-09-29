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
    /// True while the action is being carried out (a session starting); the
    /// button shows progress and ignores further taps.
    var isBusy: Bool = false
    /// Why the last action did not happen, said in place rather than by
    /// switching tabs.
    var failureMessage: String? = nil

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
                ZStack {
                    // The title keeps the capsule's width while progress shows.
                    Text(actionTitle)
                        .opacity(isBusy ? 0 : 1)
                    if isBusy {
                        ProgressView()
                            .tint(Color(SemanticColorTokens.foundationSurfaceSolid))
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Color(SemanticColorTokens.inkPrimary), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .frame(maxWidth: 112)
            .accessibilityHint(actionHint)
            .accessibilityValue(isBusy ? "Starting" : "")
            .homeCardEvidence("focus.open", role: "control", copy: actionTitle, typography: .init(role: "subheadline", points: 15, weight: "semibold", alignment: "center"))

            if let failureMessage {
                Label(failureMessage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foreground))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.hero.failure")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 104)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero")
    }
}
