import SwiftUI
import WidgetKit

private struct DomainWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSurfaceSnapshot?
}

private struct DomainWidgetProvider: TimelineProvider {
    let domain: SystemSurfaceDomain
    func placeholder(in context: Context) -> DomainWidgetEntry { .init(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (DomainWidgetEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DomainWidgetEntry>) -> Void) { completion(.init(entries: [entry()], policy: .after(Date().addingTimeInterval(900)))) }
    private func entry() -> DomainWidgetEntry {
        let envelope = try? SystemSnapshotReader.load(domain)
        return .init(date: Date(), snapshot: envelope?.snapshots.first)
    }
}

@MainActor
private struct DomainWidgetConfiguration {
    let domain: SystemSurfaceDomain

    static func description(for domain: SystemSurfaceDomain) -> String {
        domain.widgetDescription
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeBoard.\(domain.rawValue).v2", provider: DomainWidgetProvider(domain: domain)) { entry in
            DomainWidgetView(domain: domain, entry: entry)
                // Adaptive: a fixed cream container under the default `.primary`
                // ink rendered white text on cream on a dark Home Screen.
                .containerBackground(for: .widget) { WidgetBrand.canvasWarm }
        }
        .configurationDisplayName(domain.title)
        // A plain String, never an interpolated `LocalizedStringKey`: WidgetKit
        // rejects formatted text here at runtime ("Formatted text for
        // `description` is not supported"), and that one assertion takes the
        // whole extension down with it, so every widget and Live Activity in
        // the bundle silently stops rendering.
        .description(Self.description(for: domain))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct DomainWidgetView: View {
    let domain: SystemSurfaceDomain
    let entry: DomainWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                HStack { Image(systemName: entry.snapshot?.systemImage ?? domain.symbol); VStack(alignment: .leading) { Text(entry.snapshot?.title ?? domain.title).font(.caption2); Text(entry.snapshot?.primaryValue ?? domain.emptyValue).font(.caption.weight(.semibold)).lineLimit(2) } }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(entry.snapshot?.title ?? domain.title, systemImage: entry.snapshot?.systemImage ?? domain.symbol).font(.caption.weight(.semibold))
                    Text(entry.snapshot?.primaryValue ?? domain.emptyValue).font(.system(.title3, design: .rounded, weight: .semibold)).minimumScaleFactor(0.75)
                    if family == .systemMedium, let secondary = entry.snapshot?.secondaryValue { Text(secondary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                    Spacer(minLength: 0)
                    if let updatedAt = entry.snapshot?.updatedAt {
                        Text("Updated \(updatedAt.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        // Always the domain's own screen. The app still publishes a generic
        // "track"/"insights" path in older snapshots, and "track" is not a
        // host the router knows, so the snapshot's path is not trusted here.
        .widgetURL(URL(string: "lifeboard://\(domain.deepLinkPath)"))
        .accessibilityElement(children: .combine)
    }
}

@MainActor struct JournalDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .journal).body } }
@MainActor struct FastingDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .fasting).body } }
@MainActor struct NutritionDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .nutrition).body } }
@MainActor struct WellnessDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .wellness).body } }
@MainActor struct LifeMomentsDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .lifeMoments).body } }
@MainActor struct GoalsDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .goals).body } }
@MainActor struct RoutinesDomainWidget: Widget { var body: some WidgetConfiguration { DomainWidgetConfiguration(domain: .routines).body } }

private extension SystemSurfaceDomain {
    var title: String { switch self { case .journal: "Journal"; case .fasting: "Fasting"; case .nutrition: "Nutrition"; case .wellness: "Wellness"; case .lifeMoments: "Life Moments"; case .goals: "Goals"; case .routines: "Routines" } }
    var symbol: String { switch self { case .journal: "book.closed"; case .fasting: "timer"; case .nutrition: "fork.knife"; case .wellness: "heart.text.square"; case .lifeMoments: "calendar.badge.heart"; case .goals: "target"; case .routines: "repeat" } }
    var deepLinkPath: String { switch self { case .journal: "journal"; case .fasting: "fasting"; case .nutrition: "nutrition"; case .wellness: "wellness/body"; case .routines: "routines"; case .lifeMoments: "moments"; case .goals: "goals" } }
    /// Shown before the app has published anything for this area. A short
    /// fact; a tap opens the area.
    var emptyValue: String { switch self { case .journal: "No entries yet"; case .fasting: "No fast running"; case .nutrition: "Nothing logged today"; case .wellness: "No readings yet"; case .routines: "No routines yet"; case .lifeMoments: "No moments yet"; case .goals: "No goals yet" } }
    var widgetDescription: String { switch self { case .journal: "Your latest journal entry."; case .fasting: "Your current fast."; case .nutrition: "What you’ve eaten today."; case .wellness: "Your latest body measurement."; case .routines: "Your routines."; case .lifeMoments: "Your next life moment."; case .goals: "Your active goals." } }
}
