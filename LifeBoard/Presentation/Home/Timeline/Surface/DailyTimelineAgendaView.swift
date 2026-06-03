import SwiftUI

struct DailyTimelineAgendaView: View {
    let projection: TimelineDayProjection
    let layoutClass: LifeBoardLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onAddTask: (Date?) -> Void
    let onScheduleInbox: () -> Void
    let stablePresentation: TimelineDayStablePresentation

    enum Entry: Identifiable {
        case anchor(TimelineAnchorItem)
        case gap(TimelineGap)
        case block(TimelineTimeBlock)

        var id: String {
            switch self {
            case .anchor(let anchor):
                return "anchor:\(anchor.id)"
            case .gap(let gap):
                return "gap:\(gap.id)"
            case .block(let block):
                return "block:\(block.id)"
            }
        }
    }

    var entries: [Entry] {
        let beforeWakeBlocks = agendaBlocks(from: projection.beforeWakeItems)
        let blocks = agendaBlocks(from: projection.timedItems)
        let afterSleepBlocks = agendaBlocks(from: projection.afterSleepItems)
        let gaps = projection.actionableGaps.sorted { $0.startDate < $1.startDate }
        var blockIndex = 0
        var gapIndex = 0
        var result = beforeWakeBlocks.map(Entry.block)
        result.append(.anchor(projection.wakeAnchor))

        while blockIndex < blocks.count || gapIndex < gaps.count {
            if blockIndex >= blocks.count {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
                continue
            }
            if gapIndex >= gaps.count {
                result.append(.block(blocks[blockIndex]))
                blockIndex += 1
                continue
            }
            if gaps[gapIndex].startDate <= blocks[blockIndex].startDate {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
            } else {
                result.append(.block(blocks[blockIndex]))
                blockIndex += 1
            }
        }

        result.append(.anchor(projection.sleepAnchor))
        result.append(contentsOf: afterSleepBlocks.map(Entry.block))
        return result
    }

    init(
        projection: TimelineDayProjection,
        layoutClass: LifeBoardLayoutClass,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAnchorTap: @escaping (TimelineAnchorItem) -> Void,
        onAddTask: @escaping (Date?) -> Void,
        onScheduleInbox: @escaping () -> Void
    ) {
        self.projection = projection
        self.layoutClass = layoutClass
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAnchorTap = onAnchorTap
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.stablePresentation = TimelineDayStablePresentation(projection: projection)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timelineDisplayedNow(for: projection, timelineDate: timeline.date)
            let presentation = TimelineDayPresentation(stable: stablePresentation, now: now)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(entries) { entry in
                    switch entry {
                    case .anchor(let anchor):
                        TimelineAgendaAnchorRow(
                            anchor: anchor,
                            row: presentation.row(for: anchor),
                            onTap: { onAnchorTap(anchor) }
                        )
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    case .gap(let gap):
                        let suggestedDate = timelineSuggestedAddDate(for: gap, now: presentation.now)
                        TimelineGapPrompt(
                            gap: gap,
                            row: presentation.row(for: gap),
                            suggestedDate: suggestedDate,
                            onAddTask: { onAddTask(suggestedDate) },
                            onPlanBlock: onScheduleInbox
                        )
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    case .block(let block):
                        agendaBlockView(block, presentation: presentation)
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    }
                }
            }
        }
    }

    func agendaBlocks(from items: [TimelinePlanItem]) -> [TimelineTimeBlock] {
        let dayStart = Calendar.current.startOfDay(for: projection.date)
        return TimelineTimeBlock.make(from: items.compactMap { item in
            guard let startDate = item.startDate, let endDate = item.endDate else { return nil }
            let startMinute = CGFloat(Calendar.current.dateComponents([.minute], from: dayStart, to: startDate).minute ?? 0)
            let endMinute = CGFloat(Calendar.current.dateComponents([.minute], from: dayStart, to: endDate).minute ?? 0)
            return TimelineTimeBlock.Input(
                item: item,
                startDate: startDate,
                endDate: endDate,
                startMinute: startMinute,
                endMinute: max(endMinute, startMinute + 1),
                y: 0,
                height: 0
            )
        })
    }

    @ViewBuilder
    func agendaBlockView(
        _ block: TimelineTimeBlock,
        presentation: TimelineDayPresentation
    ) -> some View {
        switch block.kind {
        case .single(let item):
            TimelineAgendaItemRow(
                item: item,
                row: presentation.row(for: item),
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
        case .conflict:
            TimelineTimeBlockCard(
                block: block,
                presentation: presentation,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
        }
    }
}
