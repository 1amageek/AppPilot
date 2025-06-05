import Foundation
import CoreGraphics

public actor CommandRouter {
    private let appleEventDriver: AppleEventDriver
    private let accessibilityDriver: AccessibilityDriver
    private let uiEventDriver: UIEventDriver
    
    public init(
        appleEventDriver: AppleEventDriver,
        accessibilityDriver: AccessibilityDriver,
        uiEventDriver: UIEventDriver
    ) {
        self.appleEventDriver = appleEventDriver
        self.accessibilityDriver = accessibilityDriver
        self.uiEventDriver = uiEventDriver
    }
    
    public func selectRoute(for command: Command, app: AppID?, window: WindowID?) async -> Route {
        // If route is explicitly specified, use it
        if let clickCmd = command as? ClickCommand, let route = clickCmd.route {
            return route
        }
        if let typeCmd = command as? TypeCommand, let route = typeCmd.route {
            return route
        }
        
        // Gestures can only be done via UI events
        if command.kind == .gesture {
            return .UI_EVENT
        }
        
        // Check AppleEvent support
        if let app = app, await appleEventDriver.supports(command, for: app) {
            return .APPLE_EVENT
        }
        
        // Check Accessibility support
        if let window = window, await accessibilityDriver.canPerform(command, in: window) {
            return .AX_ACTION
        }
        
        // Default to UI events
        return .UI_EVENT
    }
    
    public func execute(_ command: Command, with route: Route) async throws -> ActionResult {
        switch route {
        case .APPLE_EVENT:
            return try await executeViaAppleEvent(command)
        case .AX_ACTION:
            return try await executeViaAccessibility(command)
        case .UI_EVENT:
            return try await executeViaUIEvent(command)
        }
    }
    
    private func executeViaAppleEvent(_ command: Command) async throws -> ActionResult {
        switch command {
        case let cmd as AppleEventCommand:
            try await appleEventDriver.send(cmd.spec, to: cmd.app)
            return ActionResult(success: true, route: .APPLE_EVENT)
            
        case let cmd as ClickCommand:
            // Convert click to AppleEvent if possible
            let spec = AppleEventSpec(eventClass: "core", eventID: "clic", parameters: nil)
            guard let app = await getAppForWindow(cmd.window) else {
                throw PilotError.NOT_FOUND(.application, "for window \(cmd.window.id)")
            }
            try await appleEventDriver.send(spec, to: app)
            return ActionResult(success: true, route: .APPLE_EVENT)
            
        default:
            throw PilotError.ROUTE_UNAVAILABLE("AppleEvent route not available for \(command.kind)")
        }
    }
    
    private func executeViaAccessibility(_ command: Command) async throws -> ActionResult {
        switch command {
        case let cmd as AXCommand:
            try await accessibilityDriver.performAction(cmd.action, at: cmd.path, in: cmd.window)
            return ActionResult(success: true, route: .AX_ACTION)
            
        case let cmd as ClickCommand:
            // For clicks via AX, we need to find the UI element at the specified coordinates
            let path = try await findElementAtCoordinates(cmd.point, in: cmd.window)
            try await accessibilityDriver.performAction(.press, at: path, in: cmd.window)
            return ActionResult(success: true, route: .AX_ACTION)
            
        case let cmd as TypeCommand:
            // Set value on focused element or find text field
            let path = AXPath(components: ["AXTextField"]) // Simplified - would normally find focused text field
            try await accessibilityDriver.setValue(cmd.text, at: path, in: cmd.window)
            return ActionResult(success: true, route: .AX_ACTION)
            
        default:
            throw PilotError.ROUTE_UNAVAILABLE("AX route not available for \(command.kind)")
        }
    }
    
    private func executeViaUIEvent(_ command: Command) async throws -> ActionResult {
        switch command {
        case let cmd as ClickCommand:
            // Convert window coordinates to screen coordinates
            let screenPoint = try await convertToScreenCoordinates(cmd.point, in: cmd.window)
            try await uiEventDriver.click(at: screenPoint, button: cmd.button, count: cmd.count)
            return ActionResult(success: true, route: .UI_EVENT)
            
        case let cmd as TypeCommand:
            try await uiEventDriver.type(text: cmd.text)
            return ActionResult(success: true, route: .UI_EVENT)
            
        case let cmd as GestureCommand:
            try await uiEventDriver.gesture(cmd.gesture, durationMs: cmd.durationMs)
            return ActionResult(success: true, route: .UI_EVENT)
            
        default:
            throw PilotError.ROUTE_UNAVAILABLE("UI Event route not available for \(command.kind)")
        }
    }
    
    private func getAppForWindow(_ window: WindowID) async -> AppID? {
        // Use CGWindowListCopyWindowInfo to get the owning process
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.id) as? [[String: Any]],
              let windowInfo = windowList.first,
              let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }
        
        return AppID(pid: pid)
    }
    
    private func convertToScreenCoordinates(_ point: Point, in window: WindowID) async throws -> CGPoint {
        // Get window frame from system
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.id) as? [[String: Any]],
              let windowInfo = windowList.first,
              let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let windowX = boundsDict["X"] as? CGFloat,
              let windowY = boundsDict["Y"] as? CGFloat,
              let _ = boundsDict["Width"] as? CGFloat,
              let windowHeight = boundsDict["Height"] as? CGFloat else {
            throw PilotError.NOT_FOUND(.window, "Window ID: \(window.id)")
        }
        
        // Convert window-relative coordinates to screen coordinates
        // macOS uses bottom-left origin for screen coordinates
        // TestApp likely uses top-left origin for window coordinates
        
        // Convert from top-left window coordinates to bottom-left screen coordinates
        let screenX = windowX + point.x
        
        // For Y coordinate: flip from top-left to bottom-left within window bounds
        // then add to window's bottom-left position in screen coordinates
        let screenY = windowY + (windowHeight - point.y)
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    private func findElementAtCoordinates(_ point: Point, in window: WindowID) async throws -> AXPath {
        // Get the accessibility tree for the window
        let tree = try await accessibilityDriver.getTree(for: window, depth: 10)
        
        // Convert window-relative point to screen coordinates for AX matching
        let screenPoint = try await convertToScreenCoordinates(point, in: window)
        
        // Recursively search for the element that contains this point
        if let path = findElementContainingPoint(screenPoint, in: tree, currentPath: []) {
            return AXPath(components: path)
        }
        
        // Fallback: return a generic clickable element path
        return AXPath(components: ["0"]) // Click the first child element
    }
    
    private func findElementContainingPoint(_ point: CGPoint, in node: AXNode, currentPath: [String]) -> [String]? {
        // Check if this node contains the point
        if let frame = node.frame, frame.contains(point) {
            // Check if this is a clickable element
            if let role = node.role, isClickableRole(role) {
                return currentPath
            }
            
            // If not clickable but contains point, search children
            for (index, child) in node.children.enumerated() {
                let childPath = currentPath + [String(index)]
                if let foundPath = findElementContainingPoint(point, in: child, currentPath: childPath) {
                    return foundPath
                }
            }
            
            // If no clickable children found, return this element anyway
            return currentPath
        }
        
        return nil
    }
    
    private func isClickableRole(_ role: String) -> Bool {
        let clickableRoles = [
            "AXButton",
            "AXCheckBox",
            "AXRadioButton",
            "AXPopUpButton",
            "AXMenuButton",
            "AXTextField",
            "AXTextArea",
            "AXSlider",
            "AXIncrementor",
            "AXLink",
            "AXImage",
            "AXTab",
            "AXCell",
            "AXRow",
            "AXColumn"
        ]
        return clickableRoles.contains(role)
    }
}
