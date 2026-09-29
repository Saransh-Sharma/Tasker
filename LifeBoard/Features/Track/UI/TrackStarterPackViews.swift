import SwiftUI
import UIKit

struct StarterPackBrowser: View {
    let install: (StarterPackPreview) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPack: StarterPack?
    @State private var preview: StarterPackPreview?
    var body: some View {
        ComposerScaffold(
            title: String(localized: "Starter packs"),
            cancelTitle: String(localized: "Close"),
            identifier: "track.starterPacks"
        ) {
            StarterPackListSection { pack in
                selectedPack = pack
                preview = StarterPackCatalog.preview(pack)
            }
        } commit: {
            EmptyView()
        }
        .sheet(item: $selectedPack) { _ in
            if let preview { StarterPackPreviewSheet(preview: preview) { install($0); dismiss() } }
        }
    }
}


private struct StarterPackListSection: View {
    let open: (StarterPack) -> Void

    var body: some View {
        ComposerSection(
            footer: "Nothing is added until you confirm."
        ) {
            ForEach(StarterPack.allCases, id: \.self) { pack in
                StarterPackRow(title: StarterPackCopy.title(pack)) { open(pack) }
            }
        }
    }
}

private struct StarterPackSelectionSection: View {
    @Binding var preview: StarterPackPreview

    var body: some View {
        ComposerSection(
            "Included",
            footer: "Edit them anytime after adding."
        ) {
            ForEach($preview.items) { $item in
                Toggle(isOn: $item.isSelected) {
                    Label(item.title, systemImage: StarterPackCopy.symbol(item.kind))
                }
                .toggleStyle(.lifeBoardClay)
            }
        }
    }
}

/// Shared so the browser, the preview sheet and Track's installed row cannot
/// drift on naming. Display names only: the `StarterPack` raw values are keys.
enum StarterPackCopy {
    static func title(_ pack: StarterPack) -> String {
        switch pack {
        case .morningFoundation: String(localized: "Morning basics")
        case .workdayReset: String(localized: "Workday reset")
        case .lowEnergyRecovery: String(localized: "Low-energy days")
        case .medicationSupport: String(localized: "Medication support")
        case .eveningWindDown: String(localized: "Evening wind-down")
        }
    }

    static func symbol(_ kind: StarterPackItemKind) -> String {
        switch kind {
        case .goal: "target"
        case .habit: "repeat.circle"
        case .routine: "figure.mind.and.body"
        case .reminder: "bell"
        }
    }
}

private struct StarterPackRow: View {
    let title: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.card))
        .accessibilityIdentifier("track.starterPacks.\(title)")
    }
}

private struct StarterPackPreviewSheet: View {
    @State var preview: StarterPackPreview
    let install: (StarterPackPreview) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ComposerScaffold(
            title: String(localized: "Preview pack"),
            confirmTitle: String(localized: "Add selected"),
            isConfirmEnabled: preview.items.contains(where: \.isSelected),
            identifier: "track.starterPacks.preview",
            onConfirm: { install(preview); dismiss() }
        ) {
            StarterPackSelectionSection(preview: $preview)
        }
    }
}
