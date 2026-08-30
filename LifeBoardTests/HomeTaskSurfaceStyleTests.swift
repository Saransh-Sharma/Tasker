import XCTest
@testable import LifeBoard

@MainActor
final class HomeTaskSurfaceStyleTests: XCTestCase {
    func testEdgeToEdgeHomeLayoutUsesFlatTaskRowsAndNoTaskInset() {
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskContentHorizontalInset, 0)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.rowSpacing, 0)
        XCTAssertTrue(TaskListLayoutStyle.edgeToEdgeHome.showsRowDividers)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.headerHorizontalPadding, Theme.Spacing.md)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskChromeStyle, .flatHomeList)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskMetadataPolicy, .homeUnifiedList)
    }

    func testInsetLayoutPreservesCardRowsAndDefaultMetadata() {
        XCTAssertEqual(TaskListLayoutStyle.inset.taskContentHorizontalInset, Theme.Spacing.lg)
        XCTAssertEqual(TaskListLayoutStyle.inset.supportingContentHorizontalInset, Theme.Spacing.lg)
        XCTAssertEqual(TaskListLayoutStyle.inset.rowSpacing, Theme.Spacing.xs)
        XCTAssertFalse(TaskListLayoutStyle.inset.showsRowDividers)
        XCTAssertEqual(TaskListLayoutStyle.inset.taskChromeStyle, .card)
        XCTAssertEqual(TaskListLayoutStyle.inset.taskMetadataPolicy, .default)
    }

    func testSunriseTaskRowViewDefaultsToCardChromeAndDefaultMetadataPolicy() {
        let view = TaskRowView(
            task: TaskDefinition(title: "Review roadmap"),
            showTypeBadge: false,
            isTaskDragEnabled: false
        )

        XCTAssertEqual(view.chromeStyle, .card)
        XCTAssertEqual(view.metadataPolicy, .default)
    }

    func testAdaptiveHomeUsesOpenSectionsAndCanonicalProjection() throws {
        let source = try loadWorkspaceFile("LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift")

        XCTAssertTrue(source.contains("struct AdaptiveHome: View"))
        XCTAssertTrue(source.contains("ScrollView"))
        XCTAssertTrue(source.contains("HomeProjectionCoordinator"))
        XCTAssertTrue(source.contains("placementSection("))
    }

    func testEvaKeepsOrdinaryRepliesOpenAndCardsOnlyForStructuredPayloads() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Eva/Views/Chat/Conversation/MessageView+AssistantAndUserBubble.swift")
        let plainReply = try XCTUnwrap(source.range(of: "// Ordinary Eva prose is a reading surface, not a card."))
        let structuredPayload = try XCTUnwrap(source.range(of: "assistantCardView(payload: payload)"))

        XCTAssertLessThan(structuredPayload.lowerBound, plainReply.lowerBound)
        let openReplyTail = source[plainReply.lowerBound...]
        XCTAssertFalse(openReplyTail.prefix(700).contains("lifeboardPremiumSurface"))
    }

    func testHomeBackgroundUsesPlainCanvasWithoutAnimatedGradient() throws {
        let homeSource = try loadWorkspaceFile("LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift")

        XCTAssertTrue(homeSource.contains("ScenicBackdrop("))
        XCTAssertFalse(homeSource.contains("HomeDynamicGradientBackdrop"))
    }

    func testHomeListViewsThreadLayoutStyleIntoTaskRows() throws {
        let taskListSource = try loadWorkspaceFile("LifeBoard/Features/Tasks/UI/TaskListView.swift")
        let taskSectionSource = try loadWorkspaceFile("LifeBoard/Features/Tasks/UI/TaskSectionView.swift")

        XCTAssertTrue(taskListSource.contains("taskChromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskListSource.contains("taskMetadataPolicy: layoutStyle.taskMetadataPolicy"))
        XCTAssertTrue(taskSectionSource.contains("chromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskSectionSource.contains("metadataPolicy: layoutStyle.taskMetadataPolicy"))
    }

    func testHomeListSectionHeadersUseSectionAccentHexWhenAvailable() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Tasks/UI/TaskSectionView.swift")

        XCTAssertTrue(source.contains("guard let accentHex = section.accentHex"))
        XCTAssertTrue(source.contains("HexColor.color(accentHex, fallback: Color.lifeboard.accentPrimary)"))
    }

    func testHomeListSectionRowsUseSharedResolverForPlainSections() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Tasks/UI/TaskSectionView.swift")

        XCTAssertTrue(source.contains("if section.showsHeader, let sectionAccentHex = section.accentHex"))
        XCTAssertTrue(source.contains("HomeTaskTintResolver.rowAccentHex("))
    }

    func testDueTodayAndRescueRowsUseSharedRowTintResolver() throws {
        let taskListSource = try loadWorkspaceFile("LifeBoard/Features/Tasks/UI/TaskListView.swift")

        XCTAssertTrue(taskListSource.contains("HomeTaskTintResolver.rowAccentHex("))
    }

    func testTimelineTintUsesCanonicalHomeTaskTintResolver() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Home/UI/ViewModels/HomeViewModel+Timeline.swift")

        XCTAssertTrue(source.contains("HomeTaskTintResolver.owningSectionAccentHex("))
    }

    func testTimelineTaskMarkerUsesCheckboxSymbolsForTaskState() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Home/UI/Timeline/Surface/TimelineItemCards.swift")

        XCTAssertTrue(source.contains("return item.isComplete ? \"checkmark.square.fill\" : \"square\""))
        XCTAssertTrue(source.contains("guard item.source == .task else { return item.systemImageName }"))
    }

    func testTimelineCompletionControlUsesCheckboxSymbolsForTaskState() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Home/UI/Timeline/Surface/TimelineNowAndMarkers.swift")

        XCTAssertTrue(source.contains("Image(systemName: isCompleted ? \"checkmark.square.fill\" : \"square\")"))
        XCTAssertTrue(source.contains(".frame(width: 44, height: 44)"))
        XCTAssertTrue(source.contains(".accessibilityValue(isCompleted ? \"Completed\" : \"Not completed\")"))
    }

    func testTimelineNormalTaskCardUsesSharedCompletionControl() throws {
        let source = try loadWorkspaceFile("LifeBoard/Features/Home/UI/Timeline/Surface/TimelineItemCards.swift")

        XCTAssertTrue(source.contains("TimelineCompletionRing("))
        XCTAssertTrue(source.contains("isCompleted: item.isComplete"))
        XCTAssertFalse(source.contains("Image(systemName: \"checkmark\")"))
    }

    func testHomeTimelineTaskCardsUseLifeAreaWatermarkAndTintedSurface() throws {
        let normalCardSource = try loadWorkspaceFile("LifeBoard/Features/Home/UI/Timeline/Surface/TimelineItemCards.swift")
        let overlapCardSource = try loadWorkspaceFile("LifeBoard/Features/Home/UI/Timeline/Surface/TimelineGroupCards.swift")

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
