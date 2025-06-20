import Foundation
import CoreGraphics

// MARK: - Geometry

/// A point in screen coordinates
/// 
/// `Point` represents a location on the screen using macOS screen coordinates.
/// The origin (0,0) is at the bottom-left of the primary display.
/// 
/// ```swift
/// let point = Point(x: 100, y: 200)
/// try await pilot.click(window: window, at: point)
/// ```
public struct Point: Sendable, Equatable, Codable {
    /// The x-coordinate in screen coordinates
    public let x: CGFloat
    /// The y-coordinate in screen coordinates
    public let y: CGFloat
    
    /// Creates a point with CGFloat coordinates
    /// - Parameters:
    ///   - x: The x-coordinate
    ///   - y: The y-coordinate
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    /// Creates a point with Double coordinates
    /// - Parameters:
    ///   - x: The x-coordinate
    ///   - y: The y-coordinate
    public init(x: Double, y: Double) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }
}