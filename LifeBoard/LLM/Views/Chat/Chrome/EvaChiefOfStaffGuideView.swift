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
                    VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.lg) {
                        hero

                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            sectionCard(section)
                                .enhancedStaggeredAppearance(index: index + 1)
                        }
                    }
                    .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                    .padding(.vertical, LifeBoardTheme.Spacing.lg)
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
                    LBColorTokens.role(.assistant).softSurface.opacity(reduceTransparency ? 0.62 : 0.36),
                    LBColorTokens.canvas.opacity(0.08),
                    LBColorTokens.coolCanvas.opacity(0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    var hero: some View {
        LBGlassCard(
            cornerRadius: LBRadiusTokens.largeCard,
            borderColor: LBColorTokens.role(.assistant).border.opacity(0.82),
            fill: reduceTransparency ? LBColorTokens.glassStrong : LBColorTokens.glassStrong.opacity(0.78),
            shadow: LBShadowToken(color: LBColorTokens.elevationShadow, radius: 24, x: 0, y: 12),
            usesMaterialBackground: !reduceTransparency
        ) {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
                HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.md) {
                    mascotWell

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(assistantIdentity.snapshot.displayName) as Chief of Staff")
                            .font(LBTypographyTokens.sectionTitle)
                            .foregroundStyle(LBColorTokens.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Plan, triage, and apply with confirmation.")
                            .font(LBTypographyTokens.bodyStrong)
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("Start with one of these prompts, or read the examples to learn when \(assistantIdentity.snapshot.displayName) is strongest.")
                    .font(LBTypographyTokens.body)
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LifeBoardTheme.Spacing.lg)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.lifeboard(.link, on: .card))
                .padding(LifeBoardTheme.Spacing.lg)
                .accessibilityHidden(true)
        }
        .enhancedStaggeredAppearance(index: 0)
    }

    var mascotWell: some View {
        ZStack {
            Circle()
                .fill(LBColorTokens.role(.assistant).softSurface.opacity(0.86))
                .overlay {
                    Circle()
                        .stroke(LBColorTokens.role(.assistant).border.opacity(0.84), lineWidth: 1)
                }

            Circle()
                .fill(LBColorTokens.glassStrong.opacity(0.56))
                .frame(width: 42, height: 42)

            EvaMascotView(placement: .chiefOfStaffGuide, size: .custom(36))
                .frame(width: 40, height: 40)
        }
        .frame(width: 52, height: 52)
        .shadow(color: LBColorTokens.elevationShadow.opacity(0.14), radius: 12, x: 0, y: 6)
        .accessibilityHidden(true)
    }

    func sectionCard(_ section: EvaChiefOfStaffGuideSection) -> some View {
        let assistantStyle = LBColorTokens.role(.assistant)

        return LBGlassCard(
            cornerRadius: LBRadiusTokens.card,
            borderColor: assistantStyle.border.opacity(0.76),
            fill: reduceTransparency ? LBColorTokens.glassStrong : assistantStyle.softSurface.opacity(0.54),
            shadow: LBShadowToken(color: LBColorTokens.elevationShadow, radius: 18, x: 0, y: 8),
            usesMaterialBackground: !reduceTransparency
        ) {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
                HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.md) {
                    sectionIconWell(section.icon, style: assistantStyle)

                    VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                        Text(section.title)
                            .font(LBTypographyTokens.cardTitle)
                            .foregroundStyle(LBColorTokens.navy)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(section.body)
                            .font(LBTypographyTokens.body)
                            .foregroundStyle(LBColorTokens.navyMuted)
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
            .padding(LifeBoardTheme.Spacing.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.guide.section.\(section.id)")
    }

    func sectionIconWell(_ icon: String, style: LBRoleStyle) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(style.base)
            .frame(width: 44, height: 44)
            .background(style.softSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: LBRadiusTokens.iconWell, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LBRadiusTokens.iconWell, style: .continuous)
                    .stroke(style.border.opacity(0.86), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

}
