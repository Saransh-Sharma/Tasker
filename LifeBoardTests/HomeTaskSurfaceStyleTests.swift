import XCTest
@testable import LifeBoard

@MainActor
final class HomeTaskSurfaceStyleTests: XCTestCase {
    func testEdgeToEdgeHomeLayoutUsesFlatTaskRowsAndNoTaskInset() {
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskContentHorizontalInset, 0)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.rowSpacing, 0)
        XCTAssertTrue(TaskListLayoutStyle.edgeToEdgeHome.showsRowDividers)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.headerHorizontalPadding, LifeBoardTheme.Spacing.md)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskChromeStyle, .flatHomeList)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskMetadataPolicy, .homeUnifiedList)
    }

    func testInsetLayoutPreservesCardRowsAndDefaultMetadata() {
        XCTAssertEqual(TaskListLayoutStyle.inset.taskContentHorizontalInset, LifeBoardTheme.Spacing.lg)
        XCTAssertEqual(TaskListLayoutStyle.inset.supportingContentHorizontalInset, LifeBoardTheme.Spacing.lg)
        XCTAssertEqual(TaskListLayoutStyle.inset.rowSpacing, LifeBoardTheme.Spacing.xs)
        XCTAssertFalse(TaskListLayoutStyle.inset.showsRowDividers)
        XCTAssertEqual(TaskListLayoutStyle.inset.taskChromeStyle, .card)
        XCTAssertEqual(TaskListLayoutStyle.inset.taskMetadataPolicy, .default)
    }

    func testSunriseTaskRowViewDefaultsToCardChromeAndDefaultMetadataPolicy() {
        let view = SunriseTaskRowView(
            task: TaskDefinition(title: "Review roadmap"),
            showTypeBadge: false,
            isTaskDragEnabled: false
        )

        XCTAssertEqual(view.chromeStyle, .card)
        XCTAssertEqual(view.metadataPolicy, .default)
    }

    func testHomeSunriseUsesEdgeToEdgeTaskSurfaceConfiguration() throws {
        let searchSource = try loadWorkspaceFile("LifeBoard/Presentation/Home/Shell/SunriseAppShell/SunriseAppShellView+FacesAndSearchChat.swift")
        let agendaSource = try loadWorkspaceFile("LifeBoard/Presentation/Home/Shell/SunriseAppShell/SunriseAppShellView+HabitsAgendaAndFocusStrip.swift")

        XCTAssertTrue(searchSource.contains("layoutStyle: .edgeToEdgeHome"))
        XCTAssertTrue(agendaSource.contains("chromeStyle: .flatHomeList"))
        XCTAssertTrue(agendaSource.contains("metadataPolicy: .homeUnifiedList"))
    }

    func testHomeBackgroundUsesPlainCanvasWithoutAnimatedGradient() throws {
        let appShellSource = try loadWorkspaceFile("LifeBoard/View/SunriseAppShellView.swift")
        let homeScreenSource = try loadWorkspaceFile("LifeBoard/LifeBoardDesign/SunriseHomeScreen.swift")
        let bezelSource = try loadWorkspaceFile("LifeBoard/DesignSystem/LifeBoardCTABezel.swift")

        XCTAssertTrue(homeScreenSource.contains("Color.lifeboard.bgCanvas"))
        XCTAssertFalse(appShellSource.contains("HomeDynamicGradientBackdrop"))
        XCTAssertFalse(homeScreenSource.contains("HomeDynamicGradientBackdrop"))
        XCTAssertFalse(bezelSource.contains("LifeBoardNoisyGradientBackdrop"))
        XCTAssertFalse(bezelSource.contains("LifeBoardNoisyGradient"))
    }

    func testHomeListViewsThreadLayoutStyleIntoTaskRows() throws {
        let taskListSource = try loadWorkspaceFile("LifeBoard/View/SunriseTaskListView.swift")
        let taskSectionSource = try loadWorkspaceFile("LifeBoard/View/SunriseTaskSectionView.swift")

        XCTAssertTrue(taskListSource.contains("taskChromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskListSource.contains("taskMetadataPolicy: layoutStyle.taskMetadataPolicy"))
        XCTAssertTrue(taskSectionSource.contains("chromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskSectionSource.contains("metadataPolicy: layoutStyle.taskMetadataPolicy"))
    }

    func testHomeListSectionHeadersUseSectionAccentHexWhenAvailable() throws {
        let source = try loadWorkspaceFile("LifeBoard/View/SunriseTaskSectionView.swift")

        XCTAssertTrue(source.contains("guard let accentHex = section.accentHex"))
        XCTAssertTrue(source.contains("LifeBoardHexColor.color(accentHex, fallback: Color.lifeboard.accentPrimary)"))
    }

    func testHomeListSectionRowsUseSharedResolverForPlainSections() throws {
        let source = try loadWorkspaceFile("LifeBoard/View/SunriseTaskSectionView.swift")

        XCTAssertTrue(source.contains("if section.showsHeader, let sectionAccentHex = section.accentHex"))
        XCTAssertTrue(source.contains("HomeTaskTintResolver.rowAccentHex("))
    }

    func testDueTodayAndRescueRowsUseSharedRowTintResolver() throws {
        let taskListSource = try loadWorkspaceFile("LifeBoard/View/SunriseTaskListView.swift")
        let agendaSource = try loadWorkspaceFile("LifeBoard/Presentation/Home/Shell/SunriseAppShell/SunriseAppShellView+HabitsAgendaAndFocusStrip.swift")

        XCTAssertTrue(taskListSource.contains("HomeTaskTintResolver.rowAccentHex("))
        XCTAssertTrue(agendaSource.contains("HomeTaskTintResolver.rowAccentHex("))
    }

    func testTimelineTintUsesCanonicalHomeTaskTintResolver() throws {
        let source = try loadWorkspaceFile("LifeBoard/Presentation/ViewModels/HomeViewModel+Timeline.swift")

        XCTAssertTrue(source.contains("HomeTaskTintResolver.owningSectionAccentHex("))
    }

    func testTimelineTaskMarkerUsesCheckboxSymbolsForTaskState() throws {
        let source = try loadWorkspaceFile("LifeBoard/Presentation/Home/Timeline/Surface/TimelineTaskMarkerRow.swift")

        XCTAssertTrue(source.contains("return item.isComplete ? \"checkmark.square.fill\" : \"square\""))
        XCTAssertTrue(source.contains("guard item.source == .task else { return item.systemImageName }"))
    }

    func testTimelineCompletionControlUsesCheckboxSymbolsForTaskState() throws {
        let source = try loadWorkspaceFile("LifeBoard/Presentation/Home/Timeline/Surface/TimelineCompletionRing.swift")

        XCTAssertTrue(source.contains("Image(systemName: isCompleted ? \"checkmark.square.fill\" : \"square\")"))
        XCTAssertTrue(source.contains(".frame(width: 44, height: 44)"))
        XCTAssertTrue(source.contains(".accessibilityValue(isCompleted ? \"Completed\" : \"Not completed\")"))
    }

    func testTimelineNormalTaskCardUsesSharedCompletionControl() throws {
        let source = try loadWorkspaceFile("LifeBoard/Presentation/Home/Timeline/Surface/TimelineNormalItemCard.swift")

        XCTAssertTrue(source.contains("TimelineCompletionRing("))
        XCTAssertTrue(source.contains("isCompleted: item.isComplete"))
        XCTAssertFalse(source.contains("Image(systemName: \"checkmark\")"))
    }

    func testHomeTimelineTaskCardsUseLifeAreaWatermarkAndTintedSurface() throws {
        let normalCardSource = try loadWorkspaceFile("LifeBoard/Presentation/Home/Timeline/Surface/TimelineNormalItemCard.swift")
        let overlapCardSource = try loadWorkspaceFile("LifeBoard/Presentation/Home/Timeline/Surface/TimelineOverlapItemCard.swift")

        XCTAssertTrue(normalCardSource.contains("item.lifeAreaSystemImageName"))
        XCTAssertTrue(normalCardSource.contains("palette.base.opacity(0.12)"))
        XCTAssertTrue(normalCardSource.contains(".symbolRenderingMode(.hierarchical)"))
        XCTAssertTrue(normalCardSource.contains(".accessibilityHidden(true)"))

        XCTAssertTrue(overlapCardSource.contains("item.lifeAreaSystemImageName"))
        XCTAssertTrue(overlapCardSource.contains("palette.base.opacity(0.12)"))
        XCTAssertTrue(overlapCardSource.contains(".symbolRenderingMode(.hierarchical)"))
        XCTAssertTrue(overlapCardSource.contains(".accessibilityHidden(true)"))
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}
