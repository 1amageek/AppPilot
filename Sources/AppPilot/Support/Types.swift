import Foundation
import CoreGraphics

// MARK: - Core Identifiers (v3.0 - Handle-based)

public struct AppHandle: Hashable, Sendable, Codable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}

public struct WindowHandle: Hashable, Sendable, Codable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}

// MARK: - Legacy Support (Internal Use)

internal struct AppID: Hashable, Sendable {
    internal let pid: pid_t
    
    internal init(pid: pid_t) {
        self.pid = pid
    }
}

internal struct WindowID: Hashable, Sendable {
    internal let id: CGWindowID
    
    internal init(id: CGWindowID) {
        self.id = id
    }
}

// MARK: - Geometry

public struct Point: Sendable, Equatable {
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

// MARK: - UI Element System (v3.0)

public struct UIElement: Sendable, Codable {
    public let id: String
    public let role: ElementRole
    public let title: String?
    public let value: String?
    public let identifier: String?
    public let bounds: CGRect
    public let isEnabled: Bool
    
    public var centerPoint: Point {
        Point(x: bounds.midX, y: bounds.midY)
    }
    
    public init(
        id: String,
        role: ElementRole,
        title: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        bounds: CGRect,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.value = value
        self.identifier = identifier
        self.bounds = bounds
        self.isEnabled = isEnabled
    }
}

public enum ElementRole: String, Sendable, CaseIterable, Codable {
    case button = "AXButton"
    case textField = "AXTextField"
    case searchField = "AXSearchField"
    case menuItem = "AXMenuItem"
    case menuBar = "AXMenuBar"
    case menuBarItem = "AXMenuBarItem"
    case checkBox = "AXCheckBox"
    case radioButton = "AXRadioButton"
    case link = "AXLink"
    case tab = "AXTab"
    case window = "AXWindow"
    case staticText = "AXStaticText"
    case group = "AXGroup"
    case scrollArea = "AXScrollArea"
    case image = "AXImage"
    case list = "AXList"
    case table = "AXTable"
    case cell = "AXCell"
    case popUpButton = "AXPopUpButton"
    case slider = "AXSlider"
    case unknown = "AXUnknown"
    
    public var isClickable: Bool {
        switch self {
        case .button, .menuItem, .menuBarItem, .checkBox, .radioButton, .link, .tab, .popUpButton:
            return true
        default:
            return false
        }
    }
    
    public var isTextInput: Bool {
        switch self {
        case .textField, .searchField:
            return true
        default:
            return false
        }
    }
}

// MARK: - Wait Specifications (v3.0)

public enum WaitSpec: Sendable {
    case time(seconds: TimeInterval)
    case elementAppear(window: WindowHandle, role: ElementRole, title: String)
    case elementDisappear(window: WindowHandle, role: ElementRole, title: String)
    case uiChange(window: WindowHandle, timeout: TimeInterval)
}

// MARK: - Result Types (v3.0)

public struct ActionResult: Sendable {
    public let success: Bool
    public let timestamp: Date
    public let element: UIElement?
    public let coordinates: Point?
    
    public init(success: Bool, timestamp: Date = Date(), element: UIElement? = nil, coordinates: Point? = nil) {
        self.success = success
        self.timestamp = timestamp
        self.element = element
        self.coordinates = coordinates
    }
}

// MARK: - Application Info (v3.0)

public struct AppInfo: Sendable, Codable {
    public let id: AppHandle
    public let name: String
    public let bundleIdentifier: String?
    public let isActive: Bool
    
    public init(id: AppHandle, name: String, bundleIdentifier: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
    }
}

// MARK: - Window Info (v3.0)

public struct WindowInfo: Sendable, Codable {
    public let id: WindowHandle
    public let title: String?
    public let bounds: CGRect  // Screen coordinates
    public let isVisible: Bool
    public let isMain: Bool
    public let appName: String
    
    public init(id: WindowHandle, title: String?, bounds: CGRect, isVisible: Bool, isMain: Bool, appName: String) {
        self.id = id
        self.title = title
        self.bounds = bounds
        self.isVisible = isVisible
        self.isMain = isMain
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
        case elementAppeared
        case elementDisappeared
        case overflow
    }
    
    public let type: EventType
    public let windowHandle: WindowHandle
    public let element: UIElement?
    public let timestamp: Date
    public let description: String?
    
    public init(type: EventType, windowHandle: WindowHandle, element: UIElement? = nil, timestamp: Date = Date(), description: String? = nil) {
        self.type = type
        self.windowHandle = windowHandle
        self.element = element
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