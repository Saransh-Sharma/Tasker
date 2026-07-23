import SwiftUI
import WidgetKit

private struct LifeBoardDomainWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LifeBoardSystemSurfaceSnapshot?
}

private struct LifeBoardDomainWidgetProvider: TimelineProvider {
    let domain: LifeBoardSystemSurfaceDomain
    func placeholder(in context: Context) -> LifeBoardDomainWidgetEntry { .init(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (LifeBoardDomainWidgetEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeBoardDomainWidgetEntry>) -> Void) { completion(.init(entries: [entry()], policy: .after(Date().addingTimeInterval(900)))) }
    private func entry() -> LifeBoardDomainWidgetEntry {
        let envelope = try? LifeBoardSystemSnapshotReader.load(domain)
        return .init(date: Date(), snapshot: envelope?.snapshots.first)
    }
}

@MainActor
private struct LifeBoardDomainWidgetConfiguration {
    let domain: LifeBoardSystemSurfaceDomain
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeBoard.\(domain.rawValue).v2", provider: LifeBoardDomainWidgetProvider(domain: domain)) { entry in
            LifeBoardDomainWidgetView(domain: domain, entry: entry)
                .containerBackground(for: .widget) { Color(red: 0.98, green: 0.96, blue: 0.91) }
        }
        .configurationDisplayName(domain.title)
        .description("A privacy-aware \(domain.title.lowercased()) glance from LifeBoard.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct LifeBoardDomainWidgetView: View {
    let domain: LifeBoardSystemSurfaceDomain
    let entry: LifeBoardDomainWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if family == .accessoryRectangular {
                HStack { Image(systemName: entry.snapshot?.systemImage ?? domain.symbol); VStack(alignment: .leading) { Text(entry.snapshot?.title ?? domain.title).font(.caption2); Text(entry.snapshot?.primaryValue ?? "Open LifeBoard").font(.caption.weight(.semibold)) } }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(entry.snapshot?.title ?? domain.title, systemImage: entry.snapshot?.systemImage ?? domain.symbol).font(.caption.weight(.semibold))
                    Text(entry.snapshot?.primaryValue ?? "Open LifeBoard to view").font(.system(.title3, design: .rounded, weight: .semibold)).minimumScaleFactor(0.75)
                    if family == .systemMedium, let secondary = entry.snapshot?.secondaryValue { Text(secondary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                    Spacer(minLength: 0)
                    Text(entry.snapshot?.updatedAt.formatted(date: .omitted, time: .shortened) ?? "Private by default").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .widgetURL(URL(string: "lifeboard://\(entry.snapshot?.deepLinkPath ?? domain.deepLinkPath)"))
        .accessibilityElement(children: .combine)
    }
}

@MainActor struct JournalDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .journal).body } }
@MainActor struct FastingDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .fasting).body } }
@MainActor struct NutritionDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .nutrition).body } }
@MainActor struct WellnessDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .wellness).body } }
@MainActor struct LifeMomentsDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .lifeMoments).body } }
@MainActor struct GoalsDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .goals).body } }
@MainActor struct RoutinesDomainWidget: Widget { var body: some WidgetConfiguration { LifeBoardDomainWidgetConfiguration(domain: .routines).body } }

private extension LifeBoardSystemSurfaceDomain {
    var title: String { switch self { case .journal: "Journal"; case .fasting: "Fasting"; case .nutrition: "Nutrition"; case .wellness: "Wellness"; case .lifeMoments: "Life Moments"; case .goals: "Goals"; case .routines: "Routines" } }
    var symbol: String { switch self { case .journal: "book.closed"; case .fasting: "timer"; case .nutrition: "fork.knife"; case .wellness: "heart.text.square"; case .lifeMoments: "calendar.badge.heart"; case .goals: "target"; case .routines: "repeat" } }
    var deepLinkPath: String { switch self { case .journal: "journal"; case .fasting, .nutrition, .wellness, .routines: "track"; case .lifeMoments, .goals: "insights" } }
}
