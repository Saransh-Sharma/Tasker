import SwiftUI

struct EvaChiefOfStaffGuideView: View {
    let onSelectPrompt: (EvaStarterPrompt) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    var sections: [EvaChiefOfStaffGuideSection] {
        EvaChiefOfStaffGuideContent.sections(for: assistantIdentity.snapshot)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                guideBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        hero

                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            sectionCard(section)
                                .enhancedStaggeredAppearance(index: index + 1)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.lg)
                }
            }
            .navigationTitle("\(assistantIdentity.snapshot.displayName) guide")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("eva.guide.close")
                }
            }
        }
        .accessibilityIdentifier("eva.guide.sheet")
    }

    var guideBackground: some View {
        ZStack {
            EvaChatSunriseBackground()

            LinearGradient(
                colors: [
                    ClayColorTokens.role(.assistant).softSurface.opacity(reduceTransparency ? 0.62 : 0.36),
                    ClayColorTokens.canvas.opacity(0.08),
                    ClayColorTokens.coolCanvas.opacity(0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    var hero: some View {
        GlassCard(
            cornerRadius: RadiusTokens.largeCard,
            borderColor: ClayColorTokens.role(.assistant).border.opacity(0.82),
            fill: reduceTransparency ? ClayColorTokens.glassStrong : ClayColorTokens.glassStrong.opacity(0.78),
            shadow: ShadowToken(color: ClayColorTokens.elevationShadow, radius: 24, x: 0, y: 12),
            usesMaterialBackground: !reduceTransparency
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    mascotWell

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(assistantIdentity.snapshot.displayName) as Chief of Staff")
                            .font(ClayTypography.sectionTitle)
                            .foregroundStyle(ClayColorTokens.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Plan, triage, and apply with confirmation.")
                            .font(ClayTypography.bodyStrong)
                            .foregroundStyle(ClayColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("Start with one of these prompts, or read the examples to learn when \(assistantIdentity.snapshot.displayName) is strongest.")
                    .font(ClayTypography.body)
                    .foregroundStyle(ClayColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.lg)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.lifeboard(.link, on: .card))
                .padding(Theme.Spacing.lg)
                .accessibilityHidden(true)
        }
        .enhancedStaggeredAppearance(index: 0)
    }

    var mascotWell: some View {
        ZStack {
            Circle()
                .fill(ClayColorTokens.role(.assistant).softSurface.opacity(0.86))
                .overlay {
                    Circle()
                        .stroke(ClayColorTokens.role(.assistant).border.opacity(0.84), lineWidth: 1)
                }

            Circle()
                .fill(ClayColorTokens.glassStrong.opacity(0.56))
                .frame(width: 42, height: 42)

            EvaMascotView(placement: .chiefOfStaffGuide, size: .custom(36))
                .frame(width: 40, height: 40)
        }
        .frame(width: 52, height: 52)
        .shadow(color: ClayColorTokens.elevationShadow.opacity(0.14), radius: 12, x: 0, y: 6)
        .accessibilityHidden(true)
    }

    func sectionCard(_ section: EvaChiefOfStaffGuideSection) -> some View {
        let assistantStyle = ClayColorTokens.role(.assistant)

        return GlassCard(
            cornerRadius: RadiusTokens.card,
            borderColor: assistantStyle.border.opacity(0.76),
            fill: reduceTransparency ? ClayColorTokens.glassStrong : assistantStyle.softSurface.opacity(0.54),
            shadow: ShadowToken(color: ClayColorTokens.elevationShadow, radius: 18, x: 0, y: 8),
            usesMaterialBackground: !reduceTransparency
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    sectionIconWell(section.icon, style: assistantStyle)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(section.title)
                            .font(ClayTypography.cardTitle)
                            .foregroundStyle(ClayColorTokens.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(section.body)
                            .font(ClayTypography.body)
                            .foregroundStyle(ClayColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FlowPromptChipsView(
                    prompts: section.prompts,
                    reduceMotion: reduceMotion,
                    onSelectPrompt: { prompt in
                        dismiss()
                        onSelectPrompt(prompt)
                    }
                )
            }
            .padding(Theme.Spacing.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.guide.section.\(section.id)")
    }

    func sectionIconWell(_ icon: String, style: RoleStyle) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(style.base)
            .frame(width: 44, height: 44)
            .background(style.softSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: RadiusTokens.iconWell, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RadiusTokens.iconWell, style: .continuous)
                    .stroke(style.border.opacity(0.86), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

}
