import Foundation
import AXUI

// MARK: - Accessibility Types

/// Re-export AXElement from AXUI for AppPilot compatibility
/// 
/// `AXElement` represents a user interface element used for automation.
/// 
/// ```swift
/// let elements = try await pilot.listElements(in: window)
/// try await pilot.click(element: elements.first!)
/// ```
public typealias AXElement = AXUI.AXElement

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
    public let element: AXElement?
    public let timestamp: Date
    public let description: String?
    
    public init(type: EventType, windowHandle: WindowHandle, element: AXElement? = nil, timestamp: Date = Date(), description: String? = nil) {
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