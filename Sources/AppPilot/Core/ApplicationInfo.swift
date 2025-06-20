import Foundation
import CoreGraphics

// MARK: - Application Info

/// Information about a running application
/// 
/// `AppInfo` contains metadata about applications that can be automated,
/// including their name, bundle identifier, and current state.
/// 
/// ```swift
/// let apps = try await pilot.listApplications()
/// for app in apps {
///     print("App: \(app.name) (\(app.bundleIdentifier ?? "unknown"))")
/// }
/// ```
public struct AppInfo: Sendable, Codable {
    /// Handle for referencing this application
    public let id: AppHandle
    /// Display name of the application
    public let name: String
    /// Bundle identifier (e.g., "com.apple.safari")
    public let bundleIdentifier: String?
    /// Whether this application is currently the frontmost/active app
    public let isActive: Bool
    
    /// Creates application information
    /// 
    /// - Parameters:
    ///   - id: Handle for this application
    ///   - name: Display name
    ///   - bundleIdentifier: Bundle identifier, if available
    ///   - isActive: Whether the app is currently active
    public init(id: AppHandle, name: String, bundleIdentifier: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
    }
}

// MARK: - Window Info

/// Information about an application window
/// 
/// `WindowInfo` contains metadata about windows that can be automated,
/// including their title, position, and visibility state.
/// 
/// ```swift
/// let windows = try await pilot.listWindows(app: app)
/// for window in windows where window.isVisible {
///     print("Window: \(window.title ?? "Untitled") at \(window.bounds)")
/// }
/// ```
public struct WindowInfo: Sendable, Codable {
    /// Handle for referencing this window
    public let id: WindowHandle
    /// Title of the window, if any
    public let title: String?
    /// Screen bounds of the window in screen coordinates
    public let bounds: CGRect
    /// Whether the window is currently visible
    public let isVisible: Bool
    /// Whether this is the main window of the application
    public let isMain: Bool
    /// Name of the application that owns this window
    public let appName: String
    /// ScreenCaptureKit window ID for direct window capture
    public let windowID: UInt32?
    
    /// Creates window information
    /// 
    /// - Parameters:
    ///   - id: Handle for this window
    ///   - title: Window title, if any
    ///   - bounds: Screen bounds
    ///   - isVisible: Whether the window is visible
    ///   - isMain: Whether this is the main window
    ///   - appName: Name of the owning application
    ///   - windowID: ScreenCaptureKit window ID for direct capture
    public init(id: WindowHandle, title: String?, bounds: CGRect, isVisible: Bool, isMain: Bool, appName: String, windowID: UInt32? = nil) {
        self.id = id
        self.title = title
        self.bounds = bounds
        self.isVisible = isVisible
        self.isMain = isMain
        self.appName = appName
        self.windowID = windowID
    }
}