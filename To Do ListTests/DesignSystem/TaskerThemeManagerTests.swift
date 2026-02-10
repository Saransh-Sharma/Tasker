import XCTest
@testable import Tasker

@MainActor
final class TaskerThemeManagerTests: XCTestCase {
    private var originalIndex: Int = 0

    override func setUp() {
        super.setUp()
        originalIndex = TaskerThemeManager.shared.selectedThemeIndex
    }

    override func tearDown() {
        TaskerThemeManager.shared.selectTheme(index: originalIndex)
        super.tearDown()
    }

    func testSelectThemeUpdatesCurrentThemeAndIndex() {
        TaskerThemeManager.shared.selectTheme(index: 3)

        XCTAssertEqual(TaskerThemeManager.shared.selectedThemeIndex, 3)
        XCTAssertEqual(TaskerThemeManager.shared.currentTheme.index, 3)
    }

    func testThemeSelectionPersistsToUserDefaultsKey() {
        TaskerThemeManager.shared.selectTheme(index: 5)

        let persisted = UserDefaults.standard.integer(forKey: TaskerTheme.userDefaultsKey)
        XCTAssertEqual(persisted, 5)
    }

    func testInvalidThemeIndexIsClamped() {
        TaskerThemeManager.shared.selectTheme(index: 500)

        XCTAssertEqual(TaskerThemeManager.shared.selectedThemeIndex, TaskerTheme.accentThemes.count - 1)
    }

    func testLegacyThemeIndexMigrationMapsPersistedValue() {
        let suiteName = "TaskerThemeManagerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(24, forKey: TaskerTheme.userDefaultsKey)
        defaults.removeObject(forKey: TaskerThemeManager.themeMigrationKey)

        let migrated = TaskerThemeManager.migratedPersistedThemeIndex(in: defaults)
        XCTAssertEqual(migrated, 8)
        XCTAssertEqual(defaults.integer(forKey: TaskerTheme.userDefaultsKey), 8)
        XCTAssertEqual(defaults.integer(forKey: TaskerThemeManager.themeMigrationKey), TaskerThemeManager.themeMigrationVersion)
    }

    func testLegacyIndexMapCoversOldThemeRange() {
        XCTAssertEqual(TaskerTheme.legacyThemeCount, 28)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(0), 0)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(7), 4)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(21), 7)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(27), 8)
    }
}
