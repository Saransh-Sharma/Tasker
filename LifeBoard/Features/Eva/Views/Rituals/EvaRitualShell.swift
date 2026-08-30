import SwiftUI

struct EvaRitualShell<Content: View, Footer: View>: View {
    let title: String
    let orientation: String
    let evidence: [Insight.Evidence]
    var onOpenEvidence: ((EvaRecordReference) -> Void)? = nil
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
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
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("EVA DECISION RITUAL")
                                .font(.caption.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            Text(orientation)
                                .font(.title3.weight(.semibold))
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
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(SemanticColorTokens.foundationSurfaceRaised))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: orientation)
    }
}

struct EvaRitualEvidenceDisclosure: View {
    let evidence: [Insight.Evidence]
    var onOpenEvidence: ((EvaRecordReference) -> Void)?
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(spacing: 10) {
                ForEach(evidence) { item in
                    if let onOpenEvidence {
                        Button {
                            onOpenEvidence(item.reference)
                        } label: {
                            evidenceRow(item, showsLink: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the referenced record")
                    } else {
                        evidenceRow(item, showsLink: false)
                            .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Label("Evidence behind this ritual", systemImage: "sparkle.magnifyingglass")
                .font(.headline)
        }
        .foundationClayCard()
        .accessibilityIdentifier("eva.ritual.evidence")
    }

    private func evidenceRow(_ item: Insight.Evidence, showsLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: showsLink ? "link" : "doc.text.magnifyingglass")
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.reason)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text(item.reference.title)
                    .font(.caption)
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
        VStack(alignment: .leading, spacing: 13) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Text(title)
                .font(.title3.weight(.semibold))
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            content()
        }
        .foundationClayCard()
    }
}
