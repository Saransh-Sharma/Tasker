import SwiftUI

/// Uses the native card body and presentation assets with isolated sample data.
struct HomeCardSamplePreview: View {
    let descriptor: DashboardWidgetDescriptor
    let preset: WidgetSizePreset
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var effectivePreset: WidgetSizePreset {
        dynamicTypeSize.isAccessibilitySize ? .wide : preset
    }

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: .morning, colorScheme: colorScheme)
        Group {
            if effectivePreset == .compact {
                HomeGlanceCardContent(
                    title: HomeCardPresentationStyle.glanceTitle(for: descriptor.kind, fallback: descriptor.title),
                    summary: HomeCardPreviewFixtures.snapshot(for: descriptor.kind).value ?? "",
                    symbol: descriptor.systemImage,
                    palette: palette
                )
                .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .care || descriptor.kind == .routines {
                let isCare = descriptor.kind == .care
                HomeActionQueueCardContent(
                    title: isCare ? "Morning care" : "Morning routines", symbol: descriptor.systemImage,
                    rows: isCare ? HomeCardPreviewFixtures.careRows : HomeCardPreviewFixtures.routineRows,
                    limit: HomeCardPresentationStyle(kind: descriptor.kind, preset: effectivePreset).rowLimit(),
                    statusMessage: nil, statusSymbol: "checkmark.circle",
                    actionTitle: isCare ? "Open Care" : "View morning routines",
                    identifier: isCare ? "care" : "routines", palette: palette, titleIsAction: !isCare
                )
                .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .focusNow && effectivePreset != .standard {
                HomeFocusCardContent(title: "Focus Now", primary: "Sketch the first draft", reason: "A quiet 25-minute focus block",
                    symbol: "scope", actionTitle: "Start", actionHint: "", preset: effectivePreset, palette: palette)
                    .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .lifeSnapshot && effectivePreset != .standard {
                HomeLifeSnapshotCardContent(mood: "Check in", moodLabel: "Mood", hydration: "500 ml", lowEnergy: false, palette: palette)
                    .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .progressReflection {
                HomeProgressCardContent(title: "Progress", completionRate: 0.4, openTaskCount: 7, rhythm: "2 of 14 days · 1 day running", palette: palette)
                    .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .fasting && effectivePreset != .standard {
                HomeFastingCardContent(elapsed: nil, finish: "", progress: 0, palette: palette)
                    .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .tasks {
                HomeTasksCardContent(
                    tasks: HomeCardPreviewFixtures.tasks, title: "Today’s tasks", emptyMessage: "No tasks due today",
                    isLoading: false, hasPlanningRepository: true,
                    collapsedLimit: HomeCardPresentationStyle(kind: .tasks, preset: effectivePreset).rowLimit(),
                    isExpanded: false, allowsCompletion: true, completedTask: nil, refreshFailure: nil,
                    palette: palette, dateControls: EmptyView()
                )
                .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .journal {
                HomeJournalCardContent(palette: palette)
                    .modifier(HomeCardIllustratedSurface(
                        style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette
                    ))
            } else if descriptor.kind == .scheduleCapacity {
                HomeCapacityCardContent(
                    title: "Capacity", summary: "1h 30m known room", detail: "Usable capacity 4h", palette: palette
                )
                .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .compactTimeline && effectivePreset != .standard {
                HomeTimelineCardContent(items: HomeCardPreviewFixtures.timeline, palette: palette)
                    .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else if descriptor.kind == .quickCapture && effectivePreset == .wide {
                HomeQuickCaptureCardContent(includesWater: true, palette: palette)
                    .modifier(HomeCardIllustratedSurface(style: .init(kind: descriptor.kind, preset: effectivePreset), palette: palette))
            } else {
                HomeCardBody(
                    snapshot: HomeCardPreviewFixtures.snapshot(for: descriptor.kind),
                    archetype: descriptor.archetype,
                    preset: effectivePreset,
                    palette: palette,
                    title: descriptor.title,
                    symbol: descriptor.systemImage,
                    presentationStyle: .init(kind: descriptor.kind, preset: effectivePreset)
                )
            }
        }
        .frame(minHeight: HomeCardPresentationStyle(kind: descriptor.kind, preset: effectivePreset).minimumHeight)
        .transaction { $0.disablesAnimations = true }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample preview: \(descriptor.title), \(preset.title)")
    }
}
