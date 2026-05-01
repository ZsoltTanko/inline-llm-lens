import Foundation

enum PromptMode: String, Codable, CaseIterable, Identifiable {
    case explain
    case define
    case summarize
    case rewrite
    case translate
    case critique
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .explain: return "Explain"
        case .define: return "Define"
        case .summarize: return "Summarize"
        case .rewrite: return "Rewrite"
        case .translate: return "Translate"
        case .critique: return "Critique"
        case .custom: return "Ask Custom"
        }
    }
}
