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
        HStack(spacing: LifeBoardTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.lifeboard(.accentWash))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.lifeboard(.accentPrimary))
            }

            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
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

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("bolt.fill", "fast", "optimized for apple silicon"),
        ("checkmark.shield.fill", "offline", "runs locally on your device"),
        ("lightbulb.fill", "insightful", "smart productivity suggestions"),
        ("brain.head.profile", "context-aware", "adapts to your current projects"),
        ("battery.100.bolt", "battery-light", "tiny power footprint"),
        ("list.bullet.rectangle.fill", "smart recap", "daily / weekly digests")
    ]

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                // Hero section
                VStack(spacing: LifeBoardTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.lifeboard(.accentWash))
                            .frame(width: 88, height: 88)
                        Circle()
                            .fill(Color.lifeboard(.accentMuted))
                            .frame(width: 72, height: 72)
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(Color.lifeboard(.accentPrimary))
                            .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
                    }

                    VStack(spacing: LifeBoardTheme.Spacing.xs) {
                        Text("I am \(assistantIdentity.snapshot.displayName)")
                            .font(.lifeboard(.display))
                            .foregroundColor(Color.lifeboard(.textPrimary))
                        Text("your personal AI assistant")
                            .font(.lifeboard(.callout))
                            .fontWeight(.semibold)
                            .foregroundColor(Color.lifeboard(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Feature list
                VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xl) {
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
                .padding(.horizontal, LifeBoardTheme.Spacing.xxl)

                Spacer()

                // CTA button
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("get started")
                        #if os(iOS) || os(visionOS)
                        .font(.lifeboard(.button))
                        .foregroundColor(Color.lifeboard(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.lifeboard(.accentPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.pill, style: .continuous))
                        #endif
                }
                #if os(macOS)
                .buttonStyle(.borderedProminent)
                #endif
                .scaleOnPress()
                .padding(.horizontal, LifeBoardTheme.Spacing.xl)
            }
            .padding()
            .background(Color.lifeboard(.bgCanvas))
            .navigationTitle("welcome")
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
