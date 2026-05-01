import Foundation

enum CaptureMethod: String, Codable {
    case servicesInput
    case accessibility
    case clipboardFallback
    case manualInput
}
