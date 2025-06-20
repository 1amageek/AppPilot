import Foundation
import CoreGraphics
import AXUI

// MARK: - UI Snapshot

/// A lightweight snapshot of UI element hierarchy without image data (token-efficient)
/// 
/// `ElementsSnapshot` captures only the structural state (UI element tree) of a window
/// without the screenshot, making it much more token-efficient for LLM processing.
/// This is ideal when you only need element information and not visual appearance.
/// 
/// ```swift
/// let elementsSnapshot = try await pilot.elementsSnapshot(window: window)
/// 
/// // Analyze UI elements without image overhead
/// let buttons = elementsSnapshot.elements.filter { $0.role?.rawValue == "Button" }
/// print("Found \(buttons.count) buttons")
/// ```
public struct ElementsSnapshot: Sendable, Codable {
    /// The window handle this snapshot belongs to
    public let windowHandle: WindowHandle
    
    /// Window information at the time of snapshot
    public let windowInfo: WindowInfo
    
    /// UI elements discovered in the window (filtered by query if provided)
    public let elements: [AXElement]
    
    public init(
        windowHandle: WindowHandle,
        windowInfo: WindowInfo,
        elements: [AXElement]
    ) {
        self.windowHandle = windowHandle
        self.windowInfo = windowInfo
        self.elements = elements
    }
    
    /// Get elements sorted by their position (top-left to bottom-right)
    public var elementsByPosition: [AXElement] {
        elements.sorted { e1, e2 in
            let bounds1 = e1.boundsAsRect
            let bounds2 = e2.boundsAsRect
            if abs(bounds1.minY - bounds2.minY) < 5 {
                return bounds1.minX < bounds2.minX
            }
            return bounds1.minY < bounds2.minY
        }
    }
    
    /// Get clickable elements only
    public var clickableElements: [AXElement] {
        elements.filter { element in
            element.isClickable && element.isEnabled
        }
    }
    
    /// Get text input elements only
    public var textInputElements: [AXElement] {
        elements.filter { element in
            element.isTextInput && element.isEnabled
        }
    }
}

/// A complete snapshot of UI state including window image and element hierarchy
/// 
/// `UISnapshot` captures both the visual state (screenshot) and structural state
/// (UI element tree) of a window at a specific point in time. This is useful for
/// debugging, testing, and analyzing UI state.
/// 
/// ```swift
/// let snapshot = try await pilot.snapshot(window: window)
/// 
/// // Access the screenshot
/// let image = snapshot.image
/// 
/// // Analyze UI elements
/// let buttons = snapshot.elements.filter { $0.role == .button }
/// print("Found \(buttons.count) buttons")
/// ```
public struct UISnapshot: Sendable, Codable {
    /// The window handle this snapshot belongs to
    public let windowHandle: WindowHandle
    
    /// Window information at the time of snapshot
    public let windowInfo: WindowInfo
    
    /// UI elements discovered in the window (filtered by query if provided)
    public let elements: [AXElement]
    
    /// PNG data of the window screenshot
    public let imageData: Data
    
    public init(
        windowHandle: WindowHandle,
        windowInfo: WindowInfo,
        elements: [AXElement],
        imageData: Data
    ) {
        self.windowHandle = windowHandle
        self.windowInfo = windowInfo
        self.elements = elements
        self.imageData = imageData
    }
    
    /// Reconstructs the CGImage from stored PNG data
    public var image: CGImage? {
        guard let dataProvider = CGDataProvider(data: imageData as CFData),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return cgImage
    }
    
    /// Get elements sorted by their position (top-left to bottom-right)
    public var elementsByPosition: [AXElement] {
        elements.sorted { e1, e2 in
            let bounds1 = e1.boundsAsRect
            let bounds2 = e2.boundsAsRect
            if abs(bounds1.minY - bounds2.minY) < 5 {
                return bounds1.minX < bounds2.minX
            }
            return bounds1.minY < bounds2.minY
        }
    }
    
    /// Get clickable elements only
    public var clickableElements: [AXElement] {
        elements.filter { element in
            element.isClickable && element.isEnabled
        }
    }
    
    /// Get text input elements only
    public var textInputElements: [AXElement] {
        elements.filter { element in
            element.isTextInput && element.isEnabled
        }
    }
}

public typealias PNGData = Data