import Foundation

struct ChatMessage: Codable, Equatable {
    let role: Role
    let content: String
}

enum Role: String, Codable {
    case system
    case user
    case assistant
}

struct LLMRequest {
    var model: ModelConfig
    var messages: [ChatMessage]
    var temperature: Double?
    var maxTokens: Int?
    var stream: Bool
}
