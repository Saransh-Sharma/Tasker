import SwiftUI

struct TimelineAnchorRitualSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDate: Date
    @State private var tokenSettled = false
    @State private var hasCommittedChanges = false

    let selection: TimelineAnchorSelection
    let preferencesStore: LifeBoardWorkspacePreferencesStore

    private let calendar: Calendar

    init(
        selection: TimelineAnchorSelection,
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared,
        calendar: Calendar = .current
    ) {
        self.selection = selection
        self.preferencesStore = preferencesStore
        self.calendar = calendar
        let preferences = preferencesStore.load()
        self._selectedDate = State(initialValue: selection.date(from: preferences, calendar: calendar))
    }

    var body: some View {
        GeometryReader { proxy in
            let sheetWidth = max(0, proxy.size.width)
            let metrics = TimelineAnchorRitualLayoutPolicy.metrics(
                sheetWidth: sheetWidth,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )
            let model = TimelineAnchorRitualModel(
                selection: selection,
                selectedDate: selectedDate,
                calendar: calendar
            )
            let theme = TimelineAnchorRitualTheme.theme(for: selection)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    TimelineAnchorRitualHero(
                        model: model,
                        theme: theme,
                        sheetWidth: metrics.sheetWidth,
                        heroHeight: heroHeight(for: proxy.size.height)
                    ) {
                        closeSheet()
                    }

                    TimelineAnchorRitualContent(
                        model: model,
                        theme: theme,
                        metrics: metrics,
                        tokenSize: min(tokenSize, max(56, metrics.contentWidth * 0.20)),
                        tokenSettled: tokenSettled || reduceMotion,
                        reduceMotion: reduceMotion,
                        reduceTransparency: reduceTransparency,
                        selectTime: selectTime(_:),
                        saveChanges: saveChanges
                    )
                }
                .frame(width: metrics.sheetWidth, alignment: .top)
                .padding(.bottom, 18)
            }
            .background(theme.surface)
            .ignoresSafeArea(edges: .bottom)
            .clipped()
            .accessibilityIdentifier("timelineAnchorDetail.view")
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.modalAccessibilityLabel)
            .onAppear {
                settleTokenIfNeeded()
            }
        }
        .onDisappear {
            commitChangesIfNeeded()
        }
    }

    @ScaledMetric(relativeTo: .largeTitle) private var tokenSize: CGFloat = 72

    private func heroHeight(for availableHeight: CGFloat) -> CGFloat {
        let base = min(max(availableHeight * 0.25, 170), 200)
        return dynamicTypeSize.isAccessibilitySize ? max(158, base - 18) : base
    }

    private func selectTime(_ option: TimelineAnchorRitualTimeOption) {
        selectedDate = option.date
        LifeBoardFeedback.light()
    }

    private func saveChanges() {
        commitChangesIfNeeded(playFeedback: true)
        dismiss()
    }

    private func closeSheet() {
        commitChangesIfNeeded(playFeedback: true)
        dismiss()
    }

    private func commitChangesIfNeeded(playFeedback: Bool = false) {
        guard hasCommittedChanges == false else { return }
        hasCommittedChanges = true
        TimelineAnchorRitualModel.save(
            selectedDate: selectedDate,
            selection: selection,
            to: preferencesStore,
            calendar: calendar
        )
        if playFeedback {
            LifeBoardFeedback.success()
        }
    }

    private func settleTokenIfNeeded() {
        guard reduceMotion == false else {
            tokenSettled = true
            return
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.78).delay(0.05)) {
            tokenSettled = true
        }
    }
}

private struct TimelineAnchorRitualHero: View {
    let model: TimelineAnchorRitualModel
    let theme: TimelineAnchorRitualTheme
    let sheetWidth: CGFloat
    let heroHeight: CGFloat
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Image(decorative: theme.heroAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: sheetWidth, height: heroHeight)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 78, height: 7)
                .padding(.top, 18)
                .accessibilityHidden(true)

            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(Color(lifeboardHex: "#2F241D"))
                        .frame(width: 60, height: 60)
                        .background(.regularMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timelineAnchorDetail.closeButton")
                .accessibilityLabel("Close")

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
        }
        .frame(width: sheetWidth, height: heroHeight)
        .clipped()
    }
}

private struct TimelineAnchorRitualContent: View {
    let model: TimelineAnchorRitualModel
    let theme: TimelineAnchorRitualTheme
    let metrics: TimelineAnchorRitualLayoutMetrics
    let tokenSize: CGFloat
    let tokenSettled: Bool
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let selectTime: (TimelineAnchorRitualTimeOption) -> Void
    let saveChanges: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(model.title)
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(theme.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(model.subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(theme.subtitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)

                TimelineAnchorSelectedTimePill(model: model, theme: theme)
                    .padding(.top, 6)
            }
            .frame(width: metrics.contentWidth)
            .padding(.top, 32)

            TimelineAnchorTimeSelectorCard(
                model: model,
                theme: theme,
                metrics: metrics,
                reduceTransparency: reduceTransparency,
                selectTime: selectTime
            )
            .padding(.top, 22)

            Button(action: saveChanges) {
                Label("Save changes", systemImage: "checkmark")
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: metrics.ctaWidth, height: metrics.ctaHeight)
                    .background(theme.ctaGradient, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: theme.accent.opacity(0.26), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timelineAnchorDetail.saveButton")
            .accessibilityLabel("Save changes")
            .padding(.top, 18)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(theme.accent)
                Text(model.footerText)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(theme.accent.opacity(0.70))
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
            }
            .frame(width: metrics.contentWidth)
            .multilineTextAlignment(.center)
            .padding(.top, 14)
        }
        .padding(.bottom, 18)
        .frame(width: metrics.sheetWidth)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                theme.surface
                TimelineAnchorWaveShape()
                    .fill(theme.surface)
                    .frame(width: metrics.sheetWidth, height: 112)
                    .offset(y: -82)
                    .shadow(color: Color.white.opacity(0.65), radius: 2, x: 0, y: -1)
            }
        }
        .overlay(alignment: .top) {
            TimelineAnchorFloatingToken(theme: theme, size: tokenSize)
                .scaleEffect(tokenSettled ? 1 : 0.86)
                .opacity(tokenSettled ? 1 : 0.76)
                .offset(y: -52)
                .animation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.78), value: tokenSettled)
        }
    }
}

private struct TimelineAnchorFloatingToken: View {
    let theme: TimelineAnchorRitualTheme
    let size: CGFloat

    var body: some View {
        Image(systemName: theme.tokenSystemImageName)
            .font(.system(size: max(25, size * 0.42), weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(theme.accentDeep)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                theme.accentSoft.opacity(0.84)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: size * 0.62
                        )
                    )
            )
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 3)
            }
            .shadow(color: theme.accent.opacity(0.26), radius: 22, x: 0, y: 10)
            .accessibilityHidden(true)
    }
}

private struct TimelineAnchorSelectedTimePill: View {
    let model: TimelineAnchorRitualModel
    let theme: TimelineAnchorRitualTheme

    var body: some View {
        HStack(spacing: 14) {
            Text(model.selectedTimeText)
                .font(.lifeboard(.title2).weight(.semibold))
                .monospacedDigit()
            Image(systemName: theme.pillSystemImageName)
                .font(.lifeboard(.title3).weight(.semibold))
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, 26)
        .frame(minHeight: 50)
        .background(theme.accentSoft.opacity(0.84), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected time, \(model.selectedTimeText)")
        .accessibilityIdentifier("timelineAnchorDetail.selectedTimePill")
    }
}

private struct TimelineAnchorTimeSelectorCard: View {
    let model: TimelineAnchorRitualModel
    let theme: TimelineAnchorRitualTheme
    let metrics: TimelineAnchorRitualLayoutMetrics
    let reduceTransparency: Bool
    let selectTime: (TimelineAnchorRitualTimeOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(Color(lifeboardHex: "#46342C"))
                Text(model.sectionTitle)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(Color(lifeboardHex: "#2E241F"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                TimelineAnchorCardAccent(theme: theme)
                    .frame(width: 36, height: 44)
                    .accessibilityHidden(true)
            }

            chipRow
        }
        .padding(.horizontal, metrics.selectorHorizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .frame(width: metrics.selectorCardWidth, alignment: .top)
        .frame(minHeight: metrics.selectorCardHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(reduceTransparency ? theme.surface : Color.white.opacity(0.82))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(theme.cardBorder.opacity(0.86), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        .accessibilityIdentifier("timelineAnchorDetail.timeSelectorCard")
    }

    @ViewBuilder
    private var chipRow: some View {
        switch metrics.chipLayoutMode {
        case .fixed:
            HStack(spacing: metrics.chipSpacing) {
                ForEach(model.timeOptions) { option in
                    TimelineAnchorTimeChip(
                        option: option,
                        theme: theme,
                        width: metrics.chipWidth,
                        visualHeight: metrics.chipVisualHeight,
                        selectTime: selectTime
                    )
                }
            }
            .frame(width: metrics.selectorInnerWidth, alignment: .center)
        case .scrolling:
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: metrics.chipSpacing) {
                        ForEach(model.timeOptions) { option in
                            TimelineAnchorTimeChip(
                                option: option,
                                theme: theme,
                                width: metrics.chipWidth,
                                visualHeight: metrics.chipVisualHeight,
                                selectTime: selectTime
                            )
                            .id(option.id)
                        }
                    }
                    .frame(width: metrics.chipRowWidth)
                    .padding(.vertical, 2)
                }
                .frame(width: metrics.selectorInnerWidth, alignment: .leading)
                .clipped()
                .onAppear {
                    if let selectedID = model.timeOptions.first(where: \.isSelected)?.id {
                        scrollProxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct TimelineAnchorTimeChip: View {
    let option: TimelineAnchorRitualTimeOption
    let theme: TimelineAnchorRitualTheme
    let width: CGFloat
    let visualHeight: CGFloat
    let selectTime: (TimelineAnchorRitualTimeOption) -> Void

    var body: some View {
        Button {
            selectTime(option)
        } label: {
            VStack(spacing: 0) {
                Circle()
                    .fill(option.isSelected ? theme.accent : Color.clear)
                    .frame(width: 10, height: 10)
                    .padding(.bottom, 5)
                    .accessibilityHidden(true)

                VStack(spacing: 3) {
                    Text(option.hourText)
                        .font(.lifeboard(.headline).weight(option.isSelected ? .semibold : .regular))
                        .monospacedDigit()
                    Text(option.meridiemText)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(option.isSelected ? theme.accent : Color(lifeboardHex: "#4D403A"))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(width: width, height: visualHeight)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(option.isSelected ? theme.accentSoft : Color.white.opacity(0.42))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(option.isSelected ? theme.accentMist : Color(lifeboardHex: "#EFE7E1"), lineWidth: option.isSelected ? 2 : 1)
                }
                .shadow(color: option.isSelected ? theme.accent.opacity(0.12) : Color.black.opacity(0.035), radius: option.isSelected ? 8 : 4, x: 0, y: 3)
            }
        }
        .buttonStyle(.plain)
        .frame(width: width)
        .frame(minHeight: max(44, visualHeight + 15))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.accessibilityText)
        .accessibilityAddTraits(option.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("timelineAnchorDetail.timeChip.\(option.id)")
    }
}

private struct TimelineAnchorCardAccent: View {
    let theme: TimelineAnchorRitualTheme

    var body: some View {
        ZStack {
            Image(systemName: "leaf.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(theme.accent.opacity(0.28))
                .rotationEffect(.degrees(-18))
                .offset(x: 7, y: 8)
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.accent.opacity(0.48))
                .offset(x: -12, y: -12)
        }
    }
}
