import Foundation

public enum PilotError: Error, Sendable {
    case permissionDenied(String)
    case windowNotFound(WindowID)
    case applicationNotFound(AppID)
    case eventCreationFailed
    case coordinateOutOfBounds(Point)
    case timeout(TimeInterval)
    case osFailure(api: String, code: Int32)
    case streamOverflow
    case userInterrupted
    case invalidArgument(String)
}

extension PilotError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let description):
            return "Permission denied: \(description)"
        case .windowNotFound(let windowID):
            return "Window not found: ID \(windowID.id)"
        case .applicationNotFound(let appID):
            return "Application not found: PID \(appID.pid)"
        case .eventCreationFailed:
            return "Failed to create CGEvent"
        case .coordinateOutOfBounds(let point):
            return "Coordinates out of bounds: (\(point.x), \(point.y))"
        case .timeout(let seconds):
            return "Operation timed out after \(seconds) seconds"
        case .osFailure(let api, let code):
            return "OS API failure: \(api) returned error code \(code)"
        case .streamOverflow:
            return "Event stream buffer overflow"
        case .userInterrupted:
            return "Operation interrupted by user activity"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        }
    }
}

