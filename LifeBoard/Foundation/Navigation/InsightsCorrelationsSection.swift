import SwiftUI
import LifeBoardUI

/// Up to three on-device relationships under Overview. Each row names its
/// sources and how many days it rests on, and offers one small, reversible
/// thing to try for a week. The copy is descriptive; it never says "because".
struct InsightsCorrelationsSection: View {
    let results: [DailyCorrelationEngine.Result]
    let openExperiments: [InsightExperiment]
    let startExperiment: (DailyCorrelationEngine.Result, HabitTemplate) async -> Bool
    /// Days with any recorded series, for the "not yet" line.
    var recordedDays: Int = 0

    @State private var starting: String?

    var body: some View {
        if results.isEmpty, let progress = DailyCorrelationEngine.progressLine(recordedDays: recordedDays), recordedDays > 0 {
            // A quiet line rather than nothing: the section used to vanish
            // until ten days existed, with no hint it was coming.
            Label(progress, systemImage: "point.3.connected.trianglepath.dotted")
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("insights.correlations.progress")
        } else if results.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Noticed together", symbol: "point.3.connected.trianglepath.dotted")
                Text("From your last \(InsightsRange.month.days) days. On \(DeviceNoun.this).")
                    .lifeboardFont(.meta)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(results) { result in
                    row(for: result)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("insights.correlations")
        }
    }

    private func row(for result: DailyCorrelationEngine.Result) -> some View {
        let templateID = InsightExperimentSuggestion.templateID(for: result)
        let template = templateID.flatMap(HabitTemplateCatalog.template(id:))
        let alreadyRunning = openExperiments.contains { $0.sourceCorrelationID == result.id }
        return VStack(alignment: .leading, spacing: 8) {
            Text(DailyCorrelationEngine.sentence(for: result))
                .lifeboardFont(.body)
                .fixedSize(horizontal: false, vertical: true)
            Text(DailyCorrelationEngine.evidence(for: result))
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            HStack(spacing: 8) {
                Label(result.first.label, systemImage: result.first.systemImage)
                Label(result.second.label, systemImage: result.second.systemImage)
            }
            .lifeboardFont(.meta)
            .foregroundStyle(Color.lifeboard(.textSecondary))
            if let template {
                if alreadyRunning {
                    Label("Trying \(template.title) this week", systemImage: "checkmark.circle")
                        .lifeboardFont(.meta)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                } else {
                    Button {
                        guard starting == nil else { return }
                        starting = result.id
                        Task {
                            _ = await startExperiment(result, template)
                            starting = nil
                        }
                    } label: {
                        Label(starting == result.id ? "Starting…" : "Try \(template.title) for a week", systemImage: "sparkles")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.lifeBoardChip)
                    .disabled(starting != nil)
                    .accessibilityIdentifier("insights.correlations.try.\(result.id)")
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.correlations.\(result.id)")
    }
}
