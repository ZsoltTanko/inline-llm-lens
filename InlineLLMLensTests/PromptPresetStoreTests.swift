import XCTest
@testable import InlineLLMLens

@MainActor
final class PromptPresetStoreTests: XCTestCase {
    private func makeStore(seed: Bool = true) -> PromptPresetStore {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("prompts-\(UUID()).json")
        let defaults = UserDefaults(suiteName: "PromptPresetStoreTests-\(UUID().uuidString)")!
        return PromptPresetStore(fileURL: tmp, defaults: defaults, seedIfEmpty: seed)
    }

    func testFirstLaunchSeedsSinglePresetAsDefault() {
        let store = makeStore()
        XCTAssertEqual(store.presets.count, 1)
        XCTAssertEqual(store.defaultPreset?.name, PromptPreset.seed.name)
    }

    func testNoSeedWhenSuppressed() {
        let store = makeStore(seed: false)
        XCTAssertTrue(store.presets.isEmpty)
        XCTAssertNil(store.defaultPresetID)
    }

    func testDeleteMovesDefault() {
        let store = makeStore()
        let extra = PromptPreset(name: "Other", systemPrompt: "X")
        store.add(extra)
        store.setDefault(extra.id)
        store.delete(id: extra.id)
        XCTAssertEqual(store.defaultPresetID, store.presets.first?.id)
    }

    func testPersistsAcrossInstances() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("prompts-\(UUID()).json")
        let defaults = UserDefaults(suiteName: "PromptPresetStorePersist-\(UUID()).json")!
        let s1 = PromptPresetStore(fileURL: url, defaults: defaults)
        s1.add(PromptPreset(name: "Persisted", systemPrompt: "P"))
        let s2 = PromptPresetStore(fileURL: url, defaults: defaults)
        XCTAssertTrue(s2.presets.contains(where: { $0.name == "Persisted" }))
    }

    func testImportAssignsNewIDs() throws {
        let store = makeStore()
        let p = PromptPreset(name: "Imported", systemPrompt: "X")
        let data = try JSONEncoder().encode([p])
        let added = try store.importBundle(data)
        XCTAssertEqual(added.count, 1)
        XCTAssertNotEqual(added.first?.id, p.id)
    }

    func testReorderUpdatesSortOrder() {
        let store = makeStore()
        let a = PromptPreset(name: "A", systemPrompt: "x", sortOrder: 1)
        let b = PromptPreset(name: "B", systemPrompt: "y", sortOrder: 2)
        store.add(a); store.add(b)
        let originalFirst = store.sortedPresets.first?.id
        store.move(from: IndexSet(integer: 0), to: 2)
        XCTAssertNotEqual(store.sortedPresets.first?.id, originalFirst)
    }
}
