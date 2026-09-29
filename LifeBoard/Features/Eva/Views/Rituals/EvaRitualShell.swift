import SwiftUI

struct EvaRitualShell<Content: View, Footer: View>: View {
    let title: String
    let orientation: String
    let evidence: [Insight.Evidence]
    var onOpenEvidence: ((EvaRecordReference) -> Void)? = nil
    let onClose: () -> Void
    /// False when the ritual is *pushed* onto an existing stack. A pushed
    /// destination that brings its own `NavigationStack` is unsupported:
    /// SwiftUI renders a blank page with a yellow warning triangle, which is
    /// what Weekly Review showed from its notification and deep link.
    var embedsInNavigationStack = true
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OptionalNavigationStack(isEnabled: embedsInNavigationStack) {
            ZStack(alignment: .top) {
                ScenicBackdrop(
                    scene: .secondary,
                    daypart: preferences.resolvedDaypart(),
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                .frame(height: 260)
                .clipped()
                .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            // No eyebrow: the navigation title already says
                            // what this is.
                            Text(orientation)
                                .lifeboardFont(.title3)
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foundationClayCard()

                        content()

                        if evidence.isEmpty == false {
                            EvaRitualEvidenceDisclosure(
                                evidence: evidence,
                                onOpenEvidence: onOpenEvidence
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    // The footer is a safe-area inset already; this only
                    // keeps the last card off it.
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Pushed, the stack's Back already leaves; a second Close
                // beside it was redundant and read as a faint grey pill.
                if embedsInNavigationStack {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                            .frame(minWidth: 44, minHeight: 44)
                            .keyboardShortcut(.cancelAction)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(SemanticColorTokens.foundationSurfaceRaised))
            }
        }
        .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: orientation)
    }
}

struct EvaRitualEvidenceDisclosure: View {
    let evidence: [Insight.Evidence]
    var onOpenEvidence: ((EvaRecordReference) -> Void)?
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(spacing: 12) {
                ForEach(evidence) { item in
                    if let onOpenEvidence {
                        Button {
                            onOpenEvidence(item.reference)
                        } label: {
                            evidenceRow(item, showsLink: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens details")
                    } else {
                        evidenceRow(item, showsLink: false)
                            .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Label("Details", systemImage: "sparkle.magnifyingglass")
                .lifeboardFont(.headline)
        }
        .foundationClayCard()
        .accessibilityIdentifier("eva.ritual.evidence")
    }

    private func evidenceRow(_ item: Insight.Evidence, showsLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: showsLink ? "link" : "doc.text.magnifyingglass")
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.reason)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text(item.reference.title)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
        }
    }
}

struct EvaRitualSection<Content: View>: View {
    let eyebrow: String
    let title: String
    let message: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sentence case: `DESIGN.md` bars uppercase for hierarchy.
            Text(eyebrow)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Text(title)
                .lifeboardFont(.title3)
            if let message {
                Text(message)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            content()
        }
        .foundationClayCard()
    }
}

/// A `NavigationStack` only when the view is the root of its own presentation
/// (a sheet or cover). Pushed destinations must not nest one.
struct OptionalNavigationStack<Content: View>: View {
    let isEnabled: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isEnabled {
            NavigationStack { content() }
        } else {
            content()
        }
    }
}
