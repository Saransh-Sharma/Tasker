import SwiftUI

extension DailyTimelineCanvas {
    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    @ViewBuilder
    func canvasBody(now: Date) -> some View {
        let presentation = TimelineDayPresentation(stable: stablePresentation, now: now)
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let railMetrics = TimelineRailMetrics.make(for: layoutClass, surfaceMetrics: metrics, totalWidth: totalWidth)
            let trailingLaneWidth = metrics.expandedTrailingLaneWidth
            let contentInset = metrics.expandedContentInset
            let labelRightX = railMetrics.labelLeadingX + railMetrics.labelWidth + railMetrics.timeToSpineGap
            let streamLane = TimelineStreamGeometry.laneMetrics(
                totalWidth: totalWidth,
                labelRightX: labelRightX,
                trailingReservedWidth: trailingLaneWidth + contentInset,
                layoutClass: layoutClass
            )
            let spineCenterX = streamLane.centerX
            let contentX = streamLane.contentX
            let contentWidth = max(totalWidth - contentX - trailingLaneWidth - contentInset, 140)
            let completionX = totalWidth - (trailingLaneWidth / 2)
            let currentY = currentBoundaryY(now: now)
            let streamGeometry = TimelineStreamGeometry.make(
                plan: plan,
                baseX: spineCenterX,
                laneHalfWidth: max(streamLane.halfWidth - 4, 1)
            )

            ZStack(alignment: .topLeading) {
                timeLabelLayer(
                    presentation: presentation,
                    railMetrics: railMetrics,
                    currentY: currentY
                )
                .zIndex(4)

                CurvingDayStreamView(
                    geometry: streamGeometry,
                    currentY: currentY
                )
                    .frame(width: totalWidth, height: plan.contentHeight)
                    .zIndex(1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                ForEach(plan.longGapIndicators) { indicator in
                    TimelineLongGapIndicator(text: indicator.text)
                        .frame(width: contentWidth, height: indicator.height)
                        .offset(x: contentX, y: indicator.y)
                    .zIndex(3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                ForEach(plan.visualElements) { positioned in
                    visualElementView(
                        positioned,
                        presentation: presentation,
                        totalWidth: totalWidth,
                        contentX: contentX,
                        contentWidth: contentWidth,
                        streamGeometry: streamGeometry,
                        completionX: completionX,
                        currentY: currentY
                    )
                }

                if let currentY {
                    TimelineNowBeadView(
                        time: now,
                        railMetrics: railMetrics,
                        beadX: streamGeometry.x(atY: currentY),
                        reduceMotion: reduceMotion
                    )
                    .offset(x: 0, y: TimelineNowBeadPresentation.clampedY(currentY, contentHeight: plan.contentHeight))
                    .zIndex(5)
                }

                TimelineEndAddMarker(
                    suggestedDate: plan.endMarker.suggestedDate,
                    accessibilityValue: plan.endMarker.accessibilityValue
                ) {
                    onAddTask(plan.endMarker.suggestedDate)
                }
                .offset(
                    x: TimelineSpineMounting.centerX(for: streamGeometry, atY: plan.endMarker.centerY)
                        - (TimelineCanvasLayoutPlan.endMarkerHitArea / 2),
                    y: plan.endMarker.centerY - (TimelineCanvasLayoutPlan.endMarkerHitArea / 2)
                )
                .zIndex(3)
            }
        }
        .frame(height: plan.contentHeight)
        .overlay(alignment: .top) {
            if placementCandidate != nil {
                HStack(spacing: 8) {
                    Image(systemName: isCanvasDropTargeted ? "clock.badge.checkmark.fill" : "clock.badge")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isCanvasDropTargeted ? "Release to schedule" : "Drop on a time")
                        .font(.lifeboard(.caption1).weight(.semibold))
                }
                .foregroundStyle(Color.lifeboard.accentPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.lifeboard.accentWash.opacity(isCanvasDropTargeted ? 0.92 : 0.72), in: Capsule())
                .overlay(Capsule().stroke(Color.lifeboard.accentPrimary.opacity(isCanvasDropTargeted ? 0.42 : 0.18), lineWidth: 1))
                .scaleEffect(isCanvasDropTargeted && reduceMotion == false ? 1.035 : 1)
                .padding(.top, 8)
                .accessibilityIdentifier("home.needsReplan.hotZone.timeline")
            }
        }
        .dropDestination(for: String.self, action: { items, location in
            guard let placementCandidate,
                  items.contains(placementCandidate.taskID.uuidString) else {
                return false
            }
            LifeBoardFeedback.success()
            onPlaceReplanAtTime(placementCandidate, plan.date(atY: location.y))
            return true
        }, isTargeted: { newValue in
            isCanvasDropTargeted = newValue
        })
        .onChange(of: isCanvasDropTargeted) { _, newValue in
            guard newValue else { return }
            LifeBoardFeedback.selection()
        }
    }

    func displayedNow(from timelineDate: Date) -> Date {
        Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
    }

    func currentBoundaryY(now: Date) -> CGFloat? {
        plan.currentTimeY(now: now, selectedDate: projection.date)
    }

    func timeLabelLayer(
        presentation: TimelineDayPresentation,
        railMetrics: TimelineRailMetrics,
        currentY: CGFloat?
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(plan.visualElements) { positioned in
                railLabelView(
                    for: positioned,
                    presentation: presentation,
                    railMetrics: railMetrics,
                    currentY: currentY
                )
            }
        }
        .frame(width: railMetrics.labelLayerWidth, height: plan.contentHeight, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    func railLabelView(
        for positioned: TimelineCanvasLayoutPlan.PositionedVisualTimelineElement,
        presentation: TimelineDayPresentation,
        railMetrics: TimelineRailMetrics,
        currentY: CGFloat?
    ) -> some View {
        switch positioned.element {
        case .routineMarker:
            EmptyView()
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            let row = presentation.row(for: model.item)
            TimelineRailLabel(
                text: timeLabel(for: model.item),
                kind: railLabelKind(for: model.item),
                isEmphasized: row.isCurrentRailEmphasis,
                color: row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText,
                metrics: railMetrics
            )
            .offset(y: max(positioned.y - 2, 0))
            .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)
        case .flock(let model):
            let primaryItem = model.block.items.first
            let row = primaryItem.map { presentation.row(for: $0) }
            TimelineRailLabel(
                text: TimelineRailTimeFormatter.railText(forItemStart: model.block.startDate),
                kind: railLabelKind(for: model.block.startDate),
                isEmphasized: row?.isCurrentRailEmphasis == true,
                color: row?.isCurrentRailEmphasis == true ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText,
                metrics: railMetrics
            )
            .offset(y: max(positioned.y - 2, 0))
            .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)
        case .gapPrompt, .emptyState:
            EmptyView()
        }
    }

    @ViewBuilder
    func anchorView(
        _ anchor: TimelineCanvasLayoutPlan.PositionedAnchor,
        row: TimelineRenderableRow,
        streamGeometry: TimelineStreamGeometry,
        totalWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let iconSize = metrics.expandedAnchorCircleSize
        let anchorCenterY = anchor.y
        let railMetrics = TimelineRailMetrics.make(for: layoutClass, surfaceMetrics: metrics, totalWidth: totalWidth)
        let mountedSpineX = TimelineSpineMounting.centerX(for: streamGeometry, atY: anchorCenterY)

        if let style = TimelineRoutineAnchorVisualStyle.resolve(anchorID: anchor.anchor.id, title: anchor.anchor.title, subtitle: row.subtitle) {
            let resolvedHeight = min(cardHeight, max(84, contentWidth / 3))
            let dotSize: CGFloat = 12
            let timeText = TimelineRailTimeFormatter.railText(for: anchor.anchor.time, kind: .exact)

            Circle()
                .fill(style.borderColor)
                .frame(width: dotSize, height: dotSize)
                .overlay {
                    Circle()
                        .stroke(LBColorTokens.whiteStroke.opacity(0.72), lineWidth: 2)
                }
                .offset(x: mountedSpineX - (dotSize / 2), y: anchorCenterY - (dotSize / 2))
                .accessibilityHidden(true)

            TimelineRoutineAnchorCard(
                style: style,
                timeText: timeText,
                onTap: { onAnchorTap(anchor.anchor) },
                minimumHeight: resolvedHeight,
                leadingArtworkReserve: min(max(contentWidth * 0.38, 56), 104),
                accessibilityHint: TimelineAnchorSelection(anchorID: anchor.anchor.id)?.accessibilityHint
            )
            .frame(width: contentWidth, height: resolvedHeight, alignment: .leading)
            .offset(x: contentX, y: max(anchorCenterY - (resolvedHeight / 2), 0))
            .accessibilityIdentifier("home.timeline.anchor.\(anchor.anchor.id)")
        } else {
            let iconTop = max(anchorCenterY - (iconSize / 2), 0)

            Circle()
                .fill(TimelineVisualTokens.anchorCapsuleFill)
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    Image(systemName: anchor.anchor.systemImageName)
                        .font(.system(size: metrics.expandedAnchorIconSize, weight: .semibold))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .accessibilityHidden(true)
                }
                .offset(x: mountedSpineX - (iconSize / 2), y: iconTop)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(anchor.anchor.title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                Text(TimelineRoutineTextFormatter.subtitle(for: anchor.anchor, subtitle: row.subtitle))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .offset(
                x: railMetrics.routineTextLeadingX(iconSize: iconSize, mountedSpineX: mountedSpineX),
                y: max(anchorCenterY - 22, 0)
            )
            .accessibilityHidden(true)

            Button {
                onAnchorTap(anchor.anchor)
            } label: {
                Color.clear
                    .frame(width: totalWidth, height: max(iconSize, 52))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 0, y: max(anchorCenterY - max(iconSize, 52) / 2, 0))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(anchor.anchor.title), \(anchor.anchor.time.formatted(date: .omitted, time: .shortened))")
            .accessibilityValue(anchor.anchor.id == "wake" ? "Timeline start" : "Timeline end")
            .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
        }
    }

    func timelineStem(
        row: TimelineRenderableRow,
        item: TimelinePlanItem,
        spineCenterX: CGFloat,
        y: CGFloat,
        height: CGFloat
    ) -> some View {
        TimelineStemSegments(
            leading: row.stemLeading,
            trailing: row.stemTrailing,
            fallbackPalette: TimelinePalette.resolve(from: item.tintHex),
            width: 2,
            height: height
        )
        .offset(x: spineCenterX - 1, y: y)
        .accessibilityHidden(true)
    }

    func timeLabelView(
        text: String,
        row: TimelineRenderableRow,
        timeGutterWidth: CGFloat,
        y: CGFloat,
        currentY: CGFloat?
    ) -> some View {
        Text(text)
            .font(.system(size: 13, weight: row.isCurrentRailEmphasis ? .semibold : .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(y - 2, 0))
            .opacity(shouldHideTimeLabel(at: y, currentY: currentY) ? 0 : 1)
    }

    @ViewBuilder
    func timelineBlockView(
        _ positioned: TimelineCanvasLayoutPlan.PositionedBlock,
        presentation: TimelineDayPresentation,
        timeGutterWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        spineCenterX: CGFloat,
        completionX: CGFloat,
        currentY: CGFloat?
    ) -> some View {
        switch positioned.block.kind {
        case .single(let item):
            let row = presentation.row(for: item)
            let title = TimelineDenseTitleFormatter.displayTitles(for: [item])[item.id] ?? item.title
            TimelineStemSegments(
                leading: row.stemLeading,
                trailing: row.stemTrailing,
                fallbackPalette: TimelinePalette.resolve(from: item.tintHex),
                width: 2,
                height: positioned.height
            )
            .offset(x: spineCenterX - 1, y: positioned.y)
            .accessibilityHidden(true)

            Text(timeLabel(for: item))
                .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
                .monospacedDigit()
                .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: timeGutterWidth - 8, alignment: .trailing)
                .offset(x: 0, y: max(positioned.y - 2, 0))
                .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)

            TimelineNormalItemCard(
                item: item,
                row: row,
                title: title,
                onTap: { onTaskTap(item) },
                onToggleComplete: {
                    guard item.source == .task else { return }
                    onToggleComplete(item)
                }
            )
            .frame(width: contentWidth, height: min(max(positioned.height, 64), 84), alignment: .leading)
            .offset(x: contentX, y: positioned.y)
        case .conflict:
            let primaryItem = positioned.block.items.first
            TimelineStemSegments(
                leading: primaryItem.map { presentation.row(for: $0).stemLeading } ?? .futureSegment,
                trailing: primaryItem.map { presentation.row(for: $0).stemTrailing } ?? .futureSegment,
                fallbackPalette: TimelinePalette.resolve(from: primaryItem?.tintHex),
                width: 2,
                height: positioned.height
            )
            .offset(x: spineCenterX - 1, y: positioned.y)
            .accessibilityHidden(true)

            Text(positioned.block.startDate.formatted(date: .omitted, time: .shortened))
                .font(.lifeboard(.meta).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(TimelineVisualTokens.metaText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: timeGutterWidth - 8, alignment: .trailing)
                .offset(x: 0, y: max(positioned.y - 2, 0))
                .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)

            TimelineFlockBlock(
                model: TimelineFlockModel(block: positioned.block, now: presentation.now),
                presentation: presentation,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(3)
        }
    }
}
