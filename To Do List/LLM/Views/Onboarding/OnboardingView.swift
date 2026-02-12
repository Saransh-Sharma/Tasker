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
        HStack(spacing: TaskerTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.tasker(.accentWash))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.tasker(.accentPrimary))
            }

            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                Text(title)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker(.textPrimary))
                Text(subtitle)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textSecondary))
            }
        }
        .staggeredAppearance(index: index)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var showOnboarding: Bool

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
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.tasker(.accentWash))
                            .frame(width: 88, height: 88)
                        Circle()
                            .fill(Color.tasker(.accentMuted))
                            .frame(width: 72, height: 72)
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(Color.tasker(.accentPrimary))
                            .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
                    }

                    VStack(spacing: TaskerTheme.Spacing.xs) {
                        Text("I am Eva !")
                            .font(.tasker(.display))
                            .foregroundColor(Color.tasker(.textPrimary))
                        Text("your personal AI assistant")
                            .font(.tasker(.callout))
                            .fontWeight(.semibold)
                            .foregroundColor(Color.tasker(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Feature list
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xl) {
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
                .padding(.horizontal, TaskerTheme.Spacing.xxl)

                Spacer()

                // CTA button
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("get started")
                        #if os(iOS) || os(visionOS)
                        .font(.tasker(.button))
                        .foregroundColor(Color.tasker(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.tasker(.accentPrimary))
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                        #endif
                }
                #if os(macOS)
                .buttonStyle(.borderedProminent)
                #endif
                .scaleOnPress()
                .padding(.horizontal, TaskerTheme.Spacing.xl)
            }
            .padding()
            .background(Color.tasker(.bgCanvas))
            .navigationTitle("welcome")
            .toolbar(.hidden)
        }
        .tint(Color.tasker(.accentPrimary))
        #if os(macOS)
        .frame(width: 420, height: 520)
        #endif
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
