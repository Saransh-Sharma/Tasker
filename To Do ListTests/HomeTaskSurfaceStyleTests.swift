import XCTest
@testable import To_Do_List

@MainActor
final class HomeTaskSurfaceStyleTests: XCTestCase {
    func testEdgeToEdgeHomeLayoutUsesFlatTaskRowsAndNoTaskInset() {
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskContentHorizontalInset, 0)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.rowSpacing, 0)
        XCTAssertTrue(TaskListLayoutStyle.edgeToEdgeHome.showsRowDividers)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.headerHorizontalPadding, TaskerTheme.Spacing.md)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskChromeStyle, .flatHomeList)
        XCTAssertEqual(TaskListLayoutStyle.edgeToEdgeHome.taskMetadataPolicy, .homeUnifiedList)
    }

    func testInsetLayoutPreservesCardRowsAndDefaultMetadata() {
        XCTAssertEqual(TaskListLayoutStyle.inset.taskContentHorizontalInset, TaskerTheme.Spacing.lg)
        XCTAssertEqual(TaskListLayoutStyle.inset.supportingContentHorizontalInset, TaskerTheme.Spacing.lg)
        XCTAssertEqual(TaskListLayoutStyle.inset.rowSpacing, TaskerTheme.Spacing.xs)
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
        let source = try loadWorkspaceFile("To Do List/View/HomeForedropView.swift")

        XCTAssertTrue(source.contains("layoutStyle: .edgeToEdgeHome"))
        XCTAssertTrue(source.contains("chromeStyle: .flatHomeList"))
        XCTAssertTrue(source.contains("metadataPolicy: .homeUnifiedList"))
    }

    func testHomeListViewsThreadLayoutStyleIntoTaskRows() throws {
        let taskListSource = try loadWorkspaceFile("To Do List/View/TaskListView.swift")
        let taskSectionSource = try loadWorkspaceFile("To Do List/View/TaskSectionView.swift")

        XCTAssertTrue(taskListSource.contains("taskChromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskListSource.contains("taskMetadataPolicy: layoutStyle.taskMetadataPolicy"))
        XCTAssertTrue(taskSectionSource.contains("chromeStyle: layoutStyle.taskChromeStyle"))
        XCTAssertTrue(taskSectionSource.contains("metadataPolicy: layoutStyle.taskMetadataPolicy"))
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}
