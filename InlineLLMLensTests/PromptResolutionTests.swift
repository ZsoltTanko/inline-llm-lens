import XCTest
@testable import InlineLLMLens

final class PromptResolutionTests: XCTestCase {
    private let model = ModelConfig(
        displayName: "Test",
        modelName: "test-model",
        baseURL: URL(string: "https://api.example.com/v1")!
    )

    func testExpandsKnownVariables() {
        let out = PromptBuilder.expand(
            template: "Hi {{app}}, look at {{selection}} ({{userInput}})",
            selection: "the cat",
            userInput: "explain",
            app: "Notes",
            windowTitle: ""
        )
        XCTAssertEqual(out, "Hi Notes, look at the cat (explain)")
    }

    func testLeavesUnknownVariablesIntact() {
        let out = PromptBuilder.expand(
            template: "Hello {{nope}}",
            selection: "", userInput: "", app: "", windowTitle: ""
        )
        XCTAssertEqual(out, "Hello {{nope}}")
    }

    func testUnknownVariablesIsReported() {
        let unknowns = PromptBuilder.unknownVariables(in: "{{selection}} {{nope}} {{also_bad}} {{app}}")
        XCTAssertEqual(Set(unknowns), Set(["nope", "also_bad"]))
    }

    func testResolveProducesSnapshotAndMessages() {
        let preset = PromptPreset(
            name: "Translate",
            systemPrompt: "Translate to {{userInput}}",
            requiresUserInput: true,
            temperature: 0.2,
            maxOutputTokens: 256,
            reasoningEffort: "low"
        )
        let bundle = ContextBundle(
            selectedText: "Hello",
            frontmostAppName: "Mail",
            frontmostWindowTitle: nil,
            captureMethod: .accessibility,
            timestamp: Date()
        )
        let (messages, resolution) = PromptBuilder().resolve(
            preset: preset,
            bundle: bundle,
            userInput: "French",
            model: model
        )
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, .system)
        XCTAssertEqual(messages[0].content, "Translate to French")
        XCTAssertEqual(messages[1].role, .user)
        XCTAssertEqual(messages[1].content, "Hello")
        XCTAssertEqual(resolution.systemPrompt, "Translate to French")
        XCTAssertEqual(resolution.userMessage, "Hello")
        XCTAssertEqual(resolution.temperature, 0.2)
        XCTAssertEqual(resolution.maxOutputTokens, 256)
        XCTAssertEqual(resolution.reasoningEffort, "low")
        XCTAssertEqual(resolution.modelDisplayName, "Test")
    }

    func testEffectiveReasoningPrefersPresetThenModel() {
        var modelCopy = model; modelCopy.reasoningEffort = "high"
        var preset = PromptPreset(name: "X", systemPrompt: "Y")
        XCTAssertEqual(PromptBuilder.effectiveReasoningEffort(preset: preset, model: modelCopy), "high")
        preset.reasoningEffort = "minimal"
        XCTAssertEqual(PromptBuilder.effectiveReasoningEffort(preset: preset, model: modelCopy), "minimal")
        preset.reasoningEffort = "  "
        XCTAssertEqual(PromptBuilder.effectiveReasoningEffort(preset: preset, model: modelCopy), "high")
    }
}
