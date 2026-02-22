import XCTest
@testable import To_Do_List

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
        TaskerThemeManager.shared.selectTheme(index: 1)

        XCTAssertEqual(TaskerThemeManager.shared.selectedThemeIndex, 1)
        XCTAssertEqual(TaskerThemeManager.shared.currentTheme.index, 1)
    }

    func testThemeSelectionPersistsToUserDefaultsKey() {
        TaskerThemeManager.shared.selectTheme(index: 2)

        let persisted = UserDefaults.standard.integer(forKey: TaskerTheme.userDefaultsKey)
        XCTAssertEqual(persisted, 2)
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
        XCTAssertEqual(migrated, 1)
        XCTAssertEqual(defaults.integer(forKey: TaskerTheme.userDefaultsKey), 1)
        XCTAssertEqual(defaults.integer(forKey: TaskerThemeManager.themeMigrationKey), TaskerThemeManager.themeMigrationVersion)
    }

    func testLegacyIndexMapCoversOldThemeRangeAndMapsToThreeThemeSet() {
        XCTAssertEqual(TaskerTheme.legacyThemeCount, 28)
        XCTAssertEqual(TaskerTheme.v1ThemeCount, 9)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(0), 0)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(7), 2)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(21), 1)
        XCTAssertEqual(TaskerTheme.migrateLegacyIndex(27), 1)
    }

    func testV1ToV2MappingTableMatchesSpec() {
        let expected: [Int: Int] = [
            0: 0, 1: 1, 2: 0, 3: 1, 4: 2, 5: 0, 6: 0, 7: 1, 8: 1
        ]
        for (input, output) in expected {
            XCTAssertEqual(TaskerTheme.migrateV1ToV2Index(input), output, "Expected \(input) -> \(output)")
        }
    }

    func testMigrationFromVersionOneAppliesNineToThreeRemap() {
        let suiteName = "TaskerThemeManagerTests.v1.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(8, forKey: TaskerTheme.userDefaultsKey)
        defaults.set(1, forKey: TaskerThemeManager.themeMigrationKey)

        let migrated = TaskerThemeManager.migratedPersistedThemeIndex(in: defaults)
        XCTAssertEqual(migrated, 1)
        XCTAssertEqual(defaults.integer(forKey: TaskerTheme.userDefaultsKey), 1)
        XCTAssertEqual(defaults.integer(forKey: TaskerThemeManager.themeMigrationKey), 2)
    }
}
