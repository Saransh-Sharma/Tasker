import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct HealthInsightDetailView: View {
    let domain: HealthInsightDomain
    let wellnessRepository: any WellnessRepository

    @State private var range: HealthHistoryRange = .thirtyDays
    @State private var history: [HealthMetric: [HealthAggregateValue]] = [:]
    @State private var bodySamples: [BodyMetricSample] = []
    @State private var workouts: [WorkoutRecord] = []
    @State private var sleepNotes: [SleepNote] = []
    @State private var isLoading = false
    @State private var errorCode: String?
    @State private var loadedRange: HealthHistoryRange?

    private var primaryMetric: HealthMetric? {
        switch domain {
        case .activity: .steps
        case .energy: .activeEnergy
        case .hydration: .water
        case .nutrition: .dietaryEnergy
        case .body: .bodyMass
        case .workouts, .sleep: nil
        }
    }

    private var chartPoints: [HomeSeriesPoint] {
        if let primaryMetric {
            return (history[primaryMetric] ?? []).map { .init(date: $0.start, value: $0.value) }
        }
        switch domain {
        case .workouts:
            return workouts.map { .init(date: $0.startedAt, value: max(0, $0.duration / 60)) }.sorted { $0.date < $1.date }
        case .sleep:
            return HealthSleepPresentation.nightlySummaries(notes: sleepNotes)
                .map { .init(date: $0.night, value: max(0, $0.totalDuration / 3_600)) }
                .sorted { $0.date < $1.date }
        default:
            return []
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                interpretation

                LensPicker(
                    "History range",
                    selection: $range,
                    values: HealthHistoryRange.allCases,
                    identifierPrefix: "health.insight.range",
                    title: \.title,
                    identifier: \.rawValue
                )

                if isLoading && chartPoints.isEmpty {
                    ProgressView("Reading Apple Health history…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if chartPoints.count > 1 {
                    let chart = TrendChart(
                        points: chartPoints,
                        tint: Color(SemanticColorTokens.foundationSageAccent),
                        unit: chartUnit
                    )
                    // `TrendChart` runs its own reveal sweep internally. The
                    // second one that used to sit here composited over the
                    // first, so this chart alone swept at double strength.
                    chart
                        .frame(height: 170)
                    Text(chart.textEquivalent)
                        .lifeboardFont(.meta)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                } else {
                    ContentUnavailableView(
                        "Not enough history yet",
                        systemImage: domain.symbolName,
                        description: Text("A trend appears after at least two recorded days. Missing evidence is not treated as zero.")
                    )
                }

                evidence
            }
            .frame(maxWidth: 680)
            .padding(20)
        }
        .background { GrainedCanvas() }
        .navigationTitle(domain.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: range) { await load() }
        .refreshable { await load(force: true) }
        .task {
            let updates = await HealthSyncInvalidationService.shared.updates()
            for await event in updates where event.metrics.isDisjoint(with: Set(domain.metrics)) == false {
                await load(force: false)
            }
        }
    }

    private var interpretation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(interpretationTitle, systemImage: domain.symbolName)
                .lifeboardFont(.title1)
            Text(interpretationDetail)
                .lifeboardFont(.body)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            if let errorCode {
                Label("Some history could not be refreshed. Cached evidence remains below. (\(errorCode))", systemImage: "exclamationmark.triangle")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }

    private var interpretationTitle: String {
        guard let latest = chartPoints.last else { return "No recorded pattern yet" }
        return "Latest: \(format(latest.value, metric: primaryMetric))"
    }

    private var interpretationDetail: String {
        guard chartPoints.count > 1 else {
            return "LifeBoard will describe change once there is enough evidence, without grading or diagnosing it."
        }
        return "This view shows recorded change over \(range.title), with Apple Health provenance preserved below."
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Evidence")
                .padding(.bottom, 8)
            ForEach(dailyEvidence.prefix(240)) { value in
                evidenceRow(
                    title: metricTitle(value.metric),
                    value: format(value.value, metric: value.metric),
                    date: value.start,
                    source: value.sourceLabel
                )
            }
            if domain == .body {
                ForEach(bodySamples.prefix(240)) { sample in
                    evidenceRow(
                        title: sample.kind.title,
                        value: bodyValue(sample),
                        date: sample.observedAt,
                        source: sample.source == .healthKit ? "Apple Health" : "LifeBoard"
                    )
                }
            }
            if domain == .workouts {
                ForEach(workouts.prefix(240)) { workout in
                    evidenceRow(
                        title: workout.activityKind,
                        value: "\(Int(workout.duration / 60)) min",
                        date: workout.startedAt,
                        source: workout.source == .healthKit ? "Apple Health" : "LifeBoard"
                    )
                }
            }
            if domain == .sleep {
                ForEach(sleepNotes.prefix(240)) { note in
                    evidenceRow(
                        title: "Sleep interval",
                        value: Self.duration(note.duration),
                        date: note.startedAt,
                        source: note.source == .healthKit ? "Apple Health" : "LifeBoard"
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(domain.title) evidence table")
    }

    private var dailyEvidence: [HealthAggregateValue] {
        history.values.flatMap { $0 }.sorted { $0.start > $1.start }
    }

    private func evidenceRow(title: String, value: String, date: Date, source: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text("\(source) · \(date.formatted(date: .abbreviated, time: .shortened))")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Text(value).monospacedDigit()
        }
        .frame(minHeight: 52)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func load(force: Bool = false) async {
        isLoading = true
        let coordinator = HealthCoordinator.shared.coordinator
        if force || loadedRange != range {
            let result = await coordinator.sync(.historyBackfill(Set(domain.metrics), range))
            errorCode = result.failures.isEmpty ? nil : "history_partial"
            loadedRange = range
        }
        history = await coordinator.cachedHistory(domain: domain, range: range)
        do {
            switch domain {
            case .body: bodySamples = try await wellnessRepository.bodyMetricSamples(kind: nil)
            case .workouts: workouts = try await wellnessRepository.workoutRecords()
            case .sleep: sleepNotes = try await wellnessRepository.sleepNotes()
            default: break
            }
        } catch {
            errorCode = "local_history"
        }
        isLoading = false
    }

    private var chartUnit: String {
        switch domain {
        case .activity: "steps"
        case .energy, .nutrition: "kcal"
        case .hydration: "mL"
        case .body: "kg"
        case .workouts: "minutes"
        case .sleep: "hours"
        }
    }

    private func metricTitle(_ metric: HealthMetric) -> String {
        switch metric {
        case .steps: "Steps"
        case .walkingRunningDistance: "Walking distance"
        case .activeEnergy: "Active energy"
        case .restingEnergy: "Resting energy"
        case .water: "Hydration"
        case .dietaryEnergy: "Dietary energy"
        case .dietaryProtein: "Protein"
        case .dietaryCarbohydrates: "Carbohydrates"
        case .dietaryFat: "Fat"
        case .bodyMass: "Weight"
        case .bodyFatPercentage: "Body fat"
        case .waistCircumference: "Waist"
        case .restingHeartRate: "Resting heart rate"
        case .workout: "Workout"
        case .sleep: "Sleep"
        }
    }

    private func format(_ value: Double, metric: HealthMetric?) -> String {
        guard let metric else { return value.formatted(.number.precision(.fractionLength(0...1))) }
        switch metric {
        case .steps: return value.formatted(.number.precision(.fractionLength(0)))
        case .walkingRunningDistance: return "\((value / 1_000).formatted(.number.precision(.fractionLength(1)))) km"
        case .water: return "\(Int(value)) mL"
        case .bodyMass: return "\(value.formatted(.number.precision(.fractionLength(1)))) kg"
        case .bodyFatPercentage: return "\(value.formatted(.number.precision(.fractionLength(1))))%"
        case .waistCircumference: return "\(value.formatted(.number.precision(.fractionLength(1)))) cm"
        case .restingHeartRate: return "\(Int(value)) bpm"
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat: return "\(Int(value)) g"
        case .activeEnergy, .restingEnergy, .dietaryEnergy: return "\(Int(value)) kcal"
        case .workout, .sleep: return value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    private func bodyValue(_ sample: BodyMetricSample) -> String {
        let value = (try? sample.value(in: sample.displayUnit)) ?? sample.normalizedValue
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(sample.displayUnit.symbol)"
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int(interval / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
