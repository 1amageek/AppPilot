import Foundation
import CoreGraphics

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

public enum Route: Sendable {
    case APPLE_EVENT
    case AX_ACTION
    case UI_EVENT
}

public enum Policy: Sendable {
    case STAY_HIDDEN
    case UNMINIMIZE(tempMs: Int = 150)
    case BRING_FORE_TEMP(restore: AppID)
}

public enum WaitSpec: Sendable {
    case time(ms: Int)
    case ui_change(window: WindowID, timeoutMs: Int)
}

public struct Point: Sendable {
    public let x: Double
    public let y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum MouseButton: Sendable {
    case left
    case right
    case center
}

public struct App: Sendable {
    public let id: AppID
    public let name: String
    public let bundleIdentifier: String?
    
    public init(id: AppID, name: String, bundleIdentifier: String?) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct Window: Sendable {
    public let id: WindowID
    public let title: String?
    public let frame: CGRect
    public let isMinimized: Bool
    public let app: AppID
    
    public init(id: WindowID, title: String?, frame: CGRect, isMinimized: Bool, app: AppID) {
        self.id = id
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.app = app
    }
}

public typealias PNGData = Data

public struct ActionResult: Sendable {
    public let success: Bool
    public let route: Route
    public let message: String?
    
    public init(success: Bool, route: Route, message: String? = nil) {
        self.success = success
        self.route = route
        self.message = message
    }
}

public enum Gesture: Sendable {
    case scroll(dx: Double, dy: Double)
    case pinch(scale: Double, center: Point)
    case rotate(degrees: Double, center: Point)
    case drag(from: Point, to: Point)
    case swipe(direction: SwipeDirection, distance: Double)
}

public enum SwipeDirection: Sendable {
    case up, down, left, right
}

public struct AXNode: Sendable {
    public let role: String?
    public let title: String?
    public let value: String?
    public let frame: CGRect?
    public let children: [AXNode]
    
    public init(role: String?, title: String?, value: String?, frame: CGRect?, children: [AXNode]) {
        self.role = role
        self.title = title
        self.value = value
        self.frame = frame
        self.children = children
    }
}

public struct AXPath: Sendable {
    public let components: [String]
    
    public init(components: [String]) {
        self.components = components
    }
}

public enum AXAction: String, Sendable {
    case press = "AXPress"
    case cancel = "AXCancel"
    case confirm = "AXConfirm"
    case increment = "AXIncrement"
    case decrement = "AXDecrement"
    case showMenu = "AXShowMenu"
}

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
    
    public struct EventData: Sendable {
        public let description: String
        
        public init(description: String) {
            self.description = description
        }
    }
    
    public let type: EventType
    public let window: WindowID
    public let timestamp: Date
    public let data: EventData?
    
    public init(type: EventType, window: WindowID, timestamp: Date = Date(), data: EventData? = nil) {
        self.type = type
        self.window = window
        self.timestamp = timestamp
        self.data = data
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

public struct AppleEventParameters: Sendable {
    internal let storage: [String: String]
    
    public init(_ dict: [String: String] = [:]) {
        self.storage = dict
    }
    
    public subscript(key: String) -> String? {
        return storage[key]
    }
    
    public var allKeys: [String] {
        return Array(storage.keys)
    }
    
    public func forEach(_ body: (String, String) throws -> Void) rethrows {
        try storage.forEach(body)
    }
}

public struct AppleEventSpec: Sendable {
    public let eventClass: String
    public let eventID: String
    public let parameters: AppleEventParameters?
    
    public init(eventClass: String, eventID: String, parameters: AppleEventParameters? = nil) {
        self.eventClass = eventClass
        self.eventID = eventID
        self.parameters = parameters
    }
}