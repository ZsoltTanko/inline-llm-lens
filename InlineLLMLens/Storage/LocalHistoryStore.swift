import Foundation

struct LocalHistoryItem: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date
    var selectedText: String
    var responseText: String
    var modelName: String
    var mode: PromptMode
    var appName: String?
}

/// Off by default. When enabled, persists a small JSON list locally.
/// No sync, no analytics.
final class LocalHistoryStore {
    static let shared = LocalHistoryStore()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "InlineLLMLens.history")
    private(set) var items: [LocalHistoryItem] = []

    init() {
        let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = (support ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("InlineLLMLens", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func append(_ item: LocalHistoryItem) {
        queue.async {
            self.items.append(item)
            self.save()
        }
    }

    func clear() {
        queue.async {
            self.items.removeAll()
            self.save()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([LocalHistoryItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
