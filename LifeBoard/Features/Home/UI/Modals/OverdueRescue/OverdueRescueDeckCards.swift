import SwiftUI
import UIKit

// A single card in the deck and the drag that resolves it.

// MARK: - OverdueRescueCardModel

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueCardModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let task: TaskDefinition
    let recommendation: EvaRescueRecommendation?
    let overdueDays: Int
    let projectLabel: String
    let confidenceLabel: String
    let reasonTitle: String
    let reasonBody: String
    let moveDate: Date?
    let moveButtonTitle: String
    let requiresDeleteConfirmation: Bool

    static func make(
        task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        projectsByID: [UUID: Project],
        now: Date,
        decisionAnchorDate: Date? = nil,
        decisionCalendar: Calendar = .current
    ) -> OverdueRescueCardModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dueDay = task.dueDate.map { calendar.startOfDay(for: $0) } ?? today
        let overdueDays = max(1, calendar.dateComponents([.day], from: dueDay, to: today).day ?? 1)
        let confidence = recommendation?.confidence ?? 0
        let reason = Self.reasonCopy(for: task, recommendation: recommendation, overdueDays: overdueDays)
        let moveDate = OverdueRescueMoveLaterResolver.resolveMoveDate(
            for: task,
            recommendation: recommendation,
            now: decisionAnchorDate ?? now,
            calendar: decisionCalendar
        )

        return OverdueRescueCardModel(
            id: task.id,
            task: task,
            recommendation: recommendation,
            overdueDays: overdueDays,
            projectLabel: task.projectID == ProjectConstants.inboxProjectID
                ? "No project"
                : (projectsByID[task.projectID]?.name ?? task.projectName ?? "No project"),
            confidenceLabel: confidence >= 0.75 ? "High confidence" : "Needs your call",
            reasonTitle: reason.title,
            reasonBody: reason.body,
            moveDate: moveDate,
            moveButtonTitle: OverdueRescueMoveLaterResolver.buttonTitle(
                for: moveDate,
                now: decisionAnchorDate ?? now,
                calendar: decisionCalendar
            ),
            requiresDeleteConfirmation: Self.requiresDeleteConfirmation(task, now: now)
        )
    }

    var overdueText: String {
        overdueDays == 1 ? "Needs a decision for 1 day" : "Needs a decision for \(overdueDays) days"
    }

    var isHighConfidence: Bool {
        (recommendation?.confidence ?? 0) >= 0.75
    }

    static func reasonCopy(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        overdueDays: Int
    ) -> (title: String, body: String) {
        if let recommendation, recommendation.reasons.isEmpty == false {
            let joined = recommendation.reasons
                .map { $0.replacingOccurrences(of: "Overdue \\d+d", with: "", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")

            switch recommendation.action {
            case .doToday:
                return ("Still relevant", joined.isEmpty ? "Relevant to current projects." : "\(joined).")
            case .move:
                return ("Today looks full", "This can move out of today’s board without risk.")
            case .split:
                return ("Needs a smaller next step", joined.isEmpty ? "Break this down before it blocks the day." : "\(joined).")
            case .dropCandidate:
                return ("Looks stale", joined.isEmpty ? "This has not moved in a while." : "\(joined).")
            }
        }

        if task.projectID != ProjectConstants.inboxProjectID {
            return ("Still relevant", "Relevant to current projects.")
        }
        if overdueDays >= 14 {
            return ("Looks stale", "This looks stale and has not moved in 2 weeks.")
        }
        return ("Needs your call", "Not enough signal to suggest a safe change.")
    }

    static func resolvedMoveDate(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        now: Date = Date()
    ) -> Date {
        OverdueRescueMoveLaterResolver.resolveMoveDate(for: task, recommendation: recommendation, now: now)
    }

    static func moveButtonTitle(for date: Date?, now: Date = Date()) -> String {
        OverdueRescueMoveLaterResolver.buttonTitle(for: date, now: now)
    }

    static func requiresDeleteConfirmation(_ task: TaskDefinition, now: Date = Date()) -> Bool {
        let hasNotes = task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasSubtasks = task.subtasks.isEmpty == false
        let hasRecurrence = task.recurrenceSeriesID != nil || task.repeatPattern != nil
        let hasProject = task.projectID != ProjectConstants.inboxProjectID
        let hasCalendarLink = task.scheduledStartAt != nil || task.scheduledEndAt != nil
        let hasRecentEdits = Calendar.current.dateComponents([.hour], from: task.updatedAt, to: now).hour ?? 999 < 24
        return hasNotes || hasSubtasks || hasRecurrence || hasProject || hasCalendarLink || hasRecentEdits
    }
}

// MARK: - OverdueRescueTaskCard

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueTaskCard: View {
    let card: OverdueRescueCardModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(card.task.title)
                        .font(.lifeboard(.title2))
                        .fontWeight(.bold)
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Label(card.projectLabel, systemImage: "folder")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(OverdueRescuePalette.secondaryInk)

                    Text(card.confidenceLabel)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.lifeboard.accentPrimary.opacity(0.11)))
                }
                .padding(.trailing, 78)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.overdueText)
                            .font(.lifeboard(.headline))
                            .fontWeight(.semibold)
                            .foregroundStyle(OverdueRescuePalette.secondaryInk)
                        Text(card.reasonBody)
                            .font(.lifeboard(.body))
                            .foregroundStyle(OverdueRescuePalette.innerBody)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Color.clear.frame(width: 84, height: 1)
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.innerCardCorner, style: .continuous)
                        .fill(OverdueRescuePalette.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.innerCardCorner, style: .continuous)
                                .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
                        )
                        .shadow(color: OverdueRescuePalette.softShadow, radius: 16, y: 8)
                )
            }
            .padding(30)

            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .opacity(0.74)
                .padding(.top, 30)
                .padding(.trailing, 24)
                .accessibilityHidden(true)

            Image(decorative: "rescue_decor_plant")
                .resizable()
                .scaledToFit()
                .frame(width: 106, height: 128)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -22, y: -82)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(
            RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            OverdueRescuePalette.cardSurfaceTop,
                            OverdueRescuePalette.cardSurfaceBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                        .stroke(OverdueRescuePalette.cardStroke, lineWidth: 1)
                )
                .shadow(color: OverdueRescuePalette.softShadow, radius: 32, y: 18)
        )
        .clipShape(RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous))
    }
}

// MARK: - OverdueRescueDragResolution

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueDragResolution: Equatable {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double
    let visibleOffset: CGSize
    let commitAction: OverdueRescueDecisionAction?
    let tiltDegrees: Double
}

// MARK: - OverdueRescueDragResolver

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueDragResolver {
    static let horizontalDominanceRatio: CGFloat = 1.15
    static let minimumIntentDistance: CGFloat = 24

    static func commitThreshold(cardWidth: CGFloat) -> CGFloat {
        max(96, cardWidth * 0.28)
    }

    static func maxDragOffset(cardWidth: CGFloat) -> CGFloat {
        cardWidth * 0.3
    }

    static func resolve(translation: CGSize, cardWidth: CGFloat, reduceMotion: Bool = false) -> OverdueRescueDragResolution {
        let reveal = revealKind(for: translation)
        let threshold = commitThreshold(cardWidth: cardWidth)
        let progress = reveal == .none ? 0 : revealProgress(for: translation.width, threshold: threshold)
        let clampLimit = maxDragOffset(cardWidth: cardWidth)
        let clampedWidth = max(-clampLimit, min(clampLimit, translation.width))
        let visibleOffset = reveal == .none ? .zero : CGSize(width: clampedWidth, height: translation.height * 0.06)
        let commitAction = commitAction(for: translation, cardWidth: cardWidth)
        let tilt = reduceMotion || reveal == .none ? 0 : Double(max(-5.5, min(5.5, translation.width / cardWidth * 6)))

        return OverdueRescueDragResolution(
            reveal: reveal,
            progress: progress,
            visibleOffset: visibleOffset,
            commitAction: commitAction,
            tiltDegrees: tilt
        )
    }

    static func revealKind(for translation: CGSize) -> OverdueRescueSwipeRevealKind {
        let width = translation.width
        let height = translation.height
        guard abs(width) > 8, abs(width) > abs(height) * horizontalDominanceRatio else {
            return .none
        }
        return width > 0 ? .keep : .move
    }

    static func commitAction(for translation: CGSize, cardWidth: CGFloat) -> OverdueRescueDecisionAction? {
        commitAction(
            for: translation,
            predictedEndTranslation: translation,
            cardWidth: cardWidth
        )
    }

    static func commitAction(
        for translation: CGSize,
        predictedEndTranslation: CGSize,
        cardWidth: CGFloat
    ) -> OverdueRescueDecisionAction? {
        guard abs(translation.width) >= minimumIntentDistance else { return nil }
        let reveal = revealKind(for: predictedEndTranslation)
        guard reveal != .none,
              abs(predictedEndTranslation.width) >= commitThreshold(cardWidth: cardWidth) else {
            return nil
        }
        return reveal == .keep ? .keepToday : .moveLater
    }

    static func revealProgress(for width: CGFloat, threshold: CGFloat) -> Double {
        let start = max(8, threshold * 0.08)
        let distance = abs(width)
        guard distance > start else { return 0 }
        return min(1, Double((distance - start) / max(1, threshold - start)))
    }
}
