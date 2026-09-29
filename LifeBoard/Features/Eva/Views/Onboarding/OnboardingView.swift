//
//  OnboardingView.swift
//
//

import SwiftUI

// MARK: - Feature Row Component

private struct EvaFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let index: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.lifeboard(.accentWash))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .lifeboardFont(.body)
                    .foregroundColor(Color.lifeboard(.accentPrimary))
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard(.textPrimary))
                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard(.textSecondary))
            }
        }
        .staggeredAppearance(index: index)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @StateObject private var assistantIdentity = AssistantIdentityModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeBoardMotionContext) private var motionContext

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("bolt.fill", String(localized: "Fast"), String(localized: "Built for Apple silicon")),
        ("checkmark.shield.fill", String(localized: "Offline"), String(localized: "Runs on your device")),
        ("lightbulb.fill", String(localized: "Suggestions"), String(localized: "Ideas for what to do next")),
        ("brain.head.profile", String(localized: "Your projects"), String(localized: "Adapts to what you’re working on")),
        ("battery.100.bolt", String(localized: "Battery-friendly"), String(localized: "Low power use")),
        ("list.bullet.rectangle.fill", String(localized: "Recaps"), String(localized: "Daily and weekly summaries"))
    ]

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                // Hero section
                VStack(spacing: Theme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.lifeboard(.accentWash))
                            .frame(width: 88, height: 88)
                        Circle()
                            .fill(Color.lifeboard(.accentMuted))
                            .frame(width: 72, height: 72)
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .lifeboardFont(.heroDisplay)
                            .foregroundColor(Color.lifeboard(.accentPrimary))
                            // Idle motion: off under Reduce Motion, Calm and energy pressure.
                            .symbolEffect(
                                .wiggle.byLayer,
                                options: .repeat(.continuous),
                                isActive: !reduceMotion
                                    && motionContext.allowsSpatialMotion
                                    && motionContext.comfortProfile != .calm
                            )
                    }

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Meet \(assistantIdentity.snapshot.displayName)")
                            .font(.lifeboard(.display))
                            .foregroundColor(Color.lifeboard(.textPrimary))
                        Text("Plans your day with you.")
                            .font(.lifeboard(.callout))
                            .fontWeight(.semibold)
                            .foregroundColor(Color.lifeboard(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Feature list
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(Array(features.enumerated()), id: \.element.title) { index, feature in
                        EvaFeatureRow(
                            icon: feature.icon,
                            title: feature.title,
                            subtitle: feature.subtitle,
                            index: index
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xxl)

                Spacer()

                // CTA button
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("Get started")
                        #if os(iOS) || os(visionOS)
                        .font(.lifeboard(.button))
                        .foregroundColor(Color.lifeboard(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.lifeboard(.accentPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill, style: .continuous))
                        #endif
                }
                #if os(macOS)
                .buttonStyle(.lifeBoardPrimaryCompact)
                #endif
                .scaleOnPress()
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding()
            .background(Color.lifeboard(.bgCanvas))
            .navigationTitle("Welcome")
            .toolbar(.hidden)
        }
        .tint(Color.lifeboard(.accentPrimary))
        #if os(macOS)
        .frame(width: 420, height: 520)
        #endif
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
