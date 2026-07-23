//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

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
                        metrics: metrics
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
                .accessibilityLabel("Rescue. Card \(viewModel.progressText). \(card.task.title). \(card.confidenceLabel). \(card.overdueText). Actions: Keep today, \(card.moveButtonTitle), Edit, Delete.")
                .accessibilityIdentifier("home.rescue.card.\(card.id.uuidString)")
                .accessibilityAction(named: Text("Keep today")) {
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
                    keep: { viewModel.keepToday(source: .tap) },
                    move: { viewModel.moveLater(source: .tap) },
                    edit: viewModel.requestEdit,
                    delete: viewModel.requestDelete
                )
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
                LifeBoardProgressBar(
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
                    LifeBoardFeedback.selection()
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
                    LifeBoardFeedback.medium()
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
