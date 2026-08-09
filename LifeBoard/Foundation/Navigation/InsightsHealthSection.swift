import SwiftUI
import UIKit

/// Today's body context, sourced entirely from the Health connection store.
struct InsightsHealthSection: View {
    let healthStore: HealthConnectionStore
    let router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Body rhythm")
                        .font(.title2.weight(.semibold))
                    Text(interpretation)
                        .font(.subheadline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Image(systemName: "heart.text.clipboard")
                    .font(.title2)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            }

            if healthStore.aggregates.isEmpty {
                Text(HealthAuthorizationPromptState.hasRequested
                    ? "No current Health records are available yet."
                    : "Connect Apple Health in Track to bring movement and body context here.")
                    .font(.body)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                Button {
                    router.push(.healthInsight(.activity), in: .insights)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(metricText(.steps))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text("steps today")
                            .font(.subheadline)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    fact(.energy, metric: .activeEnergy, label: "Active")
                    fact(.hydration, metric: .water, label: "Hydration")
                    fact(.body, metric: .restingHeartRate, label: "Resting HR")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 22)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.healthOverview")
    }

    private func fact(_ domain: HealthInsightDomain, metric: HealthMetric, label: String) -> some View {
        Button {
            router.push(.healthInsight(domain), in: .insights)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(metricText(metric))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .lifeBoardClaySurface(.well, cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private var interpretation: String {
        guard let steps = healthStore.aggregates[.steps] else {
            return "Health context stays factual until there is enough evidence."
        }
        if steps.value == 0 && steps.lastSampleAt == nil {
            return "No movement record has arrived for today."
        }
        return "Today’s movement is available with its Apple Health source."
    }

    private func metricText(_ metric: HealthMetric) -> String {
        guard let value = healthStore.aggregates[metric]?.value else { return "—" }
        switch metric {
        case .steps: return value.formatted(.number.precision(.fractionLength(0)))
        case .water: return "\(Int(value)) mL"
        case .walkingRunningDistance: return "\((value / 1_000).formatted(.number.precision(.fractionLength(1)))) km"
        case .restingHeartRate: return "\(Int(value)) bpm"
        case .activeEnergy, .restingEnergy, .dietaryEnergy: return "\(Int(value)) kcal"
        default: return value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }}
