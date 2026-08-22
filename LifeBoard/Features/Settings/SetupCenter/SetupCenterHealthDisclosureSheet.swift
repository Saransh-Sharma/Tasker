import SwiftUI

/// What LifeBoard is about to ask Apple Health for.
///
/// Was `NavigationStack { List { Section … } }` with a toolbar confirm — the
/// exact incantation `ComposerScaffold` exists to replace, and the only fully
/// system-chromed surface left in Setup Center.
///
/// It uses the toolbar-confirm variant rather than a commit bar because there is
/// no persistence phase to report: confirming hands off to Apple's own
/// permission sheet, and morphing a button through "Saving → Saved" for a
/// request whose outcome Apple never discloses would be a lie.
struct SetupCenterHealthDisclosureSheet: View {
    let readState: HealthReadAccessState
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ComposerScaffold(
            // "Apple Health access" truncates to "Apple Health acc…" between
            // the two toolbar buttons at an inline title.
            title: "Health access",
            subtitle: "LifeBoard reports what it asked for, never what Apple refused.",
            confirmTitle: readState == .notRequested ? "Continue" : "Request again",
            titleDisplayMode: .inline,
            detents: [.medium, .large],
            identifier: "setupCenter.health.disclosure",
            onCancel: onCancel,
            onConfirm: onConfirm
        ) {
            SetupCenterHealthReadSection()
            SetupCenterHealthWriteSection()
            SetupCenterHealthTruthSection()
        }
    }
}

private struct SetupCenterHealthReadSection: View {
    var body: some View {
        ComposerSection("LifeBoard will request read access") {
            ForEach(HealthDomain.allCases.filter { $0.metrics.isEmpty == false }) { domain in
                Label(domain.title, systemImage: domain.symbolName)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
            }
        }
    }
}

private struct SetupCenterHealthWriteSection: View {
    var body: some View {
        ComposerSection("LifeBoard will request write access") {
            ForEach(HealthDomain.allCases.filter(\.supportsWriteBack)) { domain in
                Label(domain.title, systemImage: domain.symbolName)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
            }
        }
    }
}

/// Prose stays on the canvas rather than becoming another slab row — the split
/// `ComposerSection` exists to express and `Form` cannot.
private struct SetupCenterHealthTruthSection: View {
    var body: some View {
        ComposerSection(
            footer: "Apple does not reveal whether read access was denied. After the sheet, LifeBoard reports that access was requested and only reports readable data when data is actually observed."
        ) {
            EmptyView()
        }
    }
}
