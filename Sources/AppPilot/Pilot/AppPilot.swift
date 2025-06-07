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
    public func listApplications() async throws -> [AppInfo] {
        print("📱 AppPilot: Listing applications")
        return try await accessibilityDriver.getApplications()
    }
    
    /// Find application by bundle ID
    public func findApplication(bundleId: String) async throws -> AppHandle {
        print("🔍 AppPilot: Finding application with bundle ID: \(bundleId)")
        return try await accessibilityDriver.findApplication(bundleId: bundleId)
    }
    
    /// Find application by name
    public func findApplication(name: String) async throws -> AppHandle {
        print("🔍 AppPilot: Finding application with name: \(name)")
        return try await accessibilityDriver.findApplication(name: name)
    }
    
    /// Get windows for an application
    public func listWindows(app: AppHandle) async throws -> [WindowInfo] {
        print("🪟 AppPilot: Listing windows for app: \(app.id)")
        return try await accessibilityDriver.getWindows(for: app)
    }
    
    /// Find window by title
    public func findWindow(app: AppHandle, title: String) async throws -> WindowHandle {
        print("🔍 AppPilot: Finding window with title: \(title)")
        return try await accessibilityDriver.findWindow(app: app, title: title)
    }
    
    /// Find window by index
    public func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle {
        print("🔍 AppPilot: Finding window at index: \(index)")
        return try await accessibilityDriver.findWindow(app: app, index: index)
    }
    
    // MARK: - UI Element Discovery
    
    /// Find UI elements by criteria
    public func findElements(
        in window: WindowHandle,
        role: ElementRole? = nil,
        title: String? = nil,
        identifier: String? = nil
    ) async throws -> [UIElement] {
        print("🎯 AppPilot: Finding elements in window: \(window.id)")
        print("   Role: \(role?.rawValue ?? "any")")
        print("   Title: \(title ?? "any")")
        print("   Identifier: \(identifier ?? "any")")
        
        let elements = try await accessibilityDriver.findElements(
            in: window,
            role: role,
            title: title,
            identifier: identifier
        )
        
        print("✅ AppPilot: Found \(elements.count) elements")
        return elements
    }
    
    /// Find specific UI element
    public func findElement(
        in window: WindowHandle,
        role: ElementRole,
        title: String
    ) async throws -> UIElement {
        print("🎯 AppPilot: Finding element \(role.rawValue) with title: \(title)")
        
        let element = try await accessibilityDriver.findElement(
            in: window,
            role: role,
            title: title
        )
        
        print("✅ AppPilot: Found element: \(element.id)")
        return element
    }
    
    /// Find button by title
    public func findButton(
        in window: WindowHandle,
        title: String
    ) async throws -> UIElement {
        print("🔘 AppPilot: Finding button with title: \(title)")
        return try await findElement(in: window, role: .button, title: title)
    }
    
    /// Find text field
    public func findTextField(
        in window: WindowHandle,
        placeholder: String? = nil
    ) async throws -> UIElement {
        print("📝 AppPilot: Finding text field")
        
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
        print("   ⚠️ Warning: Cannot ensure target app focus for element-only operation")
        
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
    public func getValue(from element: UIElement) async throws -> String? {
        print("📖 AppPilot: Getting value from element: \(element.id)")
        return try await accessibilityDriver.getValue(from: element)
    }
    
    /// Check if element exists and is valid
    public func elementExists(_ element: UIElement) async throws -> Bool {
        return try await accessibilityDriver.elementExists(element)
    }
    
    // MARK: - Wait Operations
    
    /// Wait for element to appear
    public func waitForElement(
        in window: WindowHandle,
        role: ElementRole,
        title: String,
        timeout: TimeInterval = 10.0
    ) async throws -> UIElement {
        print("⏰ AppPilot: Waiting for element \(role.rawValue) with title: \(title)")
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let element = try await findElement(in: window, role: role, title: title)
                print("✅ AppPilot: Element appeared after \(String(format: "%.1f", Date().timeIntervalSince(startTime)))s")
                return element
            } catch PilotError.elementNotFound {
                // Element not found yet, wait and retry
                try await wait(.time(seconds: 0.5))
            }
        }
        
        throw PilotError.timeout(timeout)
    }
    
    /// Wait for condition
    public func wait(_ spec: WaitSpec) async throws {
        switch spec {
        case .time(let seconds):
            print("⏰ AppPilot: Wait for \(seconds) seconds")
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            
        case .elementAppear(let window, let role, let title):
            let _ = try await waitForElement(in: window, role: role, title: title)
            
        case .elementDisappear(let window, let role, let title):
            print("⏰ AppPilot: Waiting for element to disappear: \(role.rawValue) '\(title)'")
            let startTime = Date()
            let timeout: TimeInterval = 10.0
            
            while Date().timeIntervalSince(startTime) < timeout {
                do {
                    let _ = try await findElement(in: window, role: role, title: title)
                    // Element still exists, wait and retry
                    try await wait(.time(seconds: 0.5))
                } catch PilotError.elementNotFound {
                    // Element disappeared
                    print("✅ AppPilot: Element disappeared")
                    return
                }
            }
            
            throw PilotError.timeout(timeout)
            
        case .uiChange(let window, let timeout):
            print("⏰ AppPilot: Wait for UI change in window: \(window.id)")
            // Simplified implementation - just wait for time
            try await wait(.time(seconds: min(timeout, 5.0)))
        }
    }
    
    // MARK: - Application Focus Management
    
    /// Ensure target application and window are focused before operations
    private func ensureTargetAppFocus(for window: WindowHandle) async throws {
        print("🎯 AppPilot: Ensuring target app focus for window: \(window.id)")
        
        // Get window info to find the associated app
        let apps = try await listApplications()
        var targetApp: AppInfo?
        var windowInfo: WindowInfo?
        
        print("   Searching through \(apps.count) applications...")
        
        // Find which app owns this window
        for app in apps {
            print("   Checking app: \(app.name) (ID: \(app.id.id))")
            do {
                let windows = try await listWindows(app: app.id)
                print("     Found \(windows.count) windows for \(app.name)")
                
                for win in windows {
                    print("       Window: \(win.id.id) - '\(win.title ?? "No title")'")
                    if win.id == window {
                        targetApp = app
                        windowInfo = win
                        print("   ✅ Found window owner: \(app.name) (ID: \(app.id.id))")
                        break
                    }
                }
                
                if targetApp != nil { break }
            } catch {
                // Skip apps that can't be queried (might not have accessibility permission)
                print("     ⚠️ Skipping app \(app.name): \(error)")
                continue
            }
        }
        
        guard let app = targetApp, let windowBounds = windowInfo?.bounds else {
            print("⚠️ AppPilot: Could not find app for window, proceeding without focus")
            return
        }
        
        print("   Target app: \(app.name)")
        print("   Window bounds: \(windowBounds)")
        
        // Find the NSRunningApplication for activation
        let runningApps = NSWorkspace.shared.runningApplications
        guard let nsApp = runningApps.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier || $0.localizedName == app.name 
        }) else {
            print("⚠️ AppPilot: Could not find NSRunningApplication, proceeding without focus")
            return
        }
        
        // Check if app is already frontmost
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        if currentFrontmost?.processIdentifier == nsApp.processIdentifier {
            print("✅ AppPilot: Target app already focused")
            return
        }
        
        // Activate the target application
        print("   Activating target application...")
        let activated = nsApp.activate(options: [.activateIgnoringOtherApps])
        
        if activated {
            print("✅ AppPilot: Target app activated")
            
            // Wait for activation to complete
            try await wait(.time(seconds: 0.5))
            
            // Verify activation
            let newFrontmost = NSWorkspace.shared.frontmostApplication
            if newFrontmost?.processIdentifier == nsApp.processIdentifier {
                print("✅ AppPilot: Target app focus verified")
            } else {
                print("⚠️ AppPilot: App activation verification failed, but proceeding")
            }
        } else {
            print("⚠️ AppPilot: Failed to activate target app, proceeding anyway")
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
                    
                    print("   Validating coordinates against window bounds: \(bounds)")
                    
                    // Check if point is within window bounds (with some tolerance)
                    let tolerance: CGFloat = 50
                    let expandedBounds = CGRect(
                        x: bounds.minX - tolerance,
                        y: bounds.minY - tolerance,
                        width: bounds.width + tolerance * 2,
                        height: bounds.height + tolerance * 2
                    )
                    
                    if !expandedBounds.contains(CGPoint(x: point.x, y: point.y)) {
                        print("⚠️ AppPilot: Click point (\(point.x), \(point.y)) is outside window bounds \(bounds)")
                        print("   Proceeding anyway for testing purposes")
                    } else {
                        print("✅ AppPilot: Click point is within window bounds")
                    }
                    return
                }
            } catch {
                // Skip apps that can't be queried
                continue
            }
        }
        
        print("⚠️ AppPilot: Could not validate coordinates - window not found")
    }
    
    // MARK: - Fallback Coordinate Operations
    
    /// Click at coordinates (fallback when element detection fails)
    public func click(
        window: WindowHandle,
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1
    ) async throws -> ActionResult {
        print("🖱️ AppPilot: Focused coordinate click at (\(point.x), \(point.y))")
        print("   Button: \(button), Count: \(count)")
        
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
    public func type(text: String) async throws -> ActionResult {
        print("⌨️ AppPilot: Fallback text input")
        print("   Text: \(text.prefix(50))\(text.count > 50 ? "..." : "")")
        
        // Note: Without window context, we cannot ensure specific app focus
        // This is a fallback method for backwards compatibility
        print("   ⚠️ Warning: Cannot ensure target app focus without window context")
        
        try await cgEventDriver.type(text: text)
        
        return ActionResult(success: true)
    }
    
    // MARK: - Input Source Management
    
    /// Get current input source
    public func getCurrentInputSource() async throws -> InputSourceInfo {
        print("🌐 AppPilot: Getting current input source")
        let source = try await cgEventDriver.getCurrentInputSource()
        print("   Current: \(source.displayName) (\(source.identifier))")
        return source
    }
    
    /// Get all available input sources
    public func getAvailableInputSources() async throws -> [InputSourceInfo] {
        print("🌐 AppPilot: Getting available input sources")
        let sources = try await cgEventDriver.getAvailableInputSources()
        print("   Found \(sources.count) input sources")
        for source in sources {
            print("     - \(source.displayName) (\(source.identifier))")
        }
        return sources
    }
    
    /// Switch to specified input source
    public func switchInputSource(to source: InputSource) async throws {
        print("🌐 AppPilot: Switching input source to \(source.displayName)")
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