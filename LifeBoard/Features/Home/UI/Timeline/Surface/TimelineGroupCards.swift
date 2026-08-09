import SwiftUI

// Cards for more than one thing at once: overlapping items, flocks,
// the planning shelf, and the utility rows between them.

// MARK: - TimelineOverlapClusterCard

struct TimelineOverlapClusterCard: View {
    let block: TimelineTimeBlock
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 12
            let laneGap = TimelineTimeBlock.laneGap
            let laneCount = max(block.visualLaneCount, 1)
            let laneWidth = max(
                (proxy.size.width - (horizontalPadding * 2) - (CGFloat(laneCount - 1) * laneGap)) / CGFloat(laneCount),
                56
            )
            let titles = TimelineDenseTitleFormatter.displayTitles(for: block.items)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary.opacity(0.94))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(clusterAccent.opacity(0.82))
                    .frame(width: 4)
                    .padding(.vertical, 3)

                header
                    .padding(.leading, horizontalPadding + 4)
                    .padding(.trailing, horizontalPadding)
                    .padding(.top, 10)

                ForEach(block.lanePlacements) { placement in
                    TimelineOverlapItemCard(
                        placement: placement,
                        row: presentation.row(for: placement.item),
                        title: titles[placement.item.id] ?? placement.item.title,
                        densityMode: block.densityMode,
                        onTap: { onTaskTap(placement.item) },
                        onToggleComplete: {
                            guard placement.item.source == .task else { return }
                            onToggleComplete(placement.item)
                        }
                    )
                    .frame(width: laneWidth, height: placement.height)
                    .offset(
                        x: horizontalPadding + CGFloat(placement.laneIndex) * (laneWidth + laneGap),
                        y: TimelineTimeBlock.clusterHeaderHeight + placement.relativeY
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.compressed ? "Compressed overlap" : "Overlap"), \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate)), \(block.countLabel)")
        .accessibilityIdentifier("home.timeline.overlapCluster")
    }

    var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate))
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if block.compressed {
                    Label("Compressed", systemImage: "rectangle.compress.vertical")
                        .font(.lifeboard(.meta).weight(.medium))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Text(block.countLabel.lowercased())
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(clusterAccent.opacity(0.18), in: Capsule())
        }
    }

    var clusterAccent: Color {
        if block.containsTask && block.containsCalendarEvent {
            return Color.lifeboard.accentPrimary
        }
        if let tintHex = block.items.first?.tintHex {
            return Color(uiColor: UIColor(lifeboardHex: tintHex))
        }
        return Color.lifeboard.accentPrimary
    }
}

// MARK: - TimelineOverlapItemCard

struct TimelineOverlapItemCard: View {
    let placement: TimelineTimeBlock.LanePlacement
    let row: TimelineRenderableRow
    let title: String
    let densityMode: TimelineTimeBlock.DensityMode
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var item: TimelinePlanItem { placement.item }
    var palette: TimelinePalette { .resolve(from: item.tintHex) }
    var iconSize: CGFloat {
        switch densityMode {
        case .dualLane:
            return 22
        case .compactLane:
            return 18
        case .microLane, .densePacked:
            return 16
        case .normal:
            return 22
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .trailing) {
                watermarkIcon(size: watermarkSize, trailingOffset: watermarkTrailingOffset)

                HStack(alignment: .center, spacing: densityMode == .dualLane ? 7 : 5) {
                    Image(systemName: item.systemImageName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(palette.icon)
                        .frame(width: iconSize + 8, height: iconSize + 8)
                        .background(palette.fill.opacity(0.9), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: densityMode == .dualLane ? 3 : 2) {
                        Text(title)
                            .font(titleFont)
                            .foregroundStyle(timelineTitleColor(for: row, item: item))
                            .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(timeText)
                            .font(.lifeboard(.meta).weight(.medium))
                            .foregroundStyle(timelineMetaColor(for: row))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, densityMode == .dualLane ? 8 : 6)
            .padding(.vertical, densityMode == .dualLane ? 7 : 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.72))
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.6), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
        .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : item.source == .calendarEvent ? "Calendar event" : "Scheduled"))
        .accessibilityHint("Opens the item details.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
        .accessibilityAction(named: Text("Open")) {
            onTap()
        }
        .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
            guard item.source == .task else { return }
            onToggleComplete()
        }
    }

    var titleFont: Font {
        switch densityMode {
        case .dualLane:
            return .lifeboard(.caption1).weight(.semibold)
        case .compactLane:
            return .lifeboard(.caption1).weight(.semibold)
        case .microLane, .densePacked:
            return .lifeboard(.meta).weight(.semibold)
        case .normal:
            return .lifeboard(.caption1).weight(.semibold)
        }
    }

    var timeText: String {
        guard let start = item.startDate else { return "All day" }
        if densityMode == .dualLane, let end = item.endDate {
            return TimelineFormatting.timeRangeText(start: start, end: end)
        }
        return start.formatted(date: .omitted, time: .shortened)
    }

    var cardBackground: Color {
        if item.source == .task {
            return palette.base.opacity(0.12)
        }
        return Color.lifeboard.surfacePrimary.opacity(0.96)
    }

    var watermarkSize: CGFloat {
        switch densityMode {
        case .dualLane, .normal:
            return 56
        case .compactLane:
            return 46
        case .microLane, .densePacked:
            return 38
        }
    }

    var watermarkTrailingOffset: CGFloat {
        densityMode == .dualLane || densityMode == .normal ? 14 : 10
    }

    @ViewBuilder
    func watermarkIcon(size: CGFloat, trailingOffset: CGFloat) -> some View {
        if item.source == .task, let lifeAreaSystemImageName = item.lifeAreaSystemImageName {
            Image(systemName: lifeAreaSystemImageName)
                .font(.system(size: size, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.base.opacity(0.14))
                .offset(x: trailingOffset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - TimelineFlockBlock

struct TimelineFlockBlock: View {
    let model: TimelineFlockModel
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var accent: Color {
        if let item = model.rows.first(where: { $0.item != nil })?.item {
            return TimelinePalette.resolve(from: item.tintHex).progress
        }
        return Color.lifeboard.accentPrimary
    }

    var body: some View {
        let fallbackItem = model.rows.compactMap(\.item).first

        VStack(alignment: .leading, spacing: 6) {
            header

            VStack(alignment: .leading, spacing: TimelineFlockModel.rowSpacing) {
                ForEach(model.rows) { row in
                    TimelineFlockRowView(
                        row: row,
                        visualHeight: model.rowVisualHeight,
                        renderRow: row.item.map { presentation.row(for: $0) },
                        onTap: {
                            guard let item = row.item ?? fallbackItem else { return }
                            onTaskTap(item)
                        },
                        onToggleComplete: {
                            guard let item = row.item, item.source == .task else { return }
                            onToggleComplete(item)
                        }
                    )
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.opacity(0.82))
                .frame(width: 4)
                .padding(.vertical, 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.54), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .compositingGroup()
        .zIndex(3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(TimelineFormatting.timeRangeText(start: model.startDate, end: model.endDate)), \(model.countLabel)")
        .accessibilityIdentifier("home.timeline.flockBlock")
    }

    var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(TimelineFormatting.timeRangeText(start: model.startDate, end: model.endDate))
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 6)

            Text(model.countLabel)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(accent.opacity(0.16), in: Capsule())
        }
        .frame(height: 24)
    }
}

// MARK: - TimelineFlockRowView

struct TimelineFlockRowView: View {
    let row: TimelineFlockModel.Row
    let visualHeight: CGFloat
    let renderRow: TimelineRenderableRow?
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var item: TimelinePlanItem? { row.item }
    var palette: TimelinePalette { .resolve(from: item?.tintHex) }

    var body: some View {
        Button(action: onTap) {
            rowContent
                .frame(maxWidth: .infinity, minHeight: visualHeight, maxHeight: visualHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let item {
                Button("Open", action: onTap)
                if item.source == .task {
                    Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(row.isSummary ? "Opens the full list." : "Opens the item details.")
    }

    var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            if row.isSummary {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: item?.systemImageName ?? "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.icon)
                    .frame(width: 24, height: 24)
                    .background(palette.fill.opacity(0.9), in: Circle())
                    .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.title)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(row.isCompleted, color: titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(2)

                    trailingStatus
                        .layoutPriority(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(row.isCompleted, color: titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    trailingStatus
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    var trailingStatus: some View {
        if row.isActiveNow {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.lifeboard.statusDanger)
                    .frame(width: 5, height: 5)
                Text("Now")
                    .font(.lifeboard(.meta).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.statusDanger)
            }
            .lineLimit(1)
        } else if row.timeText.isEmpty == false {
            Text(row.timeText)
                .font(.lifeboard(.meta).weight(.medium))
                .foregroundStyle(metaColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    var rowBackground: Color {
        if row.isActiveNow {
            return Color.lifeboard.statusDanger.opacity(0.10)
        }
        return Color.lifeboard.surfacePrimary.opacity(row.isSummary ? 0.42 : 0.72)
    }

    var titleColor: Color {
        guard let renderRow else {
            return row.isSummary ? Color.lifeboard.textSecondary : Color.lifeboard.textPrimary
        }
        return timelineTitleColor(for: renderRow, item: item)
    }

    var metaColor: Color {
        guard let renderRow else { return TimelineVisualTokens.metaText }
        return timelineMetaColor(for: renderRow)
    }

    var accessibilityLabel: String {
        if row.isSummary { return row.title }
        guard let item, let renderRow else { return row.title }
        return timelineAccessibilityLabel(for: renderRow, item: item)
    }

    var accessibilityValue: String {
        if row.isSummary { return "" }
        if row.isCompleted { return "Completed" }
        if row.isActiveNow { return "Now" }
        return item?.source == .calendarEvent ? "Calendar event" : "Scheduled"
    }
}

// MARK: - TimelineShelfItemCard

struct TimelineShelfItemCard: View {
    let item: TimelinePlanItem
    let action: () -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(palette.fill)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: item.systemImageName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.icon)
                            .accessibilityHidden(true)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("All day")
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text(item.title)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2)
                }
            }
            .frame(width: 220, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue("All-day item")
        .accessibilityHint("Opens the item details.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
    }
}

// MARK: - TimelineUtilityItemExtension

extension TimelineUtilityItem {
    var accessibilityLabel: String {
        switch self {
        case .checklist(let summary):
            return "\(summary.completedCount) of \(summary.totalCount) checklist items complete"
        case .note:
            return "Has notes"
        case .recurring:
            return "Recurring"
        case .calendar:
            return "Calendar event"
        case .meeting:
            return "Meeting"
        case .project(let name):
            return name
        }
    }
}

// MARK: - TimelineUtilityRow

struct TimelineUtilityRow: View {
    let items: [TimelineUtilityItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                utilityItemView(entry.element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    func utilityItemView(_ item: TimelineUtilityItem) -> some View {
        switch item {
        case .checklist(let summary):
            Label("\(summary.completedCount)/\(summary.totalCount)", systemImage: "checklist")
                .font(.lifeboard(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.lifeboard.surfaceSecondary, in: Capsule())
        case .note:
            utilityGlyph("note.text")
        case .recurring:
            utilityGlyph("repeat")
        case .calendar:
            utilityGlyph("calendar")
        case .meeting:
            utilityGlyph("video")
        case .project(let name):
            Label(name, systemImage: "line.3.horizontal.decrease.circle")
                .font(.lifeboard(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .lineLimit(1)
        }
    }

    func utilityGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TimelineVisualTokens.utilityText)
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}

// MARK: - TimelineInboxPlanningCard

struct TimelineInboxPlanningCard: View {
    let inboxItems: [TimelinePlanItem]
    let onTaskTap: (TimelinePlanItem) -> Void

    var body: some View {
        let style = ClayColorTokens.role(.assistant)
        GlassCard(
            cornerRadius: RadiusTokens.card,
            borderColor: style.border.opacity(0.78),
            fill: style.softSurface.opacity(0.56),
            shadow: nil,
            usesMaterialBackground: false
        ) {
            VStack(alignment: .leading, spacing: ClayLayoutMetrics.sm) {
                HStack(alignment: .top, spacing: ClayLayoutMetrics.sm) {
                    Image(systemName: "tray.full")
                        .font(ClayTypography.bodyStrong)
                        .foregroundStyle(style.deep)
                        .frame(width: 34, height: 34)
                        .background(style.softSurface.opacity(0.82), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(inboxItems.count == 1 ? "1 inbox task ready" : "\(inboxItems.count) inbox tasks ready")
                            .font(ClayTypography.meta)
                            .foregroundStyle(ClayColorTokens.navyMuted)
                        Text("Inbox waiting for placement")
                            .font(ClayTypography.cardTitle)
                            .foregroundStyle(ClayColorTokens.navy)
                        Text("Day Compass will offer a placement pass when enough unscheduled work needs a home.")
                            .font(ClayTypography.body)
                            .foregroundStyle(ClayColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(inboxItems.prefix(4)) { item in
                            Button {
                                onTaskTap(item)
                            } label: {
                                Text(item.title)
                                    .font(ClayTypography.meta)
                                    .foregroundStyle(ClayColorTokens.navy)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(ClayColorTokens.glassStrong.opacity(0.72), in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(ClayColorTokens.hairline.opacity(0.7), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        if inboxItems.count > 4 {
                            Text("+\(inboxItems.count - 4) more")
                                .font(ClayTypography.meta)
                                .foregroundStyle(ClayColorTokens.navyMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(ClayColorTokens.glassStrong.opacity(0.72), in: Capsule())
                                .accessibilityLabel("\(inboxItems.count - 4) more inbox tasks")
                        }
                    }
                    .padding(.trailing, 4)
                }
                .accessibilityLabel("Inbox task previews")
                .accessibilityHint(inboxItems.count > 4 ? "Scroll horizontally to inspect more inbox tasks." : "Swipe through inbox tasks to inspect them.")
            }
            .padding(ClayLayoutMetrics.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.timeline.inboxShelf")
    }
}
