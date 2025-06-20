import Foundation

// MARK: - Core Identifiers

/// A handle representing an application that can be automated
/// 
/// `AppHandle` provides a stable identifier for applications that persists across
/// automation operations. Use this handle to reference applications when working
/// with windows and UI elements.
/// 
/// ```swift
/// let app = try await pilot.getApplication(bundleID: "com.apple.safari")
/// let windows = try await pilot.listWindows(app: app)
/// ```
public struct AppHandle: Hashable, Sendable, Codable {
    /// The unique identifier for this application
    public let id: String
    
    /// Creates a new application handle
    /// - Parameter id: The unique identifier for the application
    public init(id: String) {
        self.id = id
    }
}

/// A handle representing a window that can be automated
/// 
/// `WindowHandle` provides a stable identifier for windows that persists across
/// automation operations. Use this handle to reference windows when working
/// with UI elements.
/// 
/// ```swift
/// let window = try await pilot.getWindow(app: app, title: "Untitled")
/// let elements = try await pilot.listElements(in: window)
/// ```
public struct WindowHandle: Hashable, Sendable, Codable {
    /// The unique identifier for this window
    public let id: String
    /// Bundle identifier of the application that owns this window
    public let bundleID: String
    
    /// Creates a new window handle
    /// - Parameters:
    ///   - id: The unique identifier for the window
    ///   - bundleID: Bundle identifier of the application that owns this window
    public init(id: String, bundleID: String) {
        self.id = id
        self.bundleID = bundleID
    }
}