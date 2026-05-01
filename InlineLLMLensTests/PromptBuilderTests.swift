import XCTest
@testable import InlineLLMLens

final class PromptBuilderTests: XCTestCase {
    private func makeSettings(includeContext: Bool = false) -> SettingsStore {
        let suite = UserDefaults(suiteName: "PromptBuilderTests-\(UUID().uuidString)")!
        let s = SettingsStore(defaults: suite)
        s.includeAppContext = includeContext
        return s
    }

    func testExplainModeIncludesSelectedTextAndSystemPrompt() {
        let settings = makeSettings()
        let builder = PromptBuilder(settings: settings)
        let bundle = ContextBundle(
            selectedText: "contrastive decoding",
            frontmostAppName: "Safari",
            frontmostWindowTitle: nil,
            captureMethod: .accessibility,
            timestamp: Date()
        )

        let messages = builder.buildInitial(bundle: bundle, mode: .explain, customInstruction: nil)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertTrue(messages[0].content.contains("Explain the selected text"))
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertTrue(messages[1].content.contains("contrastive decoding"))
    }

    func testCustomModeMergesInstructionAndSelection() {
        let settings = makeSettings()
        let builder = PromptBuilder(settings: settings)
        let bundle = ContextBundle(
            selectedText: "let x = 5",
            frontmostAppName: nil,
            frontmostWindowTitle: nil,
            captureMethod: .servicesInput,
            timestamp: Date()
        )

        let messages = builder.buildInitial(bundle: bundle, mode: .custom, customInstruction: "Why is this immutable?")
        XCTAssertTrue(messages[1].content.contains("Why is this immutable?"))
        XCTAssertTrue(messages[1].content.contains("let x = 5"))
    }

    func testIncludeAppContextAddsWeakContextLine() {
        let settings = makeSettings(includeContext: true)
        let builder = PromptBuilder(settings: settings)
        let bundle = ContextBundle(
            selectedText: "hello",
            frontmostAppName: "Safari",
            frontmostWindowTitle: "Some Article",
            captureMethod: .accessibility,
            timestamp: Date()
        )
        let messages = builder.buildInitial(bundle: bundle, mode: .explain, customInstruction: nil)
        XCTAssertTrue(messages[0].content.contains("Frontmost app: Safari"))
        XCTAssertTrue(messages[0].content.contains("Window title: Some Article"))
    }

    func testFollowUpAppendsUserMessage() {
        let settings = makeSettings()
        let builder = PromptBuilder(settings: settings)
        let initial: [ChatMessage] = [
            .init(role: .system, content: "sys"),
            .init(role: .user, content: "first"),
            .init(role: .assistant, content: "answer")
        ]
        let next = builder.appendFollowUp(messages: initial, userInput: "follow")
        XCTAssertEqual(next.count, 4)
        XCTAssertEqual(next.last?.role, .user)
        XCTAssertEqual(next.last?.content, "follow")
    }
}
