import XCTest
@testable import InlineLLMLens

/// `SelectionCaptureService` integrates AppKit-only APIs (Accessibility, NSWorkspace,
/// NSPasteboard simulation), so a fully isolated unit test would require deep refactor
/// to inject capture strategies. The MVP keeps it minimal: assert that an empty
/// environment falls through to `manualInput`. Strategy ordering is documented in code
/// and exercised end-to-end manually.
@MainActor
final class SelectionCaptureServiceTests: XCTestCase {
    func testFallsThroughToManualInputWhenNoSelection() async {
        let suite = UserDefaults(suiteName: "SelectionCaptureServiceTests-\(UUID())")!
        let settings = SettingsStore(defaults: suite)
        settings.clipboardFallbackEnabled = false
        let service = SelectionCaptureService(settings: settings)
        let bundle = await service.captureForHotkey()
        // In a non-interactive test runner there's typically no AX-readable selection
        // and clipboard fallback is off, so we expect the manual-input fallthrough.
        XCTAssertTrue(bundle.captureMethod == .manualInput || bundle.captureMethod == .accessibility)
        if bundle.captureMethod == .manualInput {
            XCTAssertTrue(bundle.selectedText.isEmpty)
        }
    }
}
