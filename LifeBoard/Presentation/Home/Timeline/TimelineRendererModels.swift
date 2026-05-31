//
//  TimelineRendererModels.swift
//  LifeBoard
//
//  Move-only timeline decomposition.
//

import SwiftUI

enum SunriseTimelineRendererMode: Equatable {
    case compact
    case expanded
    case agenda
}

enum SunriseTimelineRendererPolicy {
    static func mode(
        layoutClass: LifeBoardLayoutClass,
        dayLayoutMode _: TimelineDayLayoutMode,
        isAccessibilitySize: Bool
    ) -> SunriseTimelineRendererMode {
        if isAccessibilitySize {
            return .agenda
        }

        switch layoutClass {
        case .phone:
            return .expanded
        case .padCompact:
            return .compact
        case .padRegular, .padExpanded:
            return .expanded
        }
    }
}

enum VisualTimelineElement: Equatable, Identifiable {
    struct RoutineMarkerModel: Equatable, Identifiable {
        let anchor: TimelineAnchorItem
        let temporalY: CGFloat
        let height: CGFloat

        var id: String { "routine:\(anchor.id)" }
    }

    struct SingleItemModel: Equatable, Identifiable {
        let item: TimelinePlanItem
        let temporalY: CGFloat
        let height: CGFloat
        let isEmphasized: Bool

        var id: String { item.id }
    }

    struct FlockBlockModel: Equatable, Identifiable {
        let block: TimelineTimeBlock
        let temporalY: CGFloat
        let height: CGFloat

        var id: String { block.id }
    }

    struct GapPromptModel: Equatable, Identifiable {
        let gap: TimelineGap
        let temporalY: CGFloat
        let height: CGFloat

        var id: String { "gap:\(gap.id)" }
    }

    struct EmptyStateModel: Equatable, Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let primaryTitle: String
        let secondaryTitle: String
        let showsCalendarAction: Bool
        let suggestedDate: Date
        let temporalStart: Date
        let temporalY: CGFloat
        let height: CGFloat
    }

    case routineMarker(RoutineMarkerModel)
    case meetingCard(SingleItemModel)
    case taskMarker(SingleItemModel)
    case taskCard(SingleItemModel)
    case flock(FlockBlockModel)
    case gapPrompt(GapPromptModel)
    case emptyState(EmptyStateModel)

    var id: String {
        switch self {
        case .routineMarker(let model):
            return model.id
        case .meetingCard(let model):
            return "meeting:\(model.id)"
        case .taskMarker(let model):
            return "task-marker:\(model.id)"
        case .taskCard(let model):
            return "task-card:\(model.id)"
        case .flock(let model):
            return "flock:\(model.id)"
        case .gapPrompt(let model):
            return model.id
        case .emptyState(let model):
            return model.id
        }
    }

    var temporalStart: Date {
        switch self {
        case .routineMarker(let model):
            return model.anchor.time
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.item.startDate ?? .distantPast
        case .flock(let model):
            return model.block.startDate
        case .gapPrompt(let model):
            return model.gap.startDate
        case .emptyState(let model):
            return model.temporalStart
        }
    }

    var temporalEnd: Date {
        switch self {
        case .routineMarker(let model):
            return model.anchor.time
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.item.endDate ?? model.item.startDate ?? .distantPast
        case .flock(let model):
            return model.block.endDate
        case .gapPrompt(let model):
            return model.gap.endDate
        case .emptyState(let model):
            return model.temporalStart
        }
    }

    var temporalY: CGFloat {
        switch self {
        case .routineMarker(let model):
            return model.temporalY
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.temporalY
        case .flock(let model):
            return model.temporalY
        case .gapPrompt(let model):
            return model.temporalY
        case .emptyState(let model):
            return model.temporalY
        }
    }

    var measuredHeight: CGFloat {
        switch self {
        case .routineMarker(let model):
            return model.height
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.height
        case .flock(let model):
            return model.height
        case .gapPrompt(let model):
            return model.height
        case .emptyState(let model):
            return model.height
        }
    }

    var displayPriority: Int {
        switch self {
        case .flock:
            return 0
        case .meetingCard:
            return 1
        case .taskCard:
            return 2
        case .taskMarker:
            return 3
        case .routineMarker:
            return 4
        case .gapPrompt:
            return 5
        case .emptyState:
            return 6
        }
    }

    var isPlottedContent: Bool {
        switch self {
        case .meetingCard, .taskMarker, .taskCard, .flock:
            return true
        case .routineMarker, .gapPrompt, .emptyState:
            return false
        }
    }

    func isActive(at date: Date) -> Bool {
        switch self {
        case .routineMarker:
            return false
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.item.isActive(at: date)
        case .flock(let model):
            return model.block.items.contains { $0.isActive(at: date) }
        case .gapPrompt(let model):
            return model.gap.startDate <= date && date < model.gap.endDate
        case .emptyState:
            return false
        }
    }

    static func elementSort(_ lhs: VisualTimelineElement, _ rhs: VisualTimelineElement, now: Date) -> Bool {
        if lhs.temporalStart != rhs.temporalStart {
            return lhs.temporalStart < rhs.temporalStart
        }
        if lhs.temporalY != rhs.temporalY {
            return lhs.temporalY < rhs.temporalY
        }
        let lhsActive = lhs.isActive(at: now)
        let rhsActive = rhs.isActive(at: now)
        if lhsActive != rhsActive {
            return lhsActive
        }
        if lhs.displayPriority != rhs.displayPriority {
            return lhs.displayPriority < rhs.displayPriority
        }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }
}

