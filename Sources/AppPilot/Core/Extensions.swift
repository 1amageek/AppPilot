import Foundation
import CoreGraphics
import AXUI

// MARK: - Extensions

extension String? {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

extension String {
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + "..."
    }
    
    static func randomAlphanumeric(length: Int) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// MARK: - AXElement Extensions for Internal Use

extension AXElement: @retroactive @unchecked Sendable {
    /// The screen bounds of this element as CGRect
    public var cgBounds: CGRect {
        guard let position = self.position, let size = self.size else {
            return CGRect.zero
        }
        return CGRect(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }
    
    /// The center point of this element in screen coordinates
    public var centerPoint: Point {
        let bounds = self.cgBounds
        return Point(x: bounds.midX, y: bounds.midY)
    }
    
    /// Whether this element is currently enabled for interaction
    public var isEnabled: Bool {
        return self.state?.enabled ?? true
    }
    
    /// Whether this element is clickable based on its role
    public var isClickableElement: Bool {
        let axuiRole = self.role
        return Role(rawValue: axuiRole.rawValue)?.isClickable ?? false
    }
    
    /// Check if element is clickable (alternate name for consistency)
    public var isClickable: Bool { isClickableElement }
    
    /// Whether this element accepts text input based on its role
    public var isTextInputElement: Bool {
        let axuiRole = self.role
        return Role(rawValue: axuiRole.rawValue)?.isTextInput ?? false
    }
    
    /// Check if element accepts text input (alternate name for consistency) 
    public var isTextInput: Bool { isTextInputElement }
    
    /// Whether element is selected
    public var isSelected: Bool {
        state?.selected ?? false
    }
    
    /// Whether element is focused
    public var isFocused: Bool {
        state?.focused ?? false
    }
    
    /// Convert bounds to CGRect (alias for cgBounds)
    public var boundsAsRect: CGRect { cgBounds }
}

/// Convert AppPilot Point to AXUI Point
extension Point {
    public var axuiPoint: AXUI.Point {
        return AXUI.Point(x: Double(self.x), y: Double(self.y))
    }
    
    public init(axuiPoint: AXUI.Point) {
        self.init(x: CGFloat(axuiPoint.x), y: CGFloat(axuiPoint.y))
    }
}