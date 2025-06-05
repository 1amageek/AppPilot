import Foundation
import CoreGraphics
import AppKit

public actor CoordinateConverter {
    public init() {}
    
    public func windowToScreen(_ point: Point, in window: Window) -> CGPoint {
        // Convert window-relative coordinates to screen coordinates
        // macOS coordinate system: (0,0) is bottom-left of primary screen
        let screenX = window.frame.origin.x + point.x
        let screenY = window.frame.origin.y + point.y
        return CGPoint(x: screenX, y: screenY)
    }
    
    public func screenToWindow(_ point: CGPoint, in window: Window) -> Point {
        // Convert screen coordinates to window-relative coordinates
        let windowX = Double(point.x) - Double(window.frame.origin.x)
        let windowY = Double(point.y) - Double(window.frame.origin.y)
        return Point(x: windowX, y: windowY)
    }
    
    public func normalizeForAX(_ point: Point, in window: Window) -> CGPoint {
        // AX coordinates use screen coordinates with potential flipping
        let screenPoint = windowToScreen(point, in: window)
        
        // Get primary screen height for Y-coordinate conversion if needed
        guard let primaryScreen = NSScreen.main else {
            return screenPoint
        }
        
        let screenHeight = primaryScreen.frame.height
        
        // AX API typically uses flipped coordinates (top-left origin)
        // Convert from bottom-left to top-left coordinate system
        let flippedY = screenHeight - screenPoint.y
        
        return CGPoint(x: screenPoint.x, y: flippedY)
    }
    
    public func convertCGWindowBoundsToScreen(_ bounds: CGRect) -> CGRect {
        // CGWindow bounds are already in screen coordinates
        // but may need Y-axis adjustment depending on context
        return bounds
    }
    
    public func convertFromFlippedCoordinates(_ point: CGPoint) -> CGPoint {
        // Convert from top-left origin to bottom-left origin
        guard let primaryScreen = NSScreen.main else {
            return point
        }
        
        let screenHeight = primaryScreen.frame.height
        return CGPoint(x: point.x, y: screenHeight - point.y)
    }
}
