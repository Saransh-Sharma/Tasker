import XCTest
@testable import To_Do_List

final class LLMPersonalMemoryStoreTests: XCTestCase {
    func testNormalizationDropsWhitespaceOnlyEntries() {
        let entries = [
            LLMPersonalMemoryEntry(text: "  "),
            LLMPersonalMemoryEntry(text: "  Keep coffee after lunch  "),
            LLMPersonalMemoryEntry(text: "\n\t")
        ]

        let normalized = LLMPersonalMemoryStoreV1.normalized(entries)

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.text, "Keep coffee after lunch")
    }

    func testLegacyDefaultsStoreMigratesIntoSecureStorage() throws {
        let suiteName = "LLMPersonalMemoryStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let secureStore = LLMSecureBlobStore(
            service: "LLMPersonalMemoryStoreTests.\(UUID().uuidString)",
            account: LLMPersonalMemoryDefaultsStore.key
        )
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            secureStore.clear()
        }

        let legacyStore = LLMPersonalMemoryStoreV1(
            preferences: [LLMPersonalMemoryEntry(text: "Prefers short answers")]
        )
        let legacyData = try JSONEncoder().encode(legacyStore)
        defaults.set(legacyData, forKey: LLMPersonalMemoryDefaultsStore.key)

        let migrated = LLMPersonalMemoryDefaultsStore.load(defaults: defaults, secureStore: secureStore)

        XCTAssertEqual(migrated, legacyStore)
        XCTAssertNil(defaults.data(forKey: LLMPersonalMemoryDefaultsStore.key))
        XCTAssertEqual(secureStore.loadData(), legacyData)
    }
}
