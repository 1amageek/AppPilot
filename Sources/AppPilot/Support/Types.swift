import Foundation
import CoreGraphics

// MARK: - Core Identifiers

public struct AppID: Hashable, Sendable {
    public let pid: pid_t
    
    public init(pid: pid_t) {
        self.pid = pid
    }
}

public struct WindowID: Hashable, Sendable {
    public let id: CGWindowID
    
    public init(id: CGWindowID) {
        self.id = id
    }
}

// MARK: - Geometry

public struct Point: Sendable {
    public let x: CGFloat
    public let y: CGFloat
    
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    public init(x: Double, y: Double) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }
}

// MARK: - Input Types

public enum MouseButton: Sendable {
    case left
    case right
    case center
    
    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }
    
    var downType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .center: return .otherMouseDown
        }
    }
    
    var upType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .center: return .otherMouseUp
        }
    }
    
    var dragType: CGEventType {
        switch self {
        case .left: return .leftMouseDragged
        case .right: return .rightMouseDragged
        case .center: return .otherMouseDragged
        }
    }
}

// MARK: - Wait Specifications

public enum WaitSpec: Sendable {
    case time(seconds: TimeInterval)
    case uiChange(window: WindowID, timeout: TimeInterval)
}

// MARK: - Result Types

public struct ActionResult: Sendable {
    public let success: Bool
    public let timestamp: Date
    public let screenCoordinates: Point?
    
    public init(success: Bool, timestamp: Date = Date(), screenCoordinates: Point? = nil) {
        self.success = success
        self.timestamp = timestamp
        self.screenCoordinates = screenCoordinates
    }
}

// MARK: - Application Info

public struct AppInfo: Sendable {
    public let id: AppID
    public let name: String
    public let bundleIdentifier: String?
    public let isActive: Bool
    
    public init(id: AppID, name: String, bundleIdentifier: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
    }
}

// MARK: - Window Info

public struct WindowInfo: Sendable {
    public let id: WindowID
    public let title: String?
    public let bounds: CGRect  // Screen coordinates
    public let isMinimized: Bool
    public let appName: String
    
    public init(id: WindowID, title: String?, bounds: CGRect, isMinimized: Bool, appName: String) {
        self.id = id
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.appName = appName
    }
}

// MARK: - AX Event Types

public struct AXEvent: Sendable {
    public enum EventType: Sendable {
        case created
        case moved
        case resized
        case titleChanged
        case focusChanged
        case valueChanged
        case overflow
    }
    
    public let type: EventType
    public let windowID: WindowID
    public let timestamp: Date
    public let description: String?
    
    public init(type: EventType, windowID: WindowID, timestamp: Date = Date(), description: String? = nil) {
        self.type = type
        self.windowID = windowID
        self.timestamp = timestamp
        self.description = description
    }
}

public struct AXMask: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let created = AXMask(rawValue: 1 << 0)
    public static let moved = AXMask(rawValue: 1 << 1)
    public static let resized = AXMask(rawValue: 1 << 2)
    public static let titleChanged = AXMask(rawValue: 1 << 3)
    public static let focusChanged = AXMask(rawValue: 1 << 4)
    public static let valueChanged = AXMask(rawValue: 1 << 5)
    
    public static let all: AXMask = [.created, .moved, .resized, .titleChanged, .focusChanged, .valueChanged]
}


public typealias PNGData = Data