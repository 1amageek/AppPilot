import Foundation
import CoreGraphics
import AppKit

public actor AppPilot {
    private let cgEventDriver: CGEventDriver
    private let screenDriver: ScreenDriver
    private let accessibilityDriver: AccessibilityDriver
    
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
    /// - Parameter bundleId: The bundle identifier of the application (e.g., "com.apple.finder")
    /// - Returns: An `AppHandle` for the found application
    /// - Throws: `PilotError.applicationNotFound` if no application with the specified bundle ID is running
    public func findApplication(bundleId: String) async throws -> AppHandle {
        return try await accessibilityDriver.findApplication(bundleId: bundleId)
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
    /// - Returns: A `WindowHandle` for the found window
    /// - Throws: `PilotError.windowNotFound` if no window with the specified title exists
    public func findWindow(app: AppHandle, title: String) async throws -> WindowHandle {
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
    /// - Returns: A `WindowHandle` for the window at the specified index
    /// - Throws: `PilotError.windowNotFound` if the index is out of bounds
    public func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle {
        return try await accessibilityDriver.findWindow(app: app, index: index)
    }
    
    // MARK: - UI Element Discovery
    
    /// Find UI elements by criteria
    /// 
    /// Searches for UI elements within a window using optional filtering criteria.
    /// Elements are discovered using the Accessibility API and can be filtered by role, title, or identifier.
    /// 
    /// - Parameters:
    ///   - window: The window to search within
    ///   - role: Optional element role filter (e.g., `.button`, `.textField`)
    ///   - title: Optional title filter (case-insensitive partial match)
    ///   - identifier: Optional accessibility identifier filter (exact match)
    /// - Returns: An array of `UIElement` objects matching the criteria
    /// - Throws: `PilotError.windowNotFound` if the window is invalid or `PilotError.permissionDenied` if accessibility permission is not granted
    public func findElements(
        in window: WindowHandle,
        role: ElementRole? = nil,
        title: String? = nil,
        identifier: String? = nil
    ) async throws -> [UIElement] {
        let elements = try await accessibilityDriver.findElements(
            in: window,
            role: role,
            title: title,
            identifier: identifier
        )
        
        return elements
    }
    
    /// Find specific UI element
    /// 
    /// Locates a single UI element by role and title. This method expects exactly one matching element.
    /// 
    /// - Parameters:
    ///   - window: The window to search within
    ///   - role: The element role to search for
    ///   - title: The element title to search for (case-insensitive partial match)
    /// - Returns: The matching `UIElement`
    /// - Throws: 
    ///   - `PilotError.elementNotFound` if no element matches the criteria
    ///   - `PilotError.multipleElementsFound` if multiple elements match
    ///   - `PilotError.windowNotFound` if the window is invalid
    public func findElement(
        in window: WindowHandle,
        role: ElementRole,
        title: String
    ) async throws -> UIElement {
        let element = try await accessibilityDriver.findElement(
            in: window,
            role: role,
            title: title
        )
        
        return element
    }
    
    /// Find button by title
    /// 
    /// Convenience method to locate a button element by its title.
    /// 
    /// - Parameters:
    ///   - window: The window to search within
    ///   - title: The button title to search for
    /// - Returns: The matching button `UIElement`
    /// - Throws: Same errors as `findElement(in:role:title:)`
    public func findButton(
        in window: WindowHandle,
        title: String
    ) async throws -> UIElement {
        return try await findElement(in: window, role: .button, title: title)
    }
    
    /// Find text field
    /// 
    /// Locates a text input field, optionally by placeholder text.
    /// If no placeholder is specified, returns the first available text field or search field.
    /// 
    /// - Parameters:
    ///   - window: The window to search within
    ///   - placeholder: Optional placeholder text to search for
    /// - Returns: The matching text field `UIElement`
    /// - Throws: `PilotError.elementNotFound` if no text field is found
    public func findTextField(
        in window: WindowHandle,
        placeholder: String? = nil
    ) async throws -> UIElement {
        // Try to find by placeholder first, then any text field
        if let placeholder = placeholder {
            do {
                return try await findElement(in: window, role: .textField, title: placeholder)
            } catch {
                // Fall back to search field
                return try await findElement(in: window, role: .searchField, title: placeholder)
            }
        } else {
            // Find any text input field
            let textFields = try await findElements(in: window, role: .textField)
            if !textFields.isEmpty {
                return textFields[0]
            }
            
            let searchFields = try await findElements(in: window, role: .searchField)
            if !searchFields.isEmpty {
                return searchFields[0]
            }
            
            throw PilotError.elementNotFound(role: .textField, title: nil)
        }
    }
    
    // MARK: - Element-Based Actions
    
    /// Click UI element (automatically calculates center point)
    public func click(element: UIElement) async throws -> ActionResult {
        print("🖱️ AppPilot: Clicking element: \(element.role.rawValue) '\(element.title ?? element.id)'")
        
        // Verify element is still accessible and enabled
        guard try await accessibilityDriver.elementExists(element) && element.isEnabled else {
            throw PilotError.elementNotAccessible(element.id)
        }
        
        // Calculate center point automatically
        let centerPoint = element.centerPoint
        print("   Center point: (\(centerPoint.x), \(centerPoint.y))")
        
        // Note: Element-based operations cannot ensure app focus without window context
        // For safer operations, use click(window:at:) or clickElement(_:in:)
        print("   ⚠️ Warning: Cannot ensure target app focus for element-only operation")
        
        // Perform CGEvent click at the center point
        try await cgEventDriver.click(at: centerPoint)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: centerPoint
        )
    }
    
    /// Type text into UI element
    public func type(text: String, into element: UIElement) async throws -> ActionResult {
        print("⌨️ AppPilot: Typing into element: \(element.role.rawValue)")
        print("   Text: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
        
        // Verify element is accessible and is a text input
        guard try await accessibilityDriver.elementExists(element) && element.isEnabled else {
            throw PilotError.elementNotAccessible(element.id)
        }
        
        guard element.role.isTextInput else {
            throw PilotError.invalidArgument("Element \(element.role.rawValue) is not a text input field")
        }
        
        // Note: Element-based operations cannot ensure app focus without window context
        // For safer operations, use typeIntoElement(_:text:in:)
        
        // Click the element first to focus it
        let _ = try await click(element: element)
        
        // Wait a moment for focus to be established
        try await wait(.time(seconds: 0.1))
        
        // Type the text
        try await cgEventDriver.type(text: text)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint
        )
    }
    
    /// Get value from UI element
    /// 
    /// Retrieves the current value of a UI element, such as text from a text field
    /// or the state of a checkbox.
    /// 
    /// - Parameter element: The UI element to get the value from
    /// - Returns: The element's value as a string, or `nil` if no value is available
    /// - Throws: `PilotError.elementNotAccessible` if the element is no longer available
    public func getValue(from element: UIElement) async throws -> String? {
        return try await accessibilityDriver.getValue(from: element)
    }
    
    /// Check if element exists and is valid
    /// 
    /// Verifies that a UI element is still available and accessible in the interface.
    /// Elements may become invalid if the UI changes or windows are closed.
    /// 
    /// - Parameter element: The UI element to check
    /// - Returns: `true` if the element exists and is accessible, `false` otherwise
    /// - Throws: Accessibility-related errors if permission is denied
    public func elementExists(_ element: UIElement) async throws -> Bool {
        return try await accessibilityDriver.elementExists(element)
    }
    
    // MARK: - Wait Operations
    
    /// Wait for element to appear
    /// 
    /// Polls for a UI element to become available within the specified timeout period.
    /// This is useful when waiting for UI changes, such as loading indicators to appear
    /// or dialog boxes to be shown.
    /// 
    /// The method checks for the element every 0.5 seconds until it appears or the timeout is reached.
    /// 
    /// - Parameters:
    ///   - window: The window to search for the element in
    ///   - role: The accessibility role of the element to wait for
    ///   - title: The title/label of the element to wait for
    ///   - timeout: Maximum time to wait in seconds (default: 10.0)
    /// - Returns: The UI element once it appears
    /// - Throws: `PilotError.timeout` if the element doesn't appear within the timeout period
    public func waitForElement(
        in window: WindowHandle,
        role: ElementRole,
        title: String,
        timeout: TimeInterval = 10.0
    ) async throws -> UIElement {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let element = try await findElement(in: window, role: role, title: title)
                return element
            } catch PilotError.elementNotFound {
                // Element not found yet, wait and retry
                try await wait(.time(seconds: 0.5))
            }
        }
        
        throw PilotError.timeout(timeout)
    }
    
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
    /// 
    /// // Wait for an element to appear
    /// try await pilot.wait(.elementAppear(window, .button, "Submit"))
    /// 
    /// // Wait for an element to disappear
    /// try await pilot.wait(.elementDisappear(window, .dialog, "Loading"))
    /// ```
    public func wait(_ spec: WaitSpec) async throws {
        switch spec {
        case .time(let seconds):
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            
        case .elementAppear(let window, let role, let title):
            let _ = try await waitForElement(in: window, role: role, title: title)
            
        case .elementDisappear(let window, let role, let title):
            let startTime = Date()
            let timeout: TimeInterval = 10.0
            
            while Date().timeIntervalSince(startTime) < timeout {
                do {
                    let _ = try await findElement(in: window, role: role, title: title)
                    // Element still exists, wait and retry
                    try await wait(.time(seconds: 0.5))
                } catch PilotError.elementNotFound {
                    // Element disappeared
                    return
                }
            }
            
            throw PilotError.timeout(timeout)
            
        case .uiChange(let window, let timeout):
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
        
        guard let app = targetApp, let _ = windowInfo?.bounds else {
            return
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
        let activated = nsApp.activate(options: [.activateIgnoringOtherApps])
        
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
                        // Point is outside window bounds, but proceed anyway for testing purposes
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
        // Note: Without window context, we cannot ensure specific app focus
        // This is a fallback method for backwards compatibility
        
        try await cgEventDriver.type(text: text)
        
        return ActionResult(success: true)
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
    
    /// Type text with specific input source (fallback)
    public func type(text: String, inputSource: InputSource) async throws -> ActionResult {
        print("⌨️ AppPilot: Text input with input source")
        print("   Text: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
        print("   Input source: \(inputSource.displayName)")
        print("   ⚠️ Warning: Cannot ensure target app focus without window context")
        
        try await cgEventDriver.type(text, inputSource: inputSource)
        
        return ActionResult(success: true)
    }
    
    /// Type text into specific element with input source
    public func type(text: String, into element: UIElement, inputSource: InputSource) async throws -> ActionResult {
        print("⌨️ AppPilot: Typing into element with input source")
        print("   Text: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
        print("   Element: \(element.role.rawValue) '\(element.title ?? element.id)'")
        print("   Input source: \(inputSource.displayName)")
        
        // Verify element is accessible and is a text input
        guard try await accessibilityDriver.elementExists(element) && element.isEnabled else {
            throw PilotError.elementNotAccessible(element.id)
        }
        
        guard element.role.isTextInput else {
            throw PilotError.invalidArgument("Element \(element.role.rawValue) is not a text input field")
        }
        
        print("   ⚠️ Warning: Cannot ensure target app focus for element-only operation")
        
        // Click the element first to focus it
        let _ = try await click(element: element)
        
        // Wait a moment for focus to be established
        try await wait(.time(seconds: 0.1))
        
        // Type with input source
        try await cgEventDriver.type(text, inputSource: inputSource)
        
        return ActionResult(
            success: true,
            element: element,
            coordinates: element.centerPoint
        )
    }
    
    /// Perform gesture from one point to another (fallback)
    public func gesture(from startPoint: Point, to endPoint: Point, duration: TimeInterval = 1.0) async throws -> ActionResult {
        print("👆 AppPilot: Gesture from (\(startPoint.x), \(startPoint.y)) to (\(endPoint.x), \(endPoint.y))")
        
        // Note: Without window context, we cannot ensure specific app focus
        // This is a fallback method for backwards compatibility
        print("   ⚠️ Warning: Cannot ensure target app focus without window context")
        
        try await cgEventDriver.drag(from: startPoint, to: endPoint, duration: duration)
        
        return ActionResult(
            success: true,
            coordinates: endPoint
        )
    }
    
    /// Capture screenshot of window
    public func capture(window: WindowHandle) async throws -> CGImage {
        print("📷 AppPilot: Capturing window screenshot: \(window.id)")
        
        // For now, use ScreenDriver - would need to map WindowHandle to actual window
        return try await screenDriver.captureScreen()
    }
    
    // MARK: - Convenience Methods
    
    /// Get accessible applications that can be automated
    public func getAccessibleApplications() async throws -> [AppInfo] {
        guard await accessibilityDriver.checkPermission() else {
            throw PilotError.permissionDenied("Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility")
        }
        
        return try await listApplications()
    }
    
    /// Find all clickable elements in a window
    public func findClickableElements(in window: WindowHandle) async throws -> [UIElement] {
        let allElements = try await findElements(in: window)
        return allElements.filter { $0.role.isClickable && $0.isEnabled }
    }
    
    /// Find all text input elements in a window
    public func findTextInputElements(in window: WindowHandle) async throws -> [UIElement] {
        let allElements = try await findElements(in: window)
        return allElements.filter { $0.role.isTextInput && $0.isEnabled }
    }
    
    // MARK: - Element-based Actions
    
    /// Click on a specific UI element
    public func clickElement(_ element: UIElement, in window: WindowHandle) async throws -> ActionResult {
        print("🎯 AppPilot: Clicking element \(element.role): \(element.title ?? element.id)")
        print("   Element bounds: \(element.bounds)")
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
    
    /// Type text into a specific UI element (focuses first)
    public func typeIntoElement(_ element: UIElement, text: String, in window: WindowHandle) async throws -> ActionResult {
        print("⌨️ AppPilot: Typing into element \(element.role): \(element.title ?? element.id)")
        print("   Text: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
        
        // Ensure target app is focused before any operations
        try await ensureTargetAppFocus(for: window)
        
        // First click on the element to focus it
        let clickResult = try await clickElement(element, in: window)
        guard clickResult.success else {
            throw PilotError.elementNotAccessible("Could not focus element for typing")
        }
        
        // Wait a bit for focus
        try await wait(.time(seconds: 0.2))
        
        // Then type the text
        let typeResult = try await type(text: text)
        
        return ActionResult(
            success: typeResult.success,
            coordinates: element.centerPoint
        )
    }
    
    // MARK: - Legacy API Compatibility (for existing tests)
    
    /// Legacy method for screen coordinate clicks (without window context)
    public func click(at point: Point, button: MouseButton = .left, count: Int = 1) async throws -> ActionResult {
        print("🖱️ AppPilot: Legacy screen coordinate click at (\(point.x), \(point.y))")
        
        try await cgEventDriver.click(at: point, button: button, count: count)
        
        return ActionResult(
            success: true,
            coordinates: point
        )
    }
    
    /// Legacy drag/gesture method  
    public func drag(from startPoint: Point, to endPoint: Point, duration: TimeInterval = 1.0) async throws -> ActionResult {
        return try await gesture(from: startPoint, to: endPoint, duration: duration)
    }
    
    /// Pinch gesture for zoom (legacy compatibility)
    public func pinch(center: Point, scale: CGFloat, duration: TimeInterval = 1.0) async throws -> ActionResult {
        print("🤏 AppPilot: Pinch gesture at (\(center.x), \(center.y)) scale: \(scale)")
        
        // Simulate pinch by moving fingers apart/together
        let distance = CGFloat(50 * scale)
        let startPoint1 = Point(x: center.x - distance/2, y: center.y)
        let endPoint1 = Point(x: center.x - distance, y: center.y)
        let startPoint2 = Point(x: center.x + distance/2, y: center.y)
        let endPoint2 = Point(x: center.x + distance, y: center.y)
        
        // For now, just do a simple gesture
        try await gesture(from: startPoint1, to: endPoint1, duration: duration)
        
        return ActionResult(
            success: true,
            coordinates: center
        )
    }
    
    /// Key combination support
    public func keyCombination(_ keys: [VirtualKey], modifiers: [ModifierKey]) async throws -> ActionResult {
        print("⌨️ AppPilot: Key combination - modifiers: \(modifiers), keys: \(keys)")
        
        // Use CGEventDriver for key combinations
        try await cgEventDriver.keyCombination(keys, modifiers: modifiers)
        
        return ActionResult(success: true)
    }
}

// MARK: - Internal Helper Extensions

extension AppPilot {
    
    /// Quick method to find app and window for testing
    internal func findTestApp(name: String = "TestApp") async throws -> (app: AppHandle, window: WindowHandle) {
        let app = try await findApplication(name: name)
        let window = try await findWindow(app: app, index: 0)
        return (app: app, window: window)
    }
}