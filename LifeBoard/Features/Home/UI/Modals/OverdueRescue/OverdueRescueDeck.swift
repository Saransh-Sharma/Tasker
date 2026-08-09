import SwiftUI
import UIKit

// The deck itself: state, layout metrics, and the views that draw it.

// MARK: - OverdueRescueDeckState

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueDeckState: String, Codable, Equatable, Sendable {
    case notStarted
    case loading
    case active
    case editing
    case confirmingDelete
    case paused
    case applyingBulk
    case completed
    case error
}

// MARK: - OverdueRescueDeckView

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueDeckView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    let bottomInset: CGFloat
    let close: () -> Void

    @GestureState var dragTranslation: CGSize = .zero
    @State var commitOffset: CGSize = .zero
    @State var viewportSize: CGSize = CGSize(width: 390, height: 844)
    @State private var snapCandidate: OverdueRescueDecisionAction?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        let metrics = OverdueRescueDeckLayoutMetrics.make(
            size: viewportSize,
            bottomInset: bottomInset,
            dynamicTypeSize: dynamicTypeSize
        )

        ViewThatFits(in: .vertical) {
            deckContent(metrics: metrics, scrollFallback: false)
            ScrollView(.vertical, showsIndicators: false) {
                deckContent(metrics: metrics, scrollFallback: true)
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewportSize = newSize
        }
    }

    func deckContent(metrics: OverdueRescueDeckLayoutMetrics, scrollFallback: Bool) -> some View {
        VStack(spacing: 0) {
            header(metrics: metrics)
                .padding(.top, scrollFallback ? 10 : 6)

            Color.clear.frame(height: metrics.dynamicTypeIsExpanded ? 16 : (metrics.isCompactHeight ? 18 : 28))

            if let card = viewModel.currentCard {
                let drag = activeDragResolution(metrics: metrics)
                ZStack(alignment: .center) {
                    OverdueRescueBackCards(metrics: metrics)

                    OverdueRescueRevealPanel(
                        reveal: drag.reveal,
                        progress: drag.progress,
                        metrics: metrics,
                        keepTitle: viewModel.keepActionTitle
                    )

                    OverdueRescueTaskCard(card: card)
                        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                        .offset(activeCardOffset(metrics: metrics))
                        .rotationEffect(.degrees(reduceMotion ? 0 : drag.tiltDegrees))
                        .scaleEffect(reduceMotion || drag.reveal == .none ? 1 : 1.012)
                        .animation(reduceMotion ? nil : LifeBoardAnimation.feedbackFast, value: card.id)
                        .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: drag.reveal)
                        .gesture(cardGesture(metrics: metrics), including: voiceOverEnabled ? .subviews : .all)
                }
                .frame(maxWidth: .infinity)
                .frame(width: min(metrics.containerSize.width + 34, metrics.cardWidth + 64), height: metrics.deckHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rescue. Card \(viewModel.progressText). \(card.task.title). \(card.confidenceLabel). \(card.overdueText). Actions: \(viewModel.keepActionTitle), \(card.moveButtonTitle), Edit, Delete.")
                .accessibilityIdentifier("home.rescue.card.\(card.id.uuidString)")
                .accessibilityAction(named: Text(viewModel.keepActionTitle)) {
                    viewModel.keepToday(source: .tap)
                }
                .accessibilityAction(named: Text(card.moveButtonTitle)) {
                    viewModel.moveLater(source: .tap)
                }
                .accessibilityAction(named: Text("Edit")) {
                    viewModel.requestEdit()
                }

                OverdueRescueSwipeHint(
                    reveal: drag.reveal,
                    progress: drag.progress
                )
                .padding(.top, metrics.dynamicTypeIsExpanded ? 12 : 8)

                OverdueRescueActionGrid(
                    metrics: metrics,
                    keepTitle: viewModel.keepActionTitle,
                    keepAccessibilityHint: viewModel.keepActionAccessibilityHint,
                    keep: { viewModel.keepToday(source: .tap) },
                    move: { viewModel.moveLater(source: .tap) },
                    edit: viewModel.requestEdit,
                    delete: viewModel.requestDelete
                )
                .disabled(viewModel.isDecisionInFlight)
                .frame(width: metrics.contentWidth)
                .padding(.top, metrics.dynamicTypeIsExpanded ? 12 : (metrics.isCompactHeight ? 12 : 16))
            } else {
                Spacer()
            }

            if scrollFallback {
                Color.clear.frame(height: metrics.bottomClearance + 22)
            } else {
                Spacer(minLength: 0)
                Color.clear.frame(height: metrics.bottomClearance)
            }
        }
        .frame(maxWidth: .infinity)
    }

    func header(metrics: OverdueRescueDeckLayoutMetrics) -> some View {
        VStack(spacing: metrics.dynamicTypeIsExpanded ? 8 : 7) {
            HStack {
                Button("Close", systemImage: "xmark") {
                    close()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(OverdueRescuePalette.ink)
                .frame(width: OverdueRescueVisualSpec.topButtonSize, height: OverdueRescueVisualSpec.topButtonSize)
                .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                .lifeboardElevation(.e1, cornerRadius: OverdueRescueVisualSpec.topButtonSize / 2, includesBorder: false)
                .accessibilityLabel("Close rescue")
                .accessibilityIdentifier("home.rescue.close")
                .disabled(viewModel.isDecisionInFlight)

                Spacer()

                Menu {
                    if viewModel.safeFixes.isEmpty == false {
                        Button("Apply high-confidence fixes") {
                            viewModel.showSafeFixesConfirmation = true
                        }
                    }
                    Button("Pause rescue") {
                        viewModel.pause()
                    }
                    Button("Restart sprint") {
                        viewModel.startManualReview()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: OverdueRescueVisualSpec.topButtonSize, height: OverdueRescueVisualSpec.topButtonSize)
                        .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                        .lifeboardElevation(.e1, cornerRadius: OverdueRescueVisualSpec.topButtonSize / 2, includesBorder: false)
                }
                    .accessibilityLabel("More rescue actions")
            }
            .padding(.horizontal, OverdueRescueVisualSpec.screenHorizontalPadding)

            VStack(spacing: 6) {
                Text("Rescue")
                    .font(.lifeboard(.title2))
                    .fontWeight(.bold)
                    .foregroundStyle(OverdueRescuePalette.ink)
                Text("Swipe or tap to sort what still matters.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)
                    .multilineTextAlignment(.center)
                Text(viewModel.progressText)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)
                    .padding(.top, 14)
                ProgressBar(
                    progress: viewModel.progress,
                    colors: [Color.lifeboard.accentPrimary],
                    trackColor: OverdueRescuePalette.progressTrack,
                    height: 7
                )
                .frame(width: metrics.progressWidth)
            }
        }
    }

    func cardGesture(metrics: OverdueRescueDeckLayoutMetrics) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                let candidate = OverdueRescueDragResolver.commitAction(
                    for: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    cardWidth: metrics.cardWidth
                )
                if candidate != nil, snapCandidate == nil {
                    HapticFeedback.selection()
                }
                snapCandidate = candidate
            }
            .onEnded { value in
                snapCandidate = nil
                if let action = OverdueRescueDragResolver.commitAction(
                    for: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    cardWidth: metrics.cardWidth
                ) {
                    HapticFeedback.medium()
                    commitDrag(action, metrics: metrics)
                } else {
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.stateChange) {
                        commitOffset = .zero
                    }
                }
            }
    }

    func activeDragResolution(metrics: OverdueRescueDeckLayoutMetrics) -> OverdueRescueDragResolution {
        if commitOffset != .zero {
            return OverdueRescueDragResolution(
                reveal: commitOffset.width > 0 ? .keep : .move,
                progress: 1,
                visibleOffset: commitOffset,
                commitAction: commitOffset.width > 0 ? .keepToday : .moveLater,
                tiltDegrees: reduceMotion ? 0 : Double(max(-5.5, min(5.5, commitOffset.width / metrics.cardWidth * 6)))
            )
        }
        return OverdueRescueDragResolver.resolve(
            translation: dragTranslation,
            cardWidth: metrics.cardWidth,
            reduceMotion: reduceMotion
        )
    }

    func activeCardOffset(metrics: OverdueRescueDeckLayoutMetrics) -> CGSize {
        activeDragResolution(metrics: metrics).visibleOffset
    }

    func commitDrag(_ action: OverdueRescueDecisionAction, metrics: OverdueRescueDeckLayoutMetrics) {
        withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.panelOut) {
            switch action {
            case .keepToday:
                commitOffset = CGSize(width: metrics.cardWidth + 120, height: 0)
            case .moveLater:
                commitOffset = CGSize(width: -metrics.cardWidth - 120, height: 0)
            case .edit, .delete:
                commitOffset = .zero
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : 0.20)) {
            commitOffset = .zero
            switch action {
            case .keepToday: viewModel.keepToday(source: .swipe)
            case .moveLater: viewModel.moveLater(source: .swipe)
            case .edit, .delete: break
            }
        }
    }
}

// MARK: - OverdueRescueDeckLayoutMetrics

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueDeckLayoutMetrics: Equatable {
    var containerSize: CGSize
    var bottomInset: CGFloat
    var dynamicTypeIsExpanded: Bool

    var horizontalInset: CGFloat {
        min(30, max(20, containerSize.width * 0.052))
    }

    var contentWidth: CGFloat {
        min(max(containerSize.width - horizontalInset * 2, 300), 390)
    }

    var isCompactHeight: Bool {
        // Modern iPhones can be taller than 880 points while still needing a
        // compact vertical composition once the status and home-indicator
        // safe areas are respected. Reserve the spacious deck for iPad and
        // genuinely tall Catalyst windows.
        containerSize.height < 1_020
    }

    var cardWidth: CGFloat {
        min(contentWidth + 12, containerSize.width - 28)
    }

    var cardHeight: CGFloat {
        let height = containerSize.height > 0 ? containerSize.height : 844
        if isCompactHeight {
            return min(354, max(318, height * 0.38))
        }
        return min(430, max(386, height * 0.44))
    }

    var deckHeight: CGFloat {
        cardHeight + (isCompactHeight ? 46 : 68)
    }

    var revealPanelWidth: CGFloat {
        cardWidth * 0.96
    }

    var revealPanelOffset: CGFloat {
        cardWidth * 0.12
    }

    var revealContentInset: CGFloat {
        min(max(58, cardWidth * 0.17), max(48, revealPanelWidth * 0.24))
    }

    var revealContentWidth: CGFloat {
        let availableWidth = max(84, revealPanelWidth - revealContentInset * 2)
        let idealWidth = min(max(96, cardWidth * 0.30), 118)
        return min(idealWidth, availableWidth)
    }

    func revealPanelOffset(for reveal: OverdueRescueSwipeRevealKind) -> CGFloat {
        switch reveal {
        case .keep: return -revealPanelOffset
        case .move: return revealPanelOffset
        case .none: return 0
        }
    }

    func revealContentFrame(for reveal: OverdueRescueSwipeRevealKind) -> CGRect {
        guard reveal != .none else { return .zero }
        let centerX = containerSize.width / 2 + revealPanelOffset(for: reveal)
        let panelMinX = centerX - revealPanelWidth / 2
        let panelMaxX = centerX + revealPanelWidth / 2

        switch reveal {
        case .keep:
            return CGRect(
                x: panelMinX + revealContentInset,
                y: 0,
                width: revealContentWidth,
                height: cardHeight * 0.96
            )
        case .move:
            return CGRect(
                x: panelMaxX - revealContentInset - revealContentWidth,
                y: 0,
                width: revealContentWidth,
                height: cardHeight * 0.96
            )
        case .none:
            return .zero
        }
    }

    var progressWidth: CGFloat {
        min(250, max(190, contentWidth * 0.58))
    }

    var actionButtonHeight: CGFloat {
        dynamicTypeIsExpanded ? 88 : (isCompactHeight ? 62 : 76)
    }

    var actionGridUsesSingleColumn: Bool {
        dynamicTypeIsExpanded || contentWidth < 330
    }

    var bottomClearance: CGFloat {
        max(isCompactHeight ? 24 : 36, bottomInset + 18)
    }

    static func make(size: CGSize, bottomInset: CGFloat, dynamicTypeSize: DynamicTypeSize) -> OverdueRescueDeckLayoutMetrics {
        OverdueRescueDeckLayoutMetrics(
            containerSize: CGSize(
                width: max(size.width, 320),
                height: max(size.height, 640)
            ),
            bottomInset: bottomInset,
            dynamicTypeIsExpanded: dynamicTypeSize.isAccessibilitySize
        )
    }
}

// MARK: - OverdueRescueDeckCopy

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueDeckCopy {
    static let keepToday = "Keep today"
    static let moveLater = "Move later"
    static let edit = "Edit"
    static let delete = "Delete"
}

// MARK: - OverdueRescueBackCards

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueBackCards: View {
    let metrics: OverdueRescueDeckLayoutMetrics

    var body: some View {
        ZStack(alignment: .center) {
            backCard(index: 0, reverseIndex: 3)
            backCard(index: 1, reverseIndex: 2)
            backCard(index: 2, reverseIndex: 1)
            backCard(index: 3, reverseIndex: 0)
        }
    }

    private func backCard(index: Int, reverseIndex: Int) -> some View {
        RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
            .fill(OverdueRescuePalette.backCard(index))
            .overlay(
                RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                    .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
            )
            .frame(
                width: metrics.cardWidth - CGFloat(reverseIndex) * 10,
                height: metrics.cardHeight - CGFloat(reverseIndex) * 8
            )
            .offset(
                x: horizontalOffset(reverseIndex),
                y: -CGFloat(reverseIndex) * 21
            )
            .scaleEffect(1.0 - Double(reverseIndex) * 0.015)
            .lbShadow(ShadowTokens.rescueStack(depth: index))
    }

    func horizontalOffset(_ reverseIndex: Int) -> CGFloat {
        switch reverseIndex {
        case 1: return 8
        case 2: return -12
        case 3: return 14
        default: return 0
        }
    }
}

// MARK: - OverdueRescueLargeStackView

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueLargeStackView: View {
    let count: Int
    let safeCount: Int
    let applySafeFixes: () -> Void
    let startManualReview: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 22) {
            OverdueRescueShieldHero()
                .frame(width: 220, height: 180)
            Text("Large rescue stack")
                .font(.lifeboard(.title1))
                .fontWeight(.bold)
                .foregroundStyle(OverdueRescuePalette.ink)
                .multilineTextAlignment(.center)
            Text("\(count) tasks need review. Start with high-confidence fixes or review manually.")
                .font(.lifeboard(.title3))
                .foregroundStyle(OverdueRescuePalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
            Spacer()
            Button("Apply safe fixes") {
                dismiss()
                applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.primaryButtonHeight)
            .background(OverdueRescueVisualSpec.primaryButtonBackground())
            .opacity(safeCount == 0 ? 0.58 : 1.0)
            .disabled(safeCount == 0)
            Button("Start manual review") {
                dismiss()
                startManualReview()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(OverdueRescuePalette.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(OverdueRescuePalette.accentSoftFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(OverdueRescuePalette.accentSoftStroke, lineWidth: 1.2)
                    )
            )
        }
        .padding(28)
        .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }
}

#if DEBUG
#Preview("Large Stack - Light") {
    OverdueRescueLargeStackView(
        count: 28,
        safeCount: 12,
        applySafeFixes: {},
        startManualReview: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Large Stack - Dark") {
    OverdueRescueLargeStackView(
        count: 28,
        safeCount: 12,
        applySafeFixes: {},
        startManualReview: {}
    )
    .preferredColorScheme(.dark)
}
#endif
