import Foundation
import Combine

/// Persists the user's `[PromptPreset]` and the chosen default. Mirrors
/// `ModelStore`: JSON file in Application Support, default ID in UserDefaults.
@MainActor
final class PromptPresetStore: ObservableObject {
    @Published private(set) var presets: [PromptPreset] = []
    @Published var defaultPresetID: UUID?

    private let fileURL: URL
    private let defaults: UserDefaults
    private let defaultsKey = "InlineLLMLens.defaultPresetID"

    init(fileURL: URL? = nil, defaults: UserDefaults = .standard, seedIfEmpty: Bool = true) {
        self.defaults = defaults
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = (support ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("InlineLLMLens", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("prompts.json")
        }
        load()
        if let raw = defaults.string(forKey: defaultsKey), let id = UUID(uuidString: raw) {
            defaultPresetID = id
        }
        if presets.isEmpty && seedIfEmpty {
            let seed = PromptPreset.seed
            presets = [seed]
            defaultPresetID = seed.id
            defaults.set(seed.id.uuidString, forKey: defaultsKey)
            save()
        }
        if defaultPresetID == nil {
            defaultPresetID = presets.first?.id
        }
    }

    var defaultPreset: PromptPreset? {
        presets.first(where: { $0.id == defaultPresetID }) ?? presets.first
    }

    var sortedPresets: [PromptPreset] {
        presets.sorted { ($0.sortOrder, $0.name.lowercased()) < ($1.sortOrder, $1.name.lowercased()) }
    }

    var pinnedPresets: [PromptPreset] {
        sortedPresets.filter { $0.pinnedInDropdown }
    }

    func add(_ preset: PromptPreset) {
        var p = preset
        if p.sortOrder == 0 {
            p.sortOrder = (presets.map { $0.sortOrder }.max() ?? 0) + 1
        }
        presets.append(p)
        if defaultPresetID == nil { setDefault(p.id) }
        save()
    }

    func update(_ preset: PromptPreset) {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[idx] = preset
        save()
    }

    func delete(id: UUID) {
        presets.removeAll { $0.id == id }
        if defaultPresetID == id { defaultPresetID = presets.first?.id }
        if let id = defaultPresetID {
            defaults.set(id.uuidString, forKey: defaultsKey)
        } else {
            defaults.removeObject(forKey: defaultsKey)
        }
        save()
    }

    func setDefault(_ id: UUID) {
        defaultPresetID = id
        defaults.set(id.uuidString, forKey: defaultsKey)
    }

    func move(from source: IndexSet, to destination: Int) {
        var sorted = sortedPresets
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, p) in sorted.enumerated() {
            if let idx = presets.firstIndex(where: { $0.id == p.id }) {
                presets[idx].sortOrder = i
            }
        }
        save()
    }

    func preset(byID id: UUID?) -> PromptPreset? {
        guard let id else { return nil }
        return presets.first(where: { $0.id == id })
    }

    // MARK: - Import / export

    /// Encode a single preset (or all of them) for sharing. Decoded payloads are
    /// either `PromptPreset` or `[PromptPreset]`.
    func exportBundle() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(presets)
    }

    func exportSingle(_ preset: PromptPreset) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(preset)
    }

    /// Imports presets from a JSON payload (single object or array). New UUIDs
    /// are assigned to avoid collisions with existing presets, and hotkey
    /// bindings are intentionally not carried over (the importer can rebind).
    @discardableResult
    func importBundle(_ data: Data) throws -> [PromptPreset] {
        let decoder = JSONDecoder()
        let imported: [PromptPreset]
        if let arr = try? decoder.decode([PromptPreset].self, from: data) {
            imported = arr
        } else if let one = try? decoder.decode(PromptPreset.self, from: data) {
            imported = [one]
        } else {
            throw NSError(domain: "PromptPresetStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is not a valid prompt preset JSON."])
        }
        var added: [PromptPreset] = []
        for p in imported {
            var copy = p
            copy.id = UUID()
            copy.sortOrder = (presets.map { $0.sortOrder }.max() ?? 0) + 1
            presets.append(copy)
            added.append(copy)
        }
        save()
        return added
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PromptPreset].self, from: data) else {
            return
        }
        presets = decoded
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(presets)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            AppLogger.shared.error("Failed to persist prompt presets: \(error.localizedDescription)")
        }
    }
}
