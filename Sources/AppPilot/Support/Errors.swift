import Foundation
import AXUI

public enum PilotError: Error, Sendable {
    case permissionDenied(String)
    case applicationNotFound(String)
    case windowNotFound(WindowHandle)
    case elementNotFound(role: String, title: String?)
    case elementNotAccessible(String)
    case multipleElementsFound(role: String, title: String?, count: Int)
    case eventCreationFailed
    case coordinateOutOfBounds(Point)
    case timeout(TimeInterval)
    case osFailure(api: String, code: Int32)
    case accessibilityTreeUnavailable(WindowHandle)
    case streamOverflow
    case userInterrupted
    case invalidArgument(String)
    case screenCaptureError(String)
    case imageConversionFailed
    case cgWindowIDMismatch(ax: UInt32?, sck: UInt32?)
    case cgWindowIDUnavailable(WindowHandle)
}

extension PilotError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let description):
            return "Permission denied: \(description)"
        case .applicationNotFound(let identifier):
            return "Application not found: \(identifier)"
        case .windowNotFound(let windowHandle):
            return "Window not found: \(windowHandle.id)"
        case .elementNotFound(let role, let title):
            if let title = title {
                return "UI element not found: \(role) with title '\(title)'"
            } else {
                return "UI element not found: \(role)"
            }
        case .elementNotAccessible(let elementId):
            return "UI element not accessible or disabled: \(elementId)"
        case .multipleElementsFound(let role, let title, let count):
            if let title = title {
                return "Multiple elements found (\(count)): \(role) with title '\(title)'. Use more specific criteria."
            } else {
                return "Multiple elements found (\(count)): \(role). Use more specific criteria."
            }
        case .eventCreationFailed:
            return "Failed to create CGEvent"
        case .coordinateOutOfBounds(let point):
            return "Coordinates out of bounds: (\(point.x), \(point.y))"
        case .timeout(let seconds):
            return "Operation timed out after \(seconds) seconds"
        case .osFailure(let api, let code):
            return "OS API failure: \(api) returned error code \(code)"
        case .accessibilityTreeUnavailable(let windowHandle):
            return "Accessibility tree unavailable for window: \(windowHandle.id)"
        case .streamOverflow:
            return "Event stream buffer overflow"
        case .userInterrupted:
            return "Operation interrupted by user activity"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .screenCaptureError(let message):
            return "Screen capture error: \(message)"
        case .imageConversionFailed:
            return "Failed to convert image to PNG data"
        case .cgWindowIDMismatch(let ax, let sck):
            let axStr = ax.map(String.init) ?? "nil"
            let sckStr = sck.map(String.init) ?? "nil"
            return "CGWindowID mismatch between AccessibilityDriver (\(axStr)) and ScreenCaptureKit (\(sckStr))"
        case .cgWindowIDUnavailable(let windowHandle):
            return "CGWindowID unavailable for window: \(windowHandle.id)"
        }
    }
}

