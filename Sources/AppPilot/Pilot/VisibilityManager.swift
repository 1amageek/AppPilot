import Foundation

public actor VisibilityManager {
    private let accessibilityDriver: AccessibilityDriver
    private let missionControlDriver: MissionControlDriver
    
    private struct RestoreState {
        let window: WindowID
        let wasMinimized: Bool
        let originalSpace: Int?
        let originalForegroundApp: AppID?
    }
    
    private var restoreStates: [WindowID: RestoreState] = [:]
    
    public init(
        accessibilityDriver: AccessibilityDriver,
        missionControlDriver: MissionControlDriver
    ) {
        self.accessibilityDriver = accessibilityDriver
        self.missionControlDriver = missionControlDriver
    }
    
    public func prepareWindow(_ window: WindowID, policy: Policy) async throws {
        switch policy {
        case .STAY_HIDDEN:
            // No visibility changes needed
            return
            
        case .UNMINIMIZE(let tempMs):
            try await unminimizeTemporarily(window, durationMs: tempMs)
            
        case .BRING_FORE_TEMP(let restoreApp):
            try await bringToForegroundTemporarily(window, restoreApp: restoreApp)
        }
    }
    
    public func restoreWindow(_ window: WindowID) async throws {
        guard let state = restoreStates[window] else {
            return
        }
        
        defer {
            restoreStates[window] = nil
        }
        
        // Restore minimized state
        if state.wasMinimized {
            let path = AXPath(components: ["AXMinimized"])
            try await accessibilityDriver.setValue("true", at: path, in: window)
        }
        
        // Restore original space
        if let originalSpace = state.originalSpace {
            let currentSpace = try await missionControlDriver.getSpaceForWindow(window)
            if currentSpace != originalSpace {
                try await missionControlDriver.moveWindow(window, toSpace: originalSpace)
            }
        }
        
        // Restore original foreground app
        if state.originalForegroundApp != nil {
            // Activate original app
            let _ = AppleEventSpec(eventClass: "misc", eventID: "actv", parameters: nil)
            // This would need AppleEventDriver instance
        }
    }
    
    private func unminimizeTemporarily(_ window: WindowID, durationMs: Int) async throws {
        // Check if minimized
        let tree = try await accessibilityDriver.getTree(for: window, depth: 1)
        let wasMinimized = checkIfMinimized(tree)
        
        if wasMinimized {
            // Store restore state
            restoreStates[window] = RestoreState(
                window: window,
                wasMinimized: true,
                originalSpace: nil,
                originalForegroundApp: nil
            )
            
            // Unminimize
            let path = AXPath(components: ["AXMinimized"])
            try await accessibilityDriver.setValue("false", at: path, in: window)
            
            // Wait for animation
            try await Task.sleep(nanoseconds: UInt64(durationMs) * 1_000_000)
        }
    }
    
    private func bringToForegroundTemporarily(_ window: WindowID, restoreApp: AppID) async throws {
        let currentSpace = try await missionControlDriver.getCurrentSpace()
        let windowSpace = try await missionControlDriver.getSpaceForWindow(window)
        
        // Store restore state
        restoreStates[window] = RestoreState(
            window: window,
            wasMinimized: false,
            originalSpace: windowSpace != currentSpace ? windowSpace : nil,
            originalForegroundApp: restoreApp
        )
        
        // Move to current space if needed
        if windowSpace != currentSpace {
            try await missionControlDriver.moveWindow(window, toSpace: currentSpace)
        }
        
        // Raise window
        let path = AXPath(components: ["AXRaise"])
        try await accessibilityDriver.performAction(.press, at: path, in: window)
    }
    
    private func checkIfMinimized(_ tree: AXNode) -> Bool {
        // Check if the window is minimized by examining the AX tree
        // A minimized window typically has specific characteristics:
        // 1. Frame might be empty or have zero size
        // 2. Limited or no visible children
        // 3. May not be on screen
        
        if let role = tree.role, role == "AXWindow" {
            // Check if window frame indicates minimized state
            if let frame = tree.frame {
                // Window with zero or very small frame is likely minimized
                if frame.width <= 1 || frame.height <= 1 {
                    return true
                }
                
                // Window positioned far off-screen might be minimized
                if frame.origin.x < -1000 || frame.origin.y < -1000 {
                    return true
                }
            }
            
            // Check for typical minimized window indicators
            // Minimized windows often have no or very few interactive children
            let interactiveChildren = tree.children.filter { child in
                guard let role = child.role else { return false }
                return ["AXButton", "AXTextField", "AXTextArea", "AXSlider", 
                       "AXTable", "AXList", "AXScrollArea"].contains(role)
            }
            
            // If window has frame but no interactive content, might be minimized
            if tree.frame != nil && interactiveChildren.isEmpty && tree.children.count < 3 {
                return true
            }
        }
        
        return false
    }
    
    private func checkIfMinimizedUsingScreenDriver(_ window: WindowID) async throws -> Bool {
        // Alternative method using ScreenDriver for cross-verification
        let screenDriver = DefaultScreenDriver()
        let windowInfo = try await screenDriver.getWindowInfo(window)
        return windowInfo.isMinimized
    }
}