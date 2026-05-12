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

    func testTaskRowViewDefaultsToCardChromeAndDefaultMetadataPolicy() {
        let view = TaskRowView(
            task: TaskDefinition(title: "Review roadmap"),
            showTypeBadge: false,
            isTaskDragEnabled: false
        )

        XCTAssertEqual(view.chromeStyle, .card)
        XCTAssertEqual(view.metadataPolicy, .default)
    }

    func testHomeForedropUsesEdgeToEdgeTaskSurfaceConfiguration() throws {
        let source = try loadWorkspaceFile("LifeBoard/View/HomeForedropView.swift")

        XCTAssertTrue(source.contains("layoutStyle: .edgeToEdgeHome"))
        XCTAssertTrue(source.contains("chromeStyle: .flatHomeList"))
        XCTAssertTrue(source.contains("metadataPolicy: .homeUnifiedList"))
    }

    func testHomeListViewsThreadLayoutStyleIntoTaskRows() throws {
        let taskListSource = try loadWorkspaceFile("LifeBoard/View/TaskListView.swift")
        let taskSectionSource = try loadWorkspaceFile("LifeBoard/View/TaskSectionView.swift")

        XCTAssertTrue(taskListSource.contains("taskChromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskListSource.contains("taskMetadataPolicy: layoutStyle.taskMetadataPolicy"))
        XCTAssertTrue(taskSectionSource.contains("chromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskSectionSource.contains("metadataPolicy: layoutStyle.taskMetadataPolicy"))
    }

    func testHomeListSectionHeadersUseSectionAccentHexWhenAvailable() throws {
        let source = try loadWorkspaceFile("LifeBoard/View/TaskSectionView.swift")

        XCTAssertTrue(source.contains("guard let accentHex = section.accentHex"))
        XCTAssertTrue(source.contains("LifeBoardHexColor.color(accentHex, fallback: Color.lifeboard.accentPrimary)"))
    }

    func testHomeListSectionRowsUseSharedResolverForPlainSections() throws {
        let source = try loadWorkspaceFile("LifeBoard/View/TaskSectionView.swift")

        XCTAssertTrue(source.contains("if section.showsHeader, let sectionAccentHex = section.accentHex"))
        XCTAssertTrue(source.contains("HomeTaskTintResolver.rowAccentHex("))
    }

    func testDueTodayAndRescueRowsUseSharedRowTintResolver() throws {
        let taskListSource = try loadWorkspaceFile("LifeBoard/View/TaskListView.swift")
        let foredropSource = try loadWorkspaceFile("LifeBoard/View/HomeForedropView.swift")

        XCTAssertTrue(taskListSource.contains("HomeTaskTintResolver.rowAccentHex("))
        XCTAssertTrue(foredropSource.contains("HomeTaskTintResolver.rowAccentHex("))
    }

    func testTimelineTintUsesCanonicalHomeTaskTintResolver() throws {
        let source = try loadWorkspaceFile("LifeBoard/Presentation/ViewModels/HomeViewModel.swift")

        XCTAssertTrue(source.contains("HomeTaskTintResolver.owningSectionAccentHex("))
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}
