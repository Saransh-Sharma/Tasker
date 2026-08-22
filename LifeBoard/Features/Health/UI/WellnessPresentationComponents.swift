import Charts
import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// Wellness and Nutrition presentation components, extracted from
// `LifeBoardPhaseVIViews.swift`.
//
// That file carries the whole Health feature tree and sits on the file-size
// ratchet. The three metrics the ratchet tracks are lines, top-level type count
// and largest-type span, and the last of those is the one that predicts the
// `-Onone` launch crash — so pulling independent components into a sibling file
// is the sanctioned way to make room, not an accounting trick.
//
// Everything here is a self-contained view over values passed in. Nothing
// reaches back into `WellnessView`'s state.

struct NutritionTodayHero: View {
    let calories: Double?
    let targetCalories: Double?
    let isPartial: Bool
    let source: NutritionSummarySource
    let onLogMeal: () -> Void

    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            MetricHero(
                label: "Energy today",
                reading: reading,
                provenance: provenanceLabel,
                timeframe: targetLabel,
                accessibilityID: "nutrition.hero.energy"
            )

            Button {
                onLogMeal()
            } label: {
                Label("Log a meal", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.lifeBoardPrimary)
            .accessibilityIdentifier("nutrition.hero.log")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(palette: palette)
        .accessibilityElement(children: .contain)
    }

    /// Absent totals are `noRecord`, never `0`. Nothing logged and a genuine
    /// zero-calorie day are different facts, and the previous presentation
    /// rendered both as an em dash.
    private var reading: MetricReading {
        guard let calories else { return .noRecord }
        return calories == 0
            ? .explicitZero(unit: "kcal")
            : .recorded(value: Int(calories.rounded()).formatted(), unit: "kcal")
    }

    private var provenanceLabel: String {
        let origin = source == .appleHealth ? "Apple Health" : "LifeBoard meals"
        return isPartial ? "\(origin) · some nutrients unavailable" : origin
    }

    private var targetLabel: String? {
        guard let targetCalories, targetCalories > 0, let calories else { return nil }
        let remaining = Int((targetCalories - calories).rounded())
        if remaining > 0 { return "\(remaining) kcal below today's target" }
        if remaining < 0 { return "\(abs(remaining)) kcal above today's target" }
        return "At today's target"
    }
}

struct WellnessHero: View {
    let label: String
    let reading: MetricReading
    let provenance: String?
    let timeframe: String?
    let actionTitle: String
    let action: () -> Void

    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            MetricHero(
                label: label,
                reading: reading,
                provenance: provenance,
                timeframe: timeframe,
                accessibilityID: "wellness.hero.metric"
            )

            Button(action: action) {
                Label(actionTitle, systemImage: "plus.circle.fill")
            }
            .buttonStyle(.lifeBoardPrimary)
            .accessibilityIdentifier("wellness.hero.action")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(palette: palette)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

struct WellnessMetricOrderRow: View {
    let kind: BodyMetricKind
    @Binding var unit: WellnessDisplayUnit
    let hide: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(kind.title)
                .font(.lifeboard(.body))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Spacer(minLength: 8)
            Menu {
                Picker(kind.title, selection: $unit) {
                    ForEach(WellnessDisplayPreferences.units(for: kind), id: \.self) { option in
                        Text(option.symbol).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(unit.symbol)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            }
            .accessibilityLabel(Text("\(kind.title) unit"))
            Button(action: hide) {
                Image(systemName: "eye.slash")
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .frame(width: 34, height: 34)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Hide \(kind.title)"))
        }
    }
}

struct WellnessHistoryRow: View {
    let timestamp: Date
    let value: String
    let provenance: String
    let isImported: Bool
    let note: String?
    let edit: (() -> Void)?
    let delete: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                HStack(spacing: 6) {
                    if isImported {
                        Text(provenance)
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                    }
                    if let note {
                        Text(note)
                            .font(.lifeboard(.caption2))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .lineLimit(2)
                    }
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.lifeboard(.bodyStrong))
                .monospacedDigit()
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            if edit != nil || delete != nil {
                Menu {
                    if let edit {
                        Button("Edit", systemImage: "pencil", action: edit)
                    }
                    if let delete {
                        Button("Delete", systemImage: "trash", role: .destructive, action: delete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                        .frame(width: 44, height: 44)
                        .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                }
                .accessibilityLabel(Text("Actions for \(value) on \(timestamp.formatted(date: .abbreviated, time: .shortened))"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .lifeBoardClaySurface(.resting)
        .lifeBoardScrollEntrance(intensity: 0.55)
        .accessibilityElement(children: .contain)
    }
}

struct WellnessCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WellnessDisplayPreferences
    let save: (WellnessDisplayPreferences) -> Void

    init(
        preferences: WellnessDisplayPreferences,
        save: @escaping (WellnessDisplayPreferences) -> Void
    ) {
        _draft = State(initialValue: preferences)
        self.save = save
    }

    var body: some View {
        ComposerScaffold(
            title: "Customize Wellness",
            subtitle: "Which metrics appear, in which order.",
            confirmTitle: "Save",
            isConfirmEnabled: draft.enabledMetrics.isEmpty == false,
            titleDisplayMode: .inline,
            identifier: "wellness.customize",
            onConfirm: { save(draft); dismiss() }
        ) {
            ComposerSection(
                "Body dashboard",
                detail: "Drag to reorder, or use the Move up and Move down actions.",
                footer: "Enabled metrics keep their order. Source readings and history are never deleted when a metric is hidden."
            ) {
                // `ReorderableRows` rather than `List` + `EditButton`.
                // Dropping edit mode would have removed the only Switch Control
                // path to reordering, so the per-row Move actions the component
                // requires are what make this substitution legitimate.
                ReorderableRows(
                    items: $draft.enabledMetrics,
                    rowIdentifier: { "wellness.customize.\($0.rawValue)" },
                    accessibilityLabel: \.title
                ) { kind in
                    WellnessMetricOrderRow(
                        kind: kind,
                        unit: unitBinding(for: kind),
                        hide: { draft.enabledMetrics.removeAll { $0 == kind } }
                    )
                }
            }
            if hiddenMetrics.isEmpty == false {
                ComposerSection("Hidden metrics") {
                    ForEach(hiddenMetrics, id: \.self) { kind in
                        Button {
                            draft.enabledMetrics.append(kind)
                        } label: {
                            Label("Show \(kind.title)", systemImage: "plus.circle")
                        }
                        .buttonStyle(.lifeBoardChip)
                    }
                }
            }
        }
    }

    private func unitBinding(for kind: BodyMetricKind) -> Binding<WellnessDisplayUnit> {
        Binding(
            get: { draft.preferredUnit(for: kind) },
            set: { draft.preferredUnits[kind] = $0 }
        )
    }

    private func displayOrder(for kind: BodyMetricKind) -> Int {
        (draft.enabledMetrics.firstIndex(of: kind) ?? BodyMetricKind.allCases.firstIndex(of: kind) ?? 0) + 1
    }

    private var hiddenMetrics: [BodyMetricKind] {
        BodyMetricKind.allCases.filter { !draft.enabledMetrics.contains($0) }
    }
}

/// Logging one body measurement.
///
/// Was a bare `.decimalPad` field beside a `Stepper("Adjust")` that moved weight
/// one kilogram per tap — the least tactile control in an app whose whole
/// premise is tactility. The tape is the right instrument for this: almost every
/// entry is a small move from the last reading, which is a scrub, not a typing
/// task. The keyboard stays one tap away on the readout for the times it isn't.
