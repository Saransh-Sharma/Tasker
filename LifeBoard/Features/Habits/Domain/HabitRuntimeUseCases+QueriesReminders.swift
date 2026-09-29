import Foundation
import UserNotifications

public final class GetDueHabitsForDateUseCase: @unchecked Sendable {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        date: Date,
        completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        readRepository.fetchAgendaHabits(for: date, completion: completion)
    }

    public func execute(
        date: Date,
        habitID: UUID,
        completion: @escaping @Sendable (Result<HabitOccurrenceSummary?, Error>) -> Void
    ) {
        readRepository.fetchAgendaHabit(habitID: habitID, for: date, completion: completion)
    }
}

public final class GetHabitHistoryUseCase: @unchecked Sendable {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        habitIDs: [UUID],
        endingOn date: Date = Date(),
        dayCount: Int = 14,
        completion: @escaping @Sendable (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        readRepository.fetchHistory(habitIDs: habitIDs, endingOn: date, dayCount: dayCount, completion: completion)
    }
}

public final class GetHabitSignalsInRangeUseCase: @unchecked Sendable {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        start: Date,
        end: Date,
        completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        readRepository.fetchSignals(start: start, end: end, completion: completion)
    }
}

public final class GetHabitLibraryUseCase: @unchecked Sendable {
    private let readRepository: HabitRuntimeReadRepositoryProtocol

    public init(readRepository: HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
    }

    public func execute(
        includeArchived: Bool = true,
        completion: @escaping @Sendable (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        readRepository.fetchHabitLibrary(includeArchived: includeArchived, completion: completion)
    }

    public func execute(
        habitIDs: [UUID]?,
        includeArchived: Bool = true,
        completion: @escaping @Sendable (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        readRepository.fetchHabitLibrary(
            habitIDs: habitIDs,
            includeArchived: includeArchived,
            completion: completion
        )
    }

    public func execute(
        habitID: UUID,
        includeArchived: Bool = true,
        completion: @escaping @Sendable (Result<HabitLibraryRow?, Error>) -> Void
    ) {
        readRepository.fetchHabitDetailSummary(
            habitID: habitID,
            includeArchived: includeArchived,
            completion: completion
        )
    }
}

public final class BuildHabitHomeProjectionUseCase: @unchecked Sendable {
    private let getDueHabitsForDateUseCase: GetDueHabitsForDateUseCase

    public init(
        getDueHabitsForDateUseCase: GetDueHabitsForDateUseCase
    ) {
        self.getDueHabitsForDateUseCase = getDueHabitsForDateUseCase
    }

    public func execute(
        date: Date,
        completion: @escaping @Sendable (Result<[HomeHabitRow], Error>) -> Void
    ) {
        getDueHabitsForDateUseCase.execute(date: date) { fetchResult in
            switch fetchResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let summaries):
                let rows = summaries.map { Self.makeHomeRow(summary: $0, date: date) }
                completion(.success(rows))
            }
        }
    }

    public func execute(
        date: Date,
        habitID: UUID,
        completion: @escaping @Sendable (Result<HomeHabitRow?, Error>) -> Void
    ) {
        getDueHabitsForDateUseCase.execute(date: date, habitID: habitID) { result in
            completion(result.map { summary in
                summary.map { Self.makeHomeRow(summary: $0, date: date) }
            })
        }
    }

    private static func makeHomeRow(
        summary: HabitOccurrenceSummary,
        date: Date
    ) -> HomeHabitRow {
        let compactCells = HabitBoardPresentationBuilder.buildCells(
            marks: summary.last14Days,
            cadence: summary.cadence,
            referenceDate: date,
            dayCount: 7
        )
        let expandedCells = HabitBoardPresentationBuilder.buildCells(
            marks: summary.last14Days,
            cadence: summary.cadence,
            referenceDate: date,
            dayCount: 30
        )
        let rowState = HabitRuntimeSupport.homeState(for: summary, on: date)
        let calendar = Calendar.current
        let todayMark = summary.last14Days.first { mark in
            calendar.isDate(mark.date, inSameDayAs: date)
        }
        let riskState = todayMark?.state == .failure ? HabitRiskState.broken : summary.riskState
        return HomeHabitRow(
            habitID: summary.habitID,
            occurrenceID: summary.occurrenceID,
            title: summary.title,
            kind: summary.kind,
            trackingMode: summary.trackingMode,
            lifeAreaID: summary.lifeAreaID,
            lifeAreaName: summary.lifeAreaName,
            projectID: summary.projectID,
            projectName: summary.projectName,
            iconSymbolName: summary.icon?.symbolName ?? "circle.dashed",
            accentHex: summary.colorHex,
            cadence: summary.cadence,
            cadenceLabel: HabitBoardPresentationBuilder.cadenceLabel(for: summary.cadence),
            dueAt: summary.dueAt,
            state: rowState,
            currentStreak: summary.currentStreak,
            bestStreak: summary.bestStreak,
            last14Days: summary.last14Days,
            boardCellsCompact: compactCells,
            boardCellsExpanded: expandedCells,
            riskState: riskState,
            helperText: nil
        )
    }
}

// MARK: - Habit reminders

/// One repeating local notification for a habit's reminder time.
public struct HabitReminderRequest: Equatable, Sendable {
    public let identifier: String
    /// Calendar weekday (1 = Sunday); nil repeats every day.
    public let weekday: Int?
    public let hour: Int
    public let minute: Int
}

/// Which reminders a habit should have.
///
/// A habit's reminder time was saved with its schedule and shown in its editor,
/// but nothing ever turned it into a notification, so "Remind me at 9:00" did
/// nothing. Trackers and medications already schedule theirs; this is the same
/// shape for habits.
public enum HabitReminderPolicy {
    public static func requests(for row: HabitLibraryRow) -> [HabitReminderRequest] {
        guard row.isPaused == false, row.isArchived == false,
              let time = parseTime(row.reminderWindowStart) else { return [] }
        let prefix = "lifeboard.habit.\(row.habitID.uuidString)"
        switch row.cadence {
        case .daily:
            return [.init(identifier: "\(prefix).daily", weekday: nil, hour: time.hour, minute: time.minute)]
        case let .weekly(daysOfWeek, _, _):
            return Set(daysOfWeek).filter { (1...7).contains($0) }.sorted().map {
                .init(identifier: "\(prefix).\($0)", weekday: $0, hour: time.hour, minute: time.minute)
            }
        case .interval:
            // "Every N days" has no repeating calendar trigger; a daily reminder
            // would nag on days the habit is not due. Left unscheduled rather
            // than wrong.
            return []
        }
    }

    public static func identifiers(for habitID: UUID) -> [String] {
        let prefix = "lifeboard.habit.\(habitID.uuidString)"
        return ["\(prefix).daily"] + (1...7).map { "\(prefix).\($0)" }
    }

    /// "HH:mm" → hour and minute; nil for anything else.
    public static func parseTime(_ raw: String?) -> (hour: Int, minute: Int)? {
        guard let raw else { return nil }
        let parts = raw.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// The habit name is the title; the body is the target ("Goal: 8 glasses
    /// a day") or a plain line when there is no amount to show.
    public static func body(for row: HabitLibraryRow) -> String {
        let target = row.targetConfig?.effectiveTarget ?? (row.kind == .negative ? .avoidance : .binary)
        switch target {
        case .binary:
            return String(localized: "Due today")
        case .avoidance:
            return String(localized: "Check in today")
        case .quantitative, .quota, .timed:
            let goal = HabitTemplateCatalog.summary(for: target)
            return String(localized: "Goal: \(goal)")
        }
    }
}

/// Keeps pending habit notifications in step with the habit library: on launch
/// and after every habit mutation (create, edit, pause, archive, delete).
public actor HabitReminderCoordinator {
    public static let shared = HabitReminderCoordinator()

    private let center: UNUserNotificationCenter
    private var readRepository: (any HabitRuntimeReadRepositoryProtocol)?
    private var observer: NSObjectProtocol?
    private var scheduledHabitIDs: Set<UUID> = []

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func install(readRepository: any HabitRuntimeReadRepositoryProtocol) {
        self.readRepository = readRepository
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: .homeHabitMutation,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { await self?.reconcile(requestingPermission: true) }
            }
        }
        Task { await reconcile(requestingPermission: false) }
    }

    /// Asks for permission only when a habit change turns a reminder on — a
    /// launch never asks, and neither does creating or editing a habit with no
    /// reminder. The request is a normal one, never `.provisional`: a
    /// provisional grant made every notification in the app arrive quietly.
    public func reconcile(requestingPermission: Bool) async {
        guard let readRepository else { return }
        let rows: [HabitLibraryRow] = await withCheckedContinuation { continuation in
            readRepository.fetchHabitLibrary(includeArchived: true) { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        let previouslyScheduled = scheduledHabitIDs
        let staleIDs = Set(rows.map(\.habitID)).union(scheduledHabitIDs)
        center.removePendingNotificationRequests(withIdentifiers: staleIDs.flatMap(HabitReminderPolicy.identifiers(for:)))

        let wanted = rows.flatMap { row in HabitReminderPolicy.requests(for: row).map { (row, $0) } }
        scheduledHabitIDs = Set(wanted.map(\.0.habitID))
        guard wanted.isEmpty == false else { return }

        let newlyReminded = scheduledHabitIDs.subtracting(previouslyScheduled)
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined, requestingPermission, newlyReminded.isEmpty == false {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

        for (row, request) in wanted {
            let content = UNMutableNotificationContent()
            content.title = row.title
            content.body = HabitReminderPolicy.body(for: row)
            content.sound = .default
            content.userInfo = ["habitID": row.habitID.uuidString]
            var components = DateComponents()
            components.hour = request.hour
            components.minute = request.minute
            components.weekday = request.weekday
            try? await center.add(.init(
                identifier: request.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            ))
        }
    }
}
