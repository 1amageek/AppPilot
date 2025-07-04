import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers
import AXUI

public actor AppPilot {
    private let cgEventDriver: CGEventDriver
    private let screenDriver: ScreenDriver
    private let accessibilityDriver: AccessibilityDriver
    
    // Element ID to WindowHandle mapping for efficient element operations
    private var elementWindowMapping: [String: WindowHandle] = [:]
    
    public init(
        cgEventDriver: CGEventDriver? = nil,
        screenDriver: ScreenDriver? = nil,
        accessibilityDriver: AccessibilityDriver? = nil
    ) {
        self.cgEventDriver = cgEventDriver ?? RealCGEventDriver()
        self.screenDriver = screenDriver ?? DefaultScreenDriver()
        self.accessibilityDriver = accessibilityDriver ?? DefaultAccessibilityDriver()
    }
    
    // MARK: - Application Management
    
    /// Get all running applications
    /// 
    /// Returns a list of all currently running applications that can be automated.
    /// Only applications with regular activation policy are included.
    /// 
    /// - Returns: An array of `AppInfo` objects representing available applications
    /// - Throws: `PilotError.permissionDenied` if accessibility permission is not granted
    public func listApplications() async throws -> [AppInfo] {
        return try await accessibilityDriver.getApplications()
    }
    
    /// Find application by bundle ID
    /// 
    /// Locates a running application using its bundle identifier.
    /// 
    /// - Parameter bundleID: The bundle identifier of the application (e.g., "com.apple.finder")
    /// - Returns: An `AppHandle` for the found application
    /// - Throws: `PilotError.applicationNotFound` if no application with the specified bundle ID is running
    public func findApplication(bundleID: String) async throws -> AppHandle {
        return try await accessibilityDriver.findApplication(bundleID: bundleID)
    }
    
    /// Find application by name
    /// 
    /// Locates a running application using its display name.
    /// Uses case-insensitive partial matching.
    /// 
    /// - Parameter name: The name of the application (e.g., "Finder", "Safari")
    /// - Returns: An `AppHandle` for the found application
    /// - Throws: `PilotError.applicationNotFound` if no application with the specified name is running
    public func findApplication(name: String) async throws -> AppHandle {
        return try await accessibilityDriver.findApplication(name: name)
    }
    
    /// Get windows for an application
    /// 
    /// Retrieves all windows belonging to the specified application.
    /// 
    /// - Parameter app: The application handle to get windows for
    /// - Returns: An array of `WindowInfo` objects representing the application's windows
    /// - Throws: `PilotError.applicationNotFound` if the application handle is invalid
    public func listWindows(app: AppHandle) async throws -> [WindowInfo] {
        return try await accessibilityDriver.getWindows(for: app)
    }
    
    /// Find window by title
    /// 
    /// Locates a window by its title within the specified application.
    /// Uses case-insensitive partial matching.
    /// 
    /// - Parameters:
    ///   - app: The application handle to search within
    ///   - title: The window title to search for
    /// - Returns: A `WindowHandle` for the found window, or `nil` if not found
    public func findWindow(app: AppHandle, title: String) async throws -> WindowHandle? {
        return try await accessibilityDriver.findWindow(app: app, title: title)
    }
    
    /// Find window by index
    /// 
    /// Locates a window by its index position within the specified application.
    /// Index 0 refers to the first window.
    /// 
    /// - Parameters:
    ///   - app: The application handle to search within
    ///   - index: The zero-based index of the window
    /// - Returns: A `WindowHandle` for the window at the specified index, or `nil` if index is out of bounds
    public func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle? {
        return try await accessibilityDriver.findWindow(app: app, index: index)
    }
    
    
    
    // MARK: - Element-Based Actions
    
    
    /// Input text into UI element by ID (optimized version)
    /// 
    /// - Parameters:
    ///   - text: The text to input
    ///   - elementID: The target UI element ID (must be a text input field)
    ///   - inputSource: The input source to use (default: .automatic)
    /// - Returns: An `ActionResult` containing both input text and actual text
    /// - Throws: `PilotError.elementNotAccessible` if element is invalid or `PilotError.invalidArgument` if element is not a text input
    public func input(
        text: String,
        into elementID: String,
        inputSource: InputSource = .automatic
    ) async throws -> ActionResult {
        // Find the window that contains this element
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Verify element is accessible and is a text input
        guard try await accessibilityDriver.elementExists(with: elementID, in: window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Get element info using AXDumper directly
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard element.isEnabled else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard element.isTextInputElement else {
            throw PilotError.invalidArgument("Element \(element.role.rawValue) is not a text input field")
        }
        
        // Click the element first to focus it
        let _ = try await click(elementID: elementID)
        
        // Wait a moment for focus to be established
        try await wait(.time(seconds: 0.1))
        
        // Type the text using the appropriate method
        if inputSource == .automatic {
            try await cgEventDriver.type(text: text)
        } else {
            try await cgEventDriver.type(text, inputSource: inputSource)
        }
        
        // Wait for input to complete
        try await wait(.time(seconds: 0.2))
        
        // Get actual text from element
        let actualText = try await getValue(from: elementID)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint,
            data: .type(inputText: text, actualText: actualText, inputSource: inputSource, composition: nil)
        )
    }
    
    /// Click UI element by ID (automatically calculates center point)
    public func click(elementID: String) async throws -> ActionResult {
        // Find the window that contains this element
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Verify element is still accessible and enabled
        guard try await accessibilityDriver.elementExists(with: elementID, in: window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Get element info using AXDumper directly
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard element.isEnabled else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Calculate center point automatically
        let centerPoint = element.centerPoint
        
        // Perform CGEvent click at the center point
        try await cgEventDriver.click(at: centerPoint)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: centerPoint,
            data: .click
        )
    }
    
    
    /// Set value directly on UI element
    /// 
    /// Sets the value of a UI element directly using the Accessibility API without
    /// simulating keystrokes. This bypasses IME, input events, and validation,
    /// providing fast value setting for test data preparation.
    /// 
    /// - Parameters:
    ///   - value: The value to set on the element
    ///   - element: The target UI element
    /// - Returns: An `ActionResult` indicating success
    /// - Throws: `PilotError.elementNotAccessible` if element is invalid or `PilotError.invalidArgument` if element doesn't support value setting
    /// 
    /// - Warning: This bypasses all input events, IME, and application validation.
    ///   Use `input(text:into:)` for realistic user simulation.
    /// Set value directly on UI element by ID
    /// 
    /// - Parameters:
    ///   - value: The value to set on the element
    ///   - elementID: The target UI element ID
    /// - Returns: An `ActionResult` indicating success
    /// - Throws: `PilotError.elementNotAccessible` if element is invalid or `PilotError.invalidArgument` if element doesn't support value setting
    /// 
    /// - Warning: This bypasses all input events, IME, and application validation.
    ///   Use `input(text:into:)` for realistic user simulation.
    public func setValue(
        _ value: String,
        for elementID: String
    ) async throws -> ActionResult {
        // Find the window that contains this element
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Verify element is accessible
        guard try await accessibilityDriver.elementExists(with: elementID, in: window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Get element info using AXDumper directly
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard element.isEnabled else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Verify element supports value setting
        guard element.isTextInputElement || element.role.rawValue == "Check" || element.role.rawValue == "Slider" else {
            throw PilotError.invalidArgument("Element \(element.role.rawValue) does not support direct value setting")
        }
        
        // Set the value directly using Accessibility API
        try await accessibilityDriver.setValue(value, for: elementID, in: window)
        
        // Get the actual value to verify
        let actualValue = try await getValue(from: elementID)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint,
            data: .setValue(inputValue: value, actualValue: actualValue)
        )
    }
    
    /// Get value from UI element by ID
    /// 
    /// Retrieves the current value of a UI element, such as text from a text field
    /// or the state of a checkbox.
    /// 
    /// - Parameter elementID: The UI element ID to get the value from
    /// - Returns: The element's value as a string, or `nil` if no value is available
    /// - Throws: `PilotError.elementNotAccessible` if the element is no longer available
    public func getValue(from elementID: String) async throws -> String? {
        // Find the window that contains this element
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        return try await accessibilityDriver.value(for: elementID, in: window)
    }
    
    /// Check if element exists and is valid by ID
    /// 
    /// - Parameter elementID: The UI element ID to check
    /// - Returns: `true` if the element exists and is accessible, `false` otherwise
    /// - Throws: Accessibility-related errors if permission is denied
    public func elementExists(elementID: String) async throws -> Bool {
        // Find the window that contains this element
        guard let window = elementWindowMapping[elementID] else {
            return false
        }
        
        return try await accessibilityDriver.elementExists(with: elementID, in: window)
    }
    
    // MARK: - Wait Operations
    
    
    /// Wait for condition
    /// 
    /// Waits for various conditions to be met, such as time delays, element appearance,
    /// or element disappearance. This is essential for handling asynchronous UI changes
    /// and ensuring automation scripts wait for the right moments.
    /// 
    /// - Parameter spec: The wait specification defining what to wait for
    /// - Throws: `PilotError.timeout` if the wait condition is not met within the timeout period
    /// 
    /// ## Usage Examples
    /// ```swift
    /// // Wait for a specific time
    /// try await pilot.wait(.time(seconds: 2.0))
    /// ```
    public func wait(_ spec: WaitSpec) async throws {
        switch spec {
        case .time(let seconds):
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            
        case .uiChange(_, let timeout):
            // Simplified implementation - just wait for time
            try await wait(.time(seconds: min(timeout, 5.0)))
        }
    }
    
    // MARK: - Application Focus Management
    
    /// Ensure target application and window are focused before operations
    private func ensureTargetAppFocus(for window: WindowHandle) async throws {
        // Get window info to find the associated app
        let apps = try await listApplications()
        var targetApp: AppInfo?
        var windowInfo: WindowInfo?
        
        // Find which app owns this window
        for app in apps {
            do {
                let windows = try await listWindows(app: app.id)
                
                for win in windows {
                    if win.id == window {
                        targetApp = app
                        windowInfo = win
                        break
                    }
                }
                
                if targetApp != nil { break }
            } catch {
                // Skip apps that can't be queried (might not have accessibility permission)
                continue
            }
        }
        
        guard let app = targetApp, let _ = windowInfo else {
            throw PilotError.windowNotFound(window)
        }
        
        // Find the NSRunningApplication for activation
        let runningApps = NSWorkspace.shared.runningApplications
        guard let nsApp = runningApps.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier || $0.localizedName == app.name 
        }) else {
            return
        }
        
        // Check if app is already frontmost
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        if currentFrontmost?.processIdentifier == nsApp.processIdentifier {
            return
        }
        
        // Activate the target application
        let activated = nsApp.activate()
        
        if activated {
            // Wait for activation to complete
            try await wait(.time(seconds: 0.5))
        }
    }
    
    
    /// Validate that coordinates are within window bounds
    private func validateCoordinates(_ point: Point, for window: WindowHandle) async throws {
        // Get window info
        let apps = try await listApplications()
        for app in apps {
            do {
                let windows = try await listWindows(app: app.id)
                if let windowInfo = windows.first(where: { $0.id == window }) {
                    let bounds = windowInfo.bounds
                    
                    // Check if point is within window bounds (with some tolerance)
                    let tolerance: CGFloat = 50
                    let expandedBounds = CGRect(
                        x: bounds.minX - tolerance,
                        y: bounds.minY - tolerance,
                        width: bounds.width + tolerance * 2,
                        height: bounds.height + tolerance * 2
                    )
                    
                    if !expandedBounds.contains(CGPoint(x: point.x, y: point.y)) {
                        throw PilotError.coordinateOutOfBounds(point)
                    }
                    return
                }
            } catch {
                // Skip apps that can't be queried
                continue
            }
        }
    }
    
    // MARK: - Fallback Coordinate Operations
    
    /// Click at coordinates (fallback when element detection fails)
    /// 
    /// Performs a mouse click at the specified coordinates within a window.
    /// This is a fallback method used when UI element detection fails or when
    /// precise coordinate-based clicking is required.
    /// 
    /// The method automatically ensures the target application is focused before
    /// performing the click operation.
    /// 
    /// - Parameters:
    ///   - window: The window to click in (used for app focus management)
    ///   - point: The screen coordinates to click at
    ///   - button: The mouse button to use (default: `.left`)
    ///   - count: Number of clicks to perform (default: `1`)
    /// - Returns: An `ActionResult` indicating success and the coordinates clicked
    /// - Throws: `PilotError.eventCreationFailed` if the click event cannot be created
    /// 
    /// - Important: Prefer element-based clicking with `click(element:)` when possible,
    ///   as it's more reliable and maintainable.
    public func click(
        window: WindowHandle,
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1
    ) async throws -> ActionResult {
        // Ensure target app is focused before clicking
        try await ensureTargetAppFocus(for: window)
        
        // Validate coordinates are reasonable
        try await validateCoordinates(point, for: window)
        
        // Use CGEventDriver for the actual click
        try await cgEventDriver.click(at: point, button: button, count: count)
        
        return ActionResult(
            success: true,
            coordinates: point
        )
    }
    
    /// Click at coordinates (safe version with window context)
    /// 
    /// Performs a mouse click at the specified coordinates with automatic app focus management.
    /// This is the recommended version that ensures the target application is focused before clicking.
    /// 
    /// - Parameters:
    ///   - point: The screen coordinates to click at
    ///   - button: The mouse button to use (default: `.left`)
    ///   - count: Number of clicks to perform (default: `1`)
    ///   - window: The window context for app focus management
    /// - Returns: An `ActionResult` indicating success and the coordinates clicked
    /// - Throws: `PilotError.eventCreationFailed` if the click event cannot be created
    public func click(
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1,
        window: WindowHandle
    ) async throws -> ActionResult {
        try await ensureTargetAppFocus(for: window)
        try await validateCoordinates(point, for: window)
        try await cgEventDriver.click(at: point, button: button, count: count)
        return ActionResult(success: true, coordinates: point)
    }
    
    /// Click at coordinates (fallback version without window context)
    /// 
    /// Performs a mouse click at the specified coordinates without app focus management.
    /// This is a fallback method for backwards compatibility.
    /// 
    /// - Parameters:
    ///   - point: The screen coordinates to click at
    ///   - button: The mouse button to use (default: `.left`)
    ///   - count: Number of clicks to perform (default: `1`)
    /// - Returns: An `ActionResult` indicating success and the coordinates clicked
    /// - Throws: `PilotError.eventCreationFailed` if the click event cannot be created
    public func click(
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1
    ) async throws -> ActionResult {
        try await cgEventDriver.click(at: point, button: button, count: count)
        return ActionResult(success: true, coordinates: point)
    }
    
    /// Type text (safe version with window context)
    /// 
    /// Types text with automatic app focus management to ensure the text goes to the correct application.
    /// This is the recommended version for reliable text input.
    /// 
    /// - Parameters:
    ///   - text: The text to type
    ///   - window: The window context for app focus management
    /// - Returns: An `ActionResult` indicating success
    /// - Throws: `PilotError.eventCreationFailed` if keyboard events cannot be created
    public func type(
        _ text: String,
        window: WindowHandle
    ) async throws -> ActionResult {
        try await ensureTargetAppFocus(for: window)
        try await cgEventDriver.type(text: text)
        return ActionResult(
            success: true,
            data: .type(inputText: text, actualText: nil, inputSource: nil, composition: nil)
        )
    }
    
    /// Type text to currently focused application (fallback)
    /// 
    /// Types text into the currently focused application without targeting a specific
    /// window or element. This is a fallback method for backwards compatibility when
    /// element-based typing is not possible.
    /// 
    /// - Parameter text: The text to type
    /// - Returns: An `ActionResult` indicating success
    /// - Throws: `PilotError.eventCreationFailed` if keyboard events cannot be created
    /// 
    /// - Warning: This method cannot ensure the correct application is focused.
    ///   Prefer using `type(text:into:)` with a specific UI element when possible.
    /// 
    /// - Note: This method types text to whatever application currently has focus,
    ///   which may not be the intended target.
    public func type(text: String) async throws -> ActionResult {
        try await cgEventDriver.type(text: text)
        return ActionResult(
            success: true,
            data: .type(inputText: text, actualText: nil, inputSource: nil, composition: nil)
        )
    }
    
    /// Drag operation (safe version with window context)
    /// 
    /// Performs a drag operation from one point to another with automatic app focus management.
    /// This is the recommended version that ensures the target application is focused before dragging.
    /// 
    /// - Parameters:
    ///   - startPoint: The starting point for the drag
    ///   - endPoint: The ending point for the drag
    ///   - duration: Duration of the drag operation in seconds (default: 1.0)
    ///   - window: The window context for app focus management
    /// - Returns: An `ActionResult` indicating success and the end coordinates
    /// - Throws: `PilotError.eventCreationFailed` if drag events cannot be created
    public func drag(
        from startPoint: Point,
        to endPoint: Point,
        duration: TimeInterval = 1.0,
        window: WindowHandle
    ) async throws -> ActionResult {
        try await ensureTargetAppFocus(for: window)
        try await validateCoordinates(startPoint, for: window)
        try await validateCoordinates(endPoint, for: window)
        try await cgEventDriver.drag(from: startPoint, to: endPoint, duration: duration)
        return ActionResult(success: true, coordinates: endPoint)
    }
    
    /// Drag operation (fallback version without window context)
    /// 
    /// Performs a drag operation from one point to another without app focus management.
    /// This is a fallback method for backwards compatibility.
    /// 
    /// - Parameters:
    ///   - startPoint: The starting point for the drag
    ///   - endPoint: The ending point for the drag
    ///   - duration: Duration of the drag operation in seconds (default: 1.0)
    /// - Returns: An `ActionResult` indicating success and the end coordinates
    /// - Throws: `PilotError.eventCreationFailed` if drag events cannot be created
    public func drag(
        from startPoint: Point,
        to endPoint: Point,
        duration: TimeInterval = 1.0
    ) async throws -> ActionResult {
        try await cgEventDriver.drag(from: startPoint, to: endPoint, duration: duration)
        return ActionResult(success: true, coordinates: endPoint)
    }
    
    // MARK: - Input Source Management
    
    /// Get current input source
    /// 
    /// Retrieves information about the currently active input source (keyboard layout).
    /// This is useful for internationalization and ensuring the correct input method
    /// is active before typing text.
    /// 
    /// - Returns: Information about the current input source including display name and identifier
    /// - Throws: System-level errors if input source information cannot be retrieved
    public func getCurrentInputSource() async throws -> InputSourceInfo {
        let source = try await cgEventDriver.getCurrentInputSource()
        return source
    }
    
    /// Get all available input sources
    /// 
    /// Retrieves a list of all input sources (keyboard layouts) available on the system.
    /// This includes different language keyboards, input methods, and layout variants.
    /// 
    /// - Returns: An array of `InputSourceInfo` objects representing all available input sources
    /// - Throws: System-level errors if input source information cannot be retrieved
    /// 
    /// ## Usage Example
    /// ```swift
    /// let sources = try await pilot.getAvailableInputSources()
    /// for source in sources {
    ///     print("\(source.displayName): \(source.identifier)")
    /// }
    /// ```
    public func getAvailableInputSources() async throws -> [InputSourceInfo] {
        let sources = try await cgEventDriver.getAvailableInputSources()
        return sources
    }
    
    /// Switch to specified input source
    /// 
    /// Changes the active input source (keyboard layout) to the specified one.
    /// This is useful for automation that needs to work with different languages
    /// or input methods.
    /// 
    /// - Parameter source: The input source to switch to
    /// - Throws: System-level errors if the input source cannot be activated
    /// 
    /// ## Usage Example
    /// ```swift
    /// // Get available sources
    /// let sources = try await pilot.getAvailableInputSources()
    /// 
    /// // Find Japanese input source
    /// if let japanese = sources.first(where: { $0.identifier.contains("Japanese") }) {
    ///     try await pilot.switchInputSource(to: japanese)
    /// }
    /// ```
    public func switchInputSource(to source: InputSource) async throws {
        try await cgEventDriver.switchInputSource(to: source)
    }
    
    /// Type text with specific input source (safe version with window context)
    /// 
    /// Types text using a specific input source with automatic app focus management.
    /// This is the recommended version for reliable multilingual text input.
    /// 
    /// - Parameters:
    ///   - text: The text to type
    ///   - inputSource: The input source to use for typing
    ///   - window: The window context for app focus management
    /// - Returns: An `ActionResult` indicating success
    /// - Throws: `PilotError.eventCreationFailed` if keyboard events cannot be created
    public func type(
        _ text: String,
        inputSource: InputSource,
        window: WindowHandle
    ) async throws -> ActionResult {
        try await ensureTargetAppFocus(for: window)
        try await cgEventDriver.type(text, inputSource: inputSource)
        return ActionResult(
            success: true,
            data: .type(inputText: text, actualText: nil, inputSource: inputSource, composition: nil)
        )
    }
    
    /// Type text with specific input source (fallback)
    public func type(text: String, inputSource: InputSource) async throws -> ActionResult {
        try await cgEventDriver.type(text, inputSource: inputSource)
        return ActionResult(
            success: true,
            data: .type(inputText: text, actualText: nil, inputSource: inputSource, composition: nil)
        )
    }
    
    // MARK: - Composition Input (IME Support)
    
    /// Input text with composition (IME-aware typing)
    /// 
    /// Performs composition input (like Japanese, Chinese, Korean) where text goes through
    /// an Input Method Editor (IME) conversion process. This method handles the complex
    /// interaction flow of composition → candidate selection → commitment.
    /// 
    /// - Parameters:
    ///   - text: The text to input (e.g., romaji for Japanese)
    ///   - element: The target UI element 
    ///   - composition: The composition type (language and input style)
    /// - Returns: An `ActionResult` with composition data indicating current state
    /// - Throws: Various `PilotError` cases for element/input issues
    /// 
    /// ## Usage Example
    /// ```swift
    /// let result = try await pilot.input("konnichiwa", into: textField, with: .japaneseRomaji)
    /// if result.needsUserDecision {
    ///     if let candidates = result.compositionCandidates {
    ///         let choice = try await decideCandidate(candidates)
    ///         let finalResult = try await pilot.selectCandidate(at: choice, for: textField)
    ///     }
    /// }
    /// ```
    /// Input text with composition by element ID
    /// 
    /// - Parameters:
    ///   - text: The text to input (e.g., romaji for Japanese)
    ///   - elementID: The target UI element ID
    ///   - composition: The composition type (language and input style)
    /// - Returns: An `ActionResult` with composition data indicating current state
    /// - Throws: Various `PilotError` cases for element/input issues
    public func input(
        _ text: String,
        into elementID: String,
        with composition: CompositionType
    ) async throws -> ActionResult {
        // Find the window that contains this element
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Verify element is accessible and is a text input
        guard try await accessibilityDriver.elementExists(with: elementID, in: window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Get element info using AXDumper directly
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard element.isEnabled else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard element.isTextInputElement else {
            throw PilotError.invalidArgument("Element \(element.role.rawValue) is not a text input field")
        }
        
        // Focus the element first
        let _ = try await click(elementID: elementID)
        try await wait(.time(seconds: 0.1))
        
        // Switch to appropriate input source based on composition type
        let inputSource = try await determineInputSource(for: composition)
        try await cgEventDriver.switchInputSource(to: inputSource)
        try await wait(.time(seconds: 0.2)) // Wait for input source switch
        
        // Type the text (this will trigger IME composition)
        try await cgEventDriver.type(text)
        try await wait(.time(seconds: 0.2)) // Wait for composition to appear
        
        // Analyze current composition state
        let compositionState = try await analyzeCompositionState(for: elementID, inputText: text, composition: composition)
        
        // Get actual text from element
        let actualText = try await getValue(from: elementID)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint,
            data: .type(
                inputText: text,
                actualText: actualText,
                inputSource: inputSource,
                composition: compositionState
            )
        )
    }
    
    /// Select a conversion candidate
    /// 
    /// When composition input presents multiple conversion candidates, this method
    /// allows selection of a specific candidate by index.
    /// 
    /// Select a conversion candidate by element ID
    /// 
    /// - Parameters:
    ///   - index: The zero-based index of the candidate to select
    ///   - elementID: The UI element ID with active composition
    /// - Returns: An `ActionResult` with updated composition state
    /// - Throws: `PilotError.invalidArgument` if index is out of range
    public func selectCandidate(
        at index: Int,
        for elementID: String
    ) async throws -> ActionResult {
        // Get element info using AXDumper directly
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Navigate to the desired candidate using Tab/Shift+Tab
        // This is a simplified implementation - real implementation would need
        // to track current selection and navigate appropriately
        for _ in 0..<index {
            try await cgEventDriver.keyDown(code: 48) // Tab key
            try await cgEventDriver.keyUp(code: 48)
            try await wait(.time(seconds: 0.1))
        }
        
        // Get updated composition state
        let newState = try await getCurrentCompositionState(for: elementID)
        let actualText = try await getValue(from: elementID)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint,
            data: .type(
                inputText: "candidate_selection",
                actualText: actualText,
                inputSource: try await cgEventDriver.getCurrentInputSource().asInputSource(),
                composition: newState
            )
        )
    }
    
    /// Commit the current composition by element ID
    /// 
    /// Finalizes the current composition input by pressing Enter.
    /// This converts the composition to final text.
    /// 
    /// - Parameter elementID: The UI element ID with active composition
    /// - Returns: An `ActionResult` indicating completion
    public func commitComposition(
        for elementID: String
    ) async throws -> ActionResult {
        // Get element info using AXDumper directly
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Press Enter to commit
        try await cgEventDriver.keyDown(code: 36) // Return key
        try await cgEventDriver.keyUp(code: 36)
        try await wait(.time(seconds: 0.1))
        
        let actualText = try await getValue(from: elementID)
        
        // Create committed composition state
        let committedState = CompositionInputResult(
            state: .committed(text: actualText ?? ""),
            inputText: "committed",
            currentText: actualText ?? "",
            needsUserDecision: false,
            availableActions: [],
            compositionType: .japaneseRomaji // This should be tracked from the original input
        )
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint,
            data: .type(
                inputText: "commit",
                actualText: actualText,
                inputSource: try await cgEventDriver.getCurrentInputSource().asInputSource(),
                composition: committedState
            )
        )
    }
    
    /// Cancel the current composition by element ID
    /// 
    /// Cancels the current composition input by pressing Escape.
    /// This reverts any uncommitted composition.
    /// 
    /// - Parameter elementID: The UI element ID with active composition
    /// - Returns: An `ActionResult` indicating cancellation
    public func cancelComposition(
        for elementID: String
    ) async throws -> ActionResult {
        // Get element info using AXDumper directly
        guard let window = elementWindowMapping[elementID] else {
            throw PilotError.elementNotAccessible(elementID)
        }
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        // Press Escape to cancel
        try await cgEventDriver.keyDown(code: 53) // Escape key
        try await cgEventDriver.keyUp(code: 53)
        try await wait(.time(seconds: 0.1))
        
        let actualText = try await getValue(from: elementID)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint,
            data: .type(
                inputText: "cancel",
                actualText: actualText,
                inputSource: try await cgEventDriver.getCurrentInputSource().asInputSource(),
                composition: nil
            )
        )
    }
    
    /// Scroll operation (safe version with window context)
    /// 
    /// Performs a scroll operation with automatic app focus management and coordinate calculation.
    /// This is the recommended version that ensures scrolling happens in the correct window.
    /// 
    /// - Parameters:
    ///   - deltaX: Horizontal scroll amount (positive = right, negative = left)
    ///   - deltaY: Vertical scroll amount (positive = down, negative = up)
    ///   - point: Optional scroll position (defaults to window center)
    ///   - window: The window context for app focus management
    /// - Returns: An `ActionResult` indicating success and the scroll position
    /// - Throws: `PilotError.eventCreationFailed` if scroll events cannot be created
    public func scroll(
        deltaX: Double = 0,
        deltaY: Double = 0,
        at point: Point? = nil,
        window: WindowHandle
    ) async throws -> ActionResult {
        try await ensureTargetAppFocus(for: window)
        
        let scrollPoint: Point
        if let point = point {
            scrollPoint = point
        } else {
            // Use window center if no point specified
            let apps = try await listApplications()
            var windowInfo: WindowInfo?
            
            for app in apps {
                do {
                    let windows = try await listWindows(app: app.id)
                    if let found = windows.first(where: { $0.id == window }) {
                        windowInfo = found
                        break
                    }
                } catch {
                    continue
                }
            }
            
            guard let windowInfo = windowInfo else {
                throw PilotError.windowNotFound(window)
            }
            scrollPoint = Point(x: windowInfo.bounds.midX, y: windowInfo.bounds.midY)
        }
        
        try await validateCoordinates(scrollPoint, for: window)
        try await cgEventDriver.scroll(deltaX: deltaX, deltaY: deltaY, at: scrollPoint)
        return ActionResult(success: true, coordinates: scrollPoint)
    }
    
    /// Scroll operation (fallback version without window context)
    /// 
    /// Performs a scroll operation at a specific point without app focus management.
    /// This is a fallback method for backwards compatibility.
    /// 
    /// - Parameters:
    ///   - deltaX: Horizontal scroll amount (positive = right, negative = left)
    ///   - deltaY: Vertical scroll amount (positive = down, negative = up)
    ///   - point: The position to scroll at
    /// - Returns: An `ActionResult` indicating success and the scroll position
    /// - Throws: `PilotError.eventCreationFailed` if scroll events cannot be created
    public func scroll(
        deltaX: Double = 0,
        deltaY: Double = 0,
        at point: Point
    ) async throws -> ActionResult {
        try await cgEventDriver.scroll(deltaX: deltaX, deltaY: deltaY, at: point)
        return ActionResult(success: true, coordinates: point)
    }
    
    /// Perform gesture from one point to another (safe version with window context)
    /// 
    /// Performs a gesture operation with automatic app focus management.
    /// This is the recommended version that ensures the gesture happens in the correct window.
    /// 
    /// - Parameters:
    ///   - startPoint: The starting point for the gesture
    ///   - endPoint: The ending point for the gesture
    ///   - duration: Duration of the gesture in seconds (default: 1.0)
    ///   - window: The window context for app focus management
    /// - Returns: An `ActionResult` indicating success and the end coordinates
    /// - Throws: `PilotError.eventCreationFailed` if gesture events cannot be created
    public func gesture(
        from startPoint: Point,
        to endPoint: Point,
        duration: TimeInterval = 1.0,
        window: WindowHandle
    ) async throws -> ActionResult {
        try await ensureTargetAppFocus(for: window)
        try await validateCoordinates(startPoint, for: window)
        try await validateCoordinates(endPoint, for: window)
        try await cgEventDriver.drag(from: startPoint, to: endPoint, duration: duration)
        return ActionResult(success: true, coordinates: endPoint)
    }
    
    /// Perform gesture from one point to another (fallback)
    public func gesture(from startPoint: Point, to endPoint: Point, duration: TimeInterval = 1.0) async throws -> ActionResult {
        try await cgEventDriver.drag(from: startPoint, to: endPoint, duration: duration)
        return ActionResult(success: true, coordinates: endPoint)
    }
    
    /// Capture screenshot of window
    public func capture(window: WindowHandle) async throws -> CGImage {
        // Check if window handle is still valid first
        if await accessibilityDriver.isWindowHandleValid(window) {
            // Try direct approach first - find the window in current app lists
            let apps = try await listApplications()
            for app in apps {
                do {
                    let windows = try await listWindows(app: app.id)
                    if let windowInfo = windows.first(where: { $0.id == window }) {
                        return try await captureWindowDirect(windowInfo: windowInfo, app: app)
                    }
                } catch {
                    continue
                }
            }
        }
        
        // If direct approach failed, refresh and try again
        let apps = try await listApplications()
        var windowInfo: WindowInfo?
        var targetApp: AppInfo?
        
        for app in apps {
            do {
                let windows = try await listWindows(app: app.id)
                if let found = windows.first(where: { $0.id == window }) {
                    windowInfo = found
                    targetApp = app
                    break
                }
            } catch {
                continue
            }
        }
        
        guard let windowInfo = windowInfo, let app = targetApp else {
            throw PilotError.windowNotFound(window)
        }
        
        return try await captureWindowDirect(windowInfo: windowInfo, app: app)
    }
    
    /// Helper method to capture a window directly
    private func captureWindowDirect(windowInfo: WindowInfo, app: AppInfo) async throws -> CGImage {
        // Try direct CGWindowID approach first (faster and more reliable)
        if let cgWindowID = windowInfo.windowID {
            do {
                // Verify the CGWindowID still exists in ScreenCaptureKit
                if let validatedWindowID = try await screenDriver.findWindowByCGWindowID(cgWindowID) {
                    return try await screenDriver.captureWindow(windowID: validatedWindowID)
                }
            } catch {
                // Log but continue to fallback - CGWindowID might be stale
                print("🔄 CGWindowID \(cgWindowID) lookup failed, falling back to title/bounds matching: \(error)")
            }
        }
        
        // Fallback to existing title/bounds matching approach
        // For Chrome (and other apps with empty titles), try bundle ID + bounds matching
        print("🔄 Fallback matching: title='\(windowInfo.title ?? "nil")', bundle=\(app.bundleIdentifier ?? "nil"), bounds=\(windowInfo.bounds)")
        
        // Find the SCWindow ID that matches our WindowInfo (includes Mission Control windows)
        guard let windowID = try await screenDriver.findWindowID(
            title: windowInfo.title,
            bundleIdentifier: app.bundleIdentifier,
            bounds: windowInfo.bounds,
            onScreenOnly: false
        ) else {
            print("❌ No matching SCWindow found for window: \(windowInfo.id)")
            print("   Title: '\(windowInfo.title ?? "nil")'")
            print("   Bundle: \(app.bundleIdentifier ?? "nil")")
            print("   Bounds: \(windowInfo.bounds)")
            throw PilotError.windowNotFound(windowInfo.id)
        }
        
        print("✅ Found matching SCWindow ID: \(windowID)")
        
        let windowImage = try await screenDriver.captureWindow(windowID: windowID)
        return windowImage
    }
    
    /// Capture UI elements snapshot without image data (token-efficient)
    ///
    /// This method captures only the UI element hierarchy without taking a screenshot,
    /// making it much more token-efficient for LLM processing. Use this when you only
    /// need element information and not visual appearance.
    ///
    /// - Parameters:
    ///   - window: The window to capture elements from
    ///   - query: Optional AXUI.AXQuery to filter elements (nil = all elements)
    ///
    /// - Returns: ElementsSnapshot containing only filtered element hierarchy
    ///
    /// - Throws: 
    ///   - `PilotError.windowNotFound` if window doesn't exist
    ///   - `PilotError.permissionDenied` if accessibility permission not granted
    ///
    /// Example usage:
    /// ```swift
    /// // Get only buttons (very token-efficient)
    /// let buttonQuery = AXUI.AXQuery.button()
    /// let elementsSnapshot = try await pilot.elementsSnapshot(window: window, query: buttonQuery)
    ///
    /// // Get text fields only
    /// let textFieldQuery = AXUI.AXQuery.textField()
    /// let elementsSnapshot = try await pilot.elementsSnapshot(window: window, query: textFieldQuery)
    ///
    /// // Get all elements (more efficient than snapshot with image)
    /// let allElementsSnapshot = try await pilot.elementsSnapshot(window: window)
    /// ```
    public func elementsSnapshot(
        window: WindowHandle,
        query: AXUI.AXQuery? = nil
    ) async throws -> ElementsSnapshot {
        // Get window information
        let apps = try await listApplications()
        var windowInfo: WindowInfo?
        var targetApp: AppInfo?
        
        for app in apps {
            do {
                let windows = try await listWindows(app: app.id)
                if let found = windows.first(where: { $0.id == window }) {
                    windowInfo = found
                    targetApp = app
                    break
                }
            } catch {
                continue
            }
        }
        
        guard let windowInfo = windowInfo, let targetApp = targetApp else {
            throw PilotError.windowNotFound(window)
        }
        
        // Get bundle identifier for AXDumper
        guard let bundleID = targetApp.bundleIdentifier else {
            throw PilotError.applicationNotFound("Bundle identifier not found")
        }
        
        // Verify window exists
        let windows = try await listWindows(app: targetApp.id)
        guard windows.contains(where: { $0.id == window }) else {
            throw PilotError.windowNotFound(window)
        }
        
        // Use AXDumper.dump() directly with AXQuery for efficient element discovery
        let axElements = try AXDumper.dump(
            bundleIdentifier: bundleID,
            query: query,
            includeZeroSize: false
        )
        
        // Update element window mapping for efficient future operations
        for element in axElements {
            elementWindowMapping[element.id] = window
        }
        
        // Create and return the elements-only snapshot
        return ElementsSnapshot(
            windowHandle: window,
            windowInfo: windowInfo,
            elements: axElements
        )
    }
    
    /// Capture a selective UI snapshot with AXQuery for token-efficient element discovery
    ///
    /// This method combines window screenshot capture with selective UI element discovery
    /// using AXUI.AXQuery to reduce token consumption by only fetching elements matching
    /// specific criteria instead of all elements in the window.
    ///
    /// - Parameters:
    ///   - window: The window to capture
    ///   - query: Optional AXUI.AXQuery to filter elements (nil = all elements)
    ///
    /// - Returns: UISnapshot containing screenshot and filtered element hierarchy
    ///
    /// - Throws: 
    ///   - `PilotError.windowNotFound` if window doesn't exist
    ///   - `PilotError.imageConversionFailed` if screenshot conversion fails
    ///   - `PilotError.permissionDenied` if accessibility permission not granted
    ///
    /// Example usage:
    /// ```swift
    /// // Get only buttons (token-efficient)
    /// let buttonQuery = AXUI.AXQuery.button()
    /// let snapshot = try await pilot.snapshot(window: window, query: buttonQuery)
    ///
    /// // Get text fields
    /// let textFieldQuery = AXUI.AXQuery.textField()
    /// let snapshot = try await pilot.snapshot(window: window, query: textFieldQuery)
    ///
    /// // Get all elements (same as snapshot(window:))
    /// let fullSnapshot = try await pilot.snapshot(window: window)
    /// ```
    public func snapshot(
        window: WindowHandle,
        query: AXUI.AXQuery? = nil
    ) async throws -> UISnapshot {
        // Get window information
        let apps = try await listApplications()
        var windowInfo: WindowInfo?
        var targetApp: AppInfo?
        
        for app in apps {
            do {
                let windows = try await listWindows(app: app.id)
                if let found = windows.first(where: { $0.id == window }) {
                    windowInfo = found
                    targetApp = app
                    break
                }
            } catch {
                continue
            }
        }
        
        guard let windowInfo = windowInfo, let _ = targetApp else {
            throw PilotError.windowNotFound(window)
        }
        
        // Capture window screenshot
        let windowImage = try await capture(window: window)
        
        // Convert CGImage to PNG data
        guard let imageData = windowImage.pngData() else {
            throw PilotError.imageConversionFailed
        }
        
        // Get bundle identifier for AXDumper
        guard let targetApp = targetApp,
              let bundleID = targetApp.bundleIdentifier else {
            throw PilotError.applicationNotFound("Bundle identifier not found")
        }
        
        // Verify window exists
        let windows = try await listWindows(app: targetApp.id)
        guard windows.contains(where: { $0.id == window }) else {
            throw PilotError.windowNotFound(window)
        }
        
        // Use AXDumper.dump() directly with AXQuery for efficient element discovery
        let axElements = try AXDumper.dump(
            bundleIdentifier: bundleID,
            query: query,
            includeZeroSize: false
        )
        
        // Use AXElements directly
        let elements = axElements
        
        // Update element window mapping for efficient future operations
        for element in elements {
            elementWindowMapping[element.id] = window
        }
        
        // Create and return the snapshot
        return UISnapshot(
            windowHandle: window,
            windowInfo: windowInfo,
            elements: elements,
            imageData: imageData
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Get accessible applications that can be automated
    public func getAccessibleApplications() async throws -> [AppInfo] {
        guard await accessibilityDriver.checkPermission() else {
            throw PilotError.permissionDenied("Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility")
        }
        
        return try await listApplications()
    }
    
    
    // MARK: - Element-based Actions
    
    /// Click on a specific UI element by ID
    public func clickElement(elementID: String, in window: WindowHandle) async throws -> ActionResult {
        // Get element info using AXDumper directly
        guard let bundleID = try await getBundleIDForWindow(window) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        guard let element = try? AXDumper.element(id: elementID, bundleIdentifier: bundleID) else {
            throw PilotError.elementNotAccessible(elementID)
        }
        
        print("🎯 AppPilot: Clicking element \(element.role.rawValue): \(element.description ?? elementID)")
        print("   Element bounds: \(element.cgBounds)")
        print("   Center point: \(element.centerPoint)")
        
        // Ensure target app is focused before clicking
        try await ensureTargetAppFocus(for: window)
        
        // Use the element's center point for clicking
        let result = try await click(window: window, at: element.centerPoint)
        
        return ActionResult(
            success: result.success,
            coordinates: element.centerPoint
        )
    }
    
    /// Key combination support
    public func keyCombination(_ keys: [VirtualKey], modifiers: [ModifierKey]) async throws -> ActionResult {
        print("⌨️ AppPilot: Key combination - modifiers: \(modifiers), keys: \(keys)")
        
        // Use CGEventDriver for key combinations
        try await cgEventDriver.keyCombination(keys, modifiers: modifiers)
        
        return ActionResult(success: true)
    }
    
    
    // MARK: - Helper Methods
    
    /// Find ScreenCaptureKit window using AccessibilityDriver window handle
    /// 
    /// This method bridges AccessibilityDriver and ScreenDriver by using CGWindowID
    /// from WindowInfo to directly locate the corresponding ScreenCaptureKit window.
    ///
    /// - Parameter windowHandle: The accessibility window handle
    /// - Returns: The CGWindowID if found and validated
    /// - Throws: `PilotError.windowNotFound` or `PilotError.cgWindowIDUnavailable`
    private func findSCWindowForAXWindow(_ windowHandle: WindowHandle) async throws -> UInt32 {
        // Get WindowInfo from AccessibilityDriver (includes CGWindowID from kAXWindowNumberAttribute)
        let apps = try await listApplications()
        var windowInfo: WindowInfo?
        
        for app in apps {
            do {
                let windows = try await listWindows(app: app.id)
                if let found = windows.first(where: { $0.id == windowHandle }) {
                    windowInfo = found
                    break
                }
            } catch {
                continue
            }
        }
        
        guard let windowInfo = windowInfo else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        guard let cgWindowID = windowInfo.windowID else {
            throw PilotError.cgWindowIDUnavailable(windowHandle)
        }
        
        // Verify the CGWindowID exists in ScreenCaptureKit
        guard let validatedWindowID = try await screenDriver.findWindowByCGWindowID(cgWindowID) else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        return validatedWindowID
    }
    
    
    // MARK: - Composition Input Helper Methods
    
    /// Determine the appropriate InputSource for a given CompositionType
    private func determineInputSource(for composition: CompositionType) async throws -> InputSource {
        switch composition.rawValue {
        case "japanese":
            if composition.style?.rawValue.contains("romaji") == true {
                return .japanese
            } else {
                return .japaneseHiragana
            }
        case "chinese":
            if composition.style?.rawValue.contains("pinyin") == true {
                return .chinesePinyin
            } else {
                return .chineseTraditional
            }
        case "korean":
            return .koreanIM
        default:
            return .english
        }
    }
    
    /// Analyze the current composition state after typing
    private func analyzeCompositionState(
        for elementID: String,
        inputText: String,
        composition: CompositionType
    ) async throws -> CompositionInputResult {
        // This is a simplified implementation
        // Real implementation would need to:
        // 1. Check if IME candidate window is visible
        // 2. Extract candidate list from IME window
        // 3. Determine current selection state
        
        let currentText = try await getValue(from: elementID) ?? ""
        
        // Simple heuristic: if text changed, composition is happening
        if currentText != inputText {
            // For Japanese, common conversion scenarios
            if composition.rawValue == "japanese" {
                let realCandidates = try await getRealIMECandidates(for: elementID)
                
                if realCandidates.count > 1 {
                    return CompositionInputResult(
                        state: .candidateSelection(
                            original: inputText,
                            candidates: realCandidates,
                            selectedIndex: 0
                        ),
                        inputText: inputText,
                        currentText: currentText,
                        needsUserDecision: true,
                        availableActions: [.selectCandidate(index: 0), .nextCandidate, .commit, .cancel],
                        compositionType: composition
                    )
                } else {
                    return CompositionInputResult(
                        state: .composing(text: currentText, suggestions: realCandidates),
                        inputText: inputText,
                        currentText: currentText,
                        needsUserDecision: false,
                        availableActions: [.commit, .cancel],
                        compositionType: composition
                    )
                }
            }
        }
        
        // Default: committed state
        return CompositionInputResult(
            state: .committed(text: currentText),
            inputText: inputText,
            currentText: currentText,
            needsUserDecision: false,
            availableActions: [],
            compositionType: composition
        )
    }
    
    /// Get current composition state for an element by ID
    private func getCurrentCompositionState(for elementID: String) async throws -> CompositionInputResult {
        let currentText = try await getValue(from: elementID) ?? ""
        
        // Simplified implementation - would need real IME state detection
        return CompositionInputResult(
            state: .committed(text: currentText),
            inputText: "current",
            currentText: currentText,
            needsUserDecision: false,
            availableActions: [],
            compositionType: .japaneseRomaji
        )
    }
    
    /// Get real IME candidates from the system
    /// 
    /// This method attempts to retrieve actual conversion candidates from the active IME.
    /// It searches for IME candidate windows and extracts the candidate text.
    private func getRealIMECandidates(for elementID: String) async throws -> [String] {
        // Try to find IME candidate window
        let candidates = try await findIMECandidateWindow()
        
        if !candidates.isEmpty {
            return candidates
        }
        
        // Return empty array when no real candidates are available
        return []
    }
    
    /// Find and extract candidates from IME candidate window
    private func findIMECandidateWindow() async throws -> [String] {
        // Get all system windows
        let allApps = try await listApplications()
        var candidates: [String] = []
        
        for app in allApps {
            let windows = try await listWindows(app: app.id)
            
            for window in windows {
                // Check if this could be an IME candidate window
                if isLikelyIMECandidateWindow(window) {
                    let windowCandidates = try await extractCandidatesFromWindow(window)
                    if !windowCandidates.isEmpty {
                        candidates.append(contentsOf: windowCandidates)
                    }
                }
            }
        }
        
        return candidates
    }
    
    /// Check if a window is likely an IME candidate window
    private func isLikelyIMECandidateWindow(_ window: WindowInfo) -> Bool {
        // IME candidate windows typically have these characteristics:
        // 1. Small size (usually for candidate list)
        // 2. No title or IME-related title
        // 3. Floating/overlay behavior
        let hasSmallSize = window.bounds.width < 400 && window.bounds.height < 200
        let hasNoTitleOrIMETitle = window.title?.isEmpty == true || 
                                  window.title?.contains("候補") == true ||
                                  window.title?.contains("Candidate") == true ||
                                  window.title?.contains("変換") == true
        
        return hasSmallSize && hasNoTitleOrIMETitle
    }
    
    /// Extract candidate text from a potential IME window
    private func extractCandidatesFromWindow(_ window: WindowInfo) async throws -> [String] {
        do {
            // Use AXDumper to get elements directly
            guard let bundleID = try await getBundleIDForWindow(window.id) else {
                return []
            }
            
            let elements = try AXDumper.dump(
                bundleIdentifier: bundleID,
                query: nil,
                includeZeroSize: false
            )
            
            var candidates: [String] = []
            
            // Look for text elements that could be candidates
            let textElements = elements.filter { element in
                (element.role.rawValue == "Text" || 
                 element.role.rawValue == "Cell" || 
                 element.role.rawValue == "Button") &&
                element.isEnabled
            }
            
            for element in textElements {
                if let text = element.description,
                   !text.isEmpty,
                   !text.isSystemUIText() {
                    candidates.append(text)
                }
            }
            
            return candidates
        } catch {
            // If we can't access the window, it might not be an IME window
            return []
        }
    }
    
    /// Helper method to get bundle ID for a window
    private func getBundleIDForWindow(_ windowHandle: WindowHandle) async throws -> String? {
        return windowHandle.bundleID
    }
    
}

// MARK: - String Extension for IME Support

extension String {
    /// Check if this text is likely system UI text that shouldn't be considered a candidate
    func isSystemUIText() -> Bool {
        // Filter out common system UI text that appears in IME windows
        let systemTexts = [
            "OK", "Cancel", "確定", "キャンセル", "変換", "無変換",
            "←", "→", "↑", "↓", "▲", "▼", "◀", "▶"
        ]
        
        return systemTexts.contains(self) || 
               (self.count == 1 && self.unicodeScalars.allSatisfy { CharacterSet.symbols.contains($0) })
    }
}

// MARK: - InputSourceInfo Extension

extension InputSourceInfo {
    /// Convert InputSourceInfo to InputSource enum
    func asInputSource() -> InputSource {
        if identifier.contains("ABC") {
            return .english
        } else if identifier.contains("Kotoeri") && identifier.contains("Japanese") {
            return .japaneseHiragana
        } else if identifier.contains("Kotoeri") {
            return .japanese
        } else if identifier.contains("SCIM") || identifier.contains("Pinyin") {
            return .chinesePinyin
        } else if identifier.contains("TCIM") || identifier.contains("Cangjie") {
            return .chineseTraditional
        } else if identifier.contains("Korean") {
            return .koreanIM
        } else {
            return .automatic
        }
    }
}

// MARK: - CGImage Extension

extension CGImage {
    /// Convert CGImage to PNG data
    func pngData() -> Data? {
        let cfData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(cfData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, self, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return cfData as Data
    }
}
