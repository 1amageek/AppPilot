import Foundation

public enum PilotError: Error, Sendable {
    case PERMISSION_DENIED(PermissionKind)
    case NOT_FOUND(EntityKind, String?)
    case ROUTE_UNAVAILABLE(String)
    case VISIBILITY_REQUIRED(String)
    case USER_INTERRUPTED
    case STREAM_OVERFLOW
    case OS_FAILURE(api: String, status: Int32)
    case INVALID_ARG(String)
    case TIMEOUT(ms: Int)
}

public enum PermissionKind: String, Sendable {
    case accessibility = "Accessibility"
    case screenRecording = "Screen Recording"
    case appleEvents = "Apple Events"
}

public enum EntityKind: String, Sendable {
    case application = "Application"
    case window = "Window"
    case axElement = "AX Element"
}

extension PilotError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .PERMISSION_DENIED(let kind):
            return "Permission denied: \(kind.rawValue) permission required"
        case .NOT_FOUND(let entity, let details):
            if let details = details {
                return "\(entity.rawValue) not found: \(details)"
            } else {
                return "\(entity.rawValue) not found"
            }
        case .ROUTE_UNAVAILABLE(let reason):
            return "All command routes unavailable: \(reason)"
        case .VISIBILITY_REQUIRED(let reason):
            return "Window visibility required: \(reason)"
        case .USER_INTERRUPTED:
            return "Operation interrupted by user activity"
        case .STREAM_OVERFLOW:
            return "Event stream buffer overflow"
        case .OS_FAILURE(let api, let status):
            return "OS API failure: \(api) returned \(status)"
        case .INVALID_ARG(let message):
            return "Invalid argument: \(message)"
        case .TIMEOUT(let ms):
            return "Operation timed out after \(ms)ms"
        }
    }
}