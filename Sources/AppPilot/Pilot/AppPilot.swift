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
    
    // MARK: - Query Operations
    
    /// Get all running applications
    public func listApplications() async throws -> [AppInfo] {
        print("📱 AppPilot: Listing applications")
        
        guard let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw PilotError.osFailure(api: "CGWindowListCopyWindowInfo", code: -1)
        }
        
        var appDict: [pid_t: AppInfo] = [:]
        
        for windowInfo in windowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let appName = windowInfo[kCGWindowOwnerName as String] as? String else {
                continue
            }
            
            if appDict[pid] == nil {
                let bundleId = getBundleIdentifier(for: pid)
                let isActive = isApplicationActive(pid: pid)
                
                appDict[pid] = AppInfo(
                    id: AppID(pid: pid),
                    name: appName,
                    bundleIdentifier: bundleId,
                    isActive: isActive
                )
            }
        }
        
        let apps = Array(appDict.values).sorted { $0.name < $1.name }
        print("✅ AppPilot: Found \(apps.count) applications")
        return apps
    }
    
    /// Get windows for an application
    public func listWindows(app: AppID) async throws -> [WindowInfo] {
        print("🪟 AppPilot: Listing windows for app PID \(app.pid)")
        
        guard let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw PilotError.osFailure(api: "CGWindowListCopyWindowInfo", code: -1)
        }
        
        var windows: [WindowInfo] = []
        
        for windowInfo in windowList {
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  pid == app.pid,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            let title = windowInfo[kCGWindowName as String] as? String
            let appName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            let isMinimized = isWindowMinimized(windowID: windowID)
            
            windows.append(WindowInfo(
                id: WindowID(id: windowID),
                title: title,
                bounds: bounds,
                isMinimized: isMinimized,
                appName: appName
            ))
        }
        
        print("✅ AppPilot: Found \(windows.count) windows")
        return windows
    }
    
    /// Capture screenshot of window
    public func capture(window: WindowID) async throws -> CGImage {
        print("📷 AppPilot: Capturing window \(window.id)")
        
        // Use ScreenDriver for screenshot capture
        let image = try await screenDriver.captureWindow(window)
        
        print("✅ AppPilot: Screenshot captured")
        return image
    }
    
    /// Get window bounds in screen coordinates
    public func getWindowBounds(window: WindowID) async throws -> CGRect {
        print("📐 AppPilot: Getting bounds for window \(window.id)")
        
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.id) as? [[String: Any]],
              let windowInfo = windowList.first,
              let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            throw PilotError.windowNotFound(window)
        }
        
        let bounds = CGRect(x: x, y: y, width: width, height: height)
        print("✅ AppPilot: Window bounds: \(bounds)")
        return bounds
    }
    
    /// Subscribe to UI changes in window
    public func subscribeAX(window: WindowID) -> AsyncStream<AXEvent> {
        print("👀 AppPilot: Subscribing to AX events for window \(window.id)")
        
        return AsyncStream<AXEvent> { continuation in
            Task {
                // TODO: Implement real AXObserver-based event monitoring
                // This is a placeholder implementation for development
                continuation.yield(AXEvent(
                    type: .created,
                    windowID: window,
                    description: "Placeholder AX event"
                ))
                continuation.finish()
            }
        }
    }
    
    // MARK: - Coordinate Conversion Helper
    
    /// Convert window-relative point to screen coordinates
    public func windowToScreen(point: Point, window: WindowID) async throws -> Point {
        let bounds = try await getWindowBounds(window: window)
        return Point(x: bounds.minX + point.x, y: bounds.minY + point.y)
    }
    
    // MARK: - Screen Automation Operations (Global Coordinates)
    
    /// Click at screen coordinates
    public func click(
        at screenPoint: Point,
        button: MouseButton = .left,
        count: Int = 1
    ) async throws -> ActionResult {
        print("🖱️ AppPilot: Click at screen coordinates (\(screenPoint.x), \(screenPoint.y))")
        
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        // Validate coordinates
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        if screenPoint.x < 0 || screenPoint.x > screenBounds.width ||
           screenPoint.y < 0 || screenPoint.y > screenBounds.height {
            throw PilotError.coordinateOutOfBounds(screenPoint)
        }
        
        // Use new CGEventDriver extension method for click
        for _ in 0..<count {
            try await cgEventDriver.click(at: screenPoint, button: button)
            if count > 1 {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms between clicks
            }
        }
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: screenPoint
        )
    }
    
    /// Type text to currently focused application
    public func type(text: String) async throws -> ActionResult {
        print("⌨️ AppPilot: Type text '\(text)'")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        guard !text.isEmpty else {
            throw PilotError.invalidArgument("Text cannot be empty")
        }
        
        try await cgEventDriver.type(text)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: nil
        )
    }
    
    /// Perform drag from point to point
    public func drag(
        from startPoint: Point,
        to endPoint: Point,
        duration: TimeInterval = 1.0,
        button: MouseButton = .left
    ) async throws -> ActionResult {
        print("👆 AppPilot: Drag from (\(startPoint.x), \(startPoint.y)) to (\(endPoint.x), \(endPoint.y))")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        guard duration > 0 else {
            throw PilotError.invalidArgument("Duration must be positive")
        }
        
        try await cgEventDriver.drag(from: startPoint, to: endPoint, duration: duration, button: button)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: endPoint
        )
    }
    
    /// Pinch gesture (zoom in/out)
    public func pinch(
        center: Point,
        scale: Double,
        duration: TimeInterval = 0.5
    ) async throws -> ActionResult {
        print("🤏 AppPilot: Pinch at (\(center.x), \(center.y)) scale=\(scale)")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        guard scale > 0 else {
            throw PilotError.invalidArgument("Scale must be positive")
        }
        
        // Simulate pinch with scroll + modifier keys
        try await cgEventDriver.moveCursor(to: center)
        try await cgEventDriver.keyDown(code: ModifierKey.control.keyCode)
        let deltaY = scale > 1.0 ? 10.0 : -10.0
        try await cgEventDriver.scroll(deltaX: 0, deltaY: deltaY, at: center)
        try await cgEventDriver.keyUp(code: ModifierKey.control.keyCode)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: center
        )
    }
    
    /// Rotation gesture
    public func rotate(
        center: Point,
        degrees: Double,
        duration: TimeInterval = 0.5
    ) async throws -> ActionResult {
        print("🔄 AppPilot: Rotate at (\(center.x), \(center.y)) by \(degrees)°")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        // Simulate rotation with circular movement
        let radius: Double = 50.0
        let steps = max(20, Int(duration * 30))
        let angleStep = (degrees * .pi / 180) / Double(steps)
        
        for i in 0..<steps {
            let angle = angleStep * Double(i)
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            try await cgEventDriver.moveCursor(to: Point(x: x, y: y))
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000 / Double(steps)))
        }
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: center
        )
    }
    
    /// Swipe gesture
    public func swipe(
        from startPoint: Point,
        direction: SwipeDirection,
        distance: Double = 100,
        duration: TimeInterval = 0.3
    ) async throws -> ActionResult {
        print("👋 AppPilot: Swipe from (\(startPoint.x), \(startPoint.y)) \(direction)")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        guard distance > 0 else {
            throw PilotError.invalidArgument("Distance must be positive")
        }
        
        try await cgEventDriver.swipe(from: startPoint, direction: direction, distance: distance, duration: duration)
        
        let vector = direction.vector
        let endPoint = Point(
            x: startPoint.x + vector.x * distance,
            y: startPoint.y + vector.y * distance
        )
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: endPoint
        )
    }
    
    /// Scroll at specific point
    public func scroll(
        at point: Point,
        deltaX: Double = 0,
        deltaY: Double = 0
    ) async throws -> ActionResult {
        print("📜 AppPilot: Scroll at (\(point.x), \(point.y))")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        try await cgEventDriver.scroll(deltaX: deltaX, deltaY: deltaY, at: point)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: point
        )
    }
    
    /// Double-tap then drag (common in map applications)
    public func doubleTapAndDrag(
        tapPoint: Point,
        dragTo endPoint: Point,
        duration: TimeInterval = 1.0
    ) async throws -> ActionResult {
        print("🖱️➕👆 AppPilot: Double-tap and drag")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        // Implement double-tap and drag using extension methods
        try await cgEventDriver.doubleClick(at: tapPoint)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms pause
        try await cgEventDriver.drag(from: tapPoint, to: endPoint, duration: duration)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: endPoint
        )
    }
    
    /// Key press with modifiers
    public func keyPress(
        key: VirtualKey,
        modifiers: [ModifierKey] = [],
        duration: TimeInterval = 0.1
    ) async throws -> ActionResult {
        print("⌨️ AppPilot: Key press \(key)")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        try await cgEventDriver.keyPress(key, modifiers: modifiers, hold: duration)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: nil
        )
    }
    
    /// Key combination (e.g., Cmd+C)
    public func keyCombination(
        _ keys: [VirtualKey],
        modifiers: [ModifierKey]
    ) async throws -> ActionResult {
        print("⌨️ AppPilot: Key combination")
        
        guard AXIsProcessTrusted() else {
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent automation")
        }
        
        try await cgEventDriver.keyCombination(keys, modifiers: modifiers)
        
        return ActionResult(
            success: true,
            timestamp: Date(),
            screenCoordinates: nil
        )
    }
    
    /// Wait for condition
    public func wait(_ spec: WaitSpec) async throws {
        switch spec {
        case .time(let seconds):
            print("⏰ AppPilot: Wait for \(seconds) seconds")
            guard seconds > 0 else {
                throw PilotError.invalidArgument("Wait time must be positive")
            }
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            
        case .uiChange(let window, let timeout):
            print("👀 AppPilot: Wait for UI change in window \(window.id) (timeout: \(timeout)s)")
            // TODO: Implement real AX event monitoring for UI changes
            // This is a placeholder implementation for development
            try await Task.sleep(nanoseconds: UInt64(min(timeout, 0.1) * 1_000_000_000))
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getBundleIdentifier(for pid: pid_t) -> String? {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.bundleIdentifier
    }
    
    private func isApplicationActive(pid: pid_t) -> Bool {
        let runningApp = NSRunningApplication(processIdentifier: pid)
        return runningApp?.isActive ?? false
    }
    
    private func isWindowMinimized(windowID: CGWindowID) -> Bool {
        // This is a simplified check
        // In a real implementation, you would use more sophisticated detection
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let windowInfo = windowList.first else {
            return false
        }
        
        // Check if window is on screen (simplified logic)
        if let onScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool {
            return !onScreen
        }
        
        return false
    }
}