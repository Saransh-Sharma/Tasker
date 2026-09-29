import SwiftUI
import UIKit

/// Focus history, reached from the settled session's receipt and from the
/// "session ended" state. Reads ended sessions through the same planning
/// repository the session route uses; titles come from the task definitions,
/// so a task finished since still names its sessions.
private struct FocusHistoryLoadKey: Hashable {
    let month: Date
    let generation: Int
}

struct FocusHistoryRouteView: View {
    let dependencies: PlanFeatureDependencies
    let router: AppRouter

    @State private var month = Date()
    @State private var state: RouteLoadState<FocusHistoryProjection> = .loading
    @State private var titles: [UUID: String] = [:]
    /// A month change after the first load: the screen stays, redacted, rather
    /// than showing last month's numbers under this month's title.
    @State private var isLoadingMonth = false
    @State private var reloadGeneration = 0

    var body: some View {
        EntityRouteScaffold(
            title: "Focus history",
            systemImage: "clock.arrow.circlepath",
            state: state,
            retry: {
                state = .loading
                reloadGeneration &+= 1
            }
        ) { projection in
            FocusHistoryScreen(
                projection: projection,
                isLoading: isLoadingMonth,
                canShowNextMonth: Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month) == false,
                onPreviousMonth: { shift(by: -1) },
                onNextMonth: { shift(by: 1) },
                onOpenTask: { router.push(.taskDetail($0), in: .plan) }
            )
        }
        .task(id: FocusHistoryLoadKey(month: month, generation: reloadGeneration)) { await load() }
    }

    private func shift(by months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months, to: month) else { return }
        // No future months: there is nothing to show there yet.
        guard next <= Date() || Calendar.current.isDate(next, equalTo: Date(), toGranularity: .month) else { return }
        isLoadingMonth = true
        month = next
    }

    private func load() async {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        do {
            if titles.isEmpty {
                let repository = dependencies.taskDefinitionRepository
                let definitions: [TaskDefinition] = try await withCheckedThrowingContinuation { continuation in
                    repository.fetchAll { continuation.resume(with: $0) }
                }
                titles = Dictionary(definitions.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
            }
            // One month back covers a session that started before midnight on
            // the first; the projection filters to the month itself.
            let since = calendar.date(byAdding: .day, value: -1, to: monthStart)
            let sessions = try await dependencies.planningRepository.sessions(since: since)
            let lookup = titles
            state = .loaded(FocusHistoryProjection.make(
                month: monthStart,
                sessions: sessions,
                titles: { lookup[$0] },
                calendar: calendar
            ))
            isLoadingMonth = false
        } catch {
            isLoadingMonth = false
            state = .failed(error.localizedDescription)
        }
    }
}
