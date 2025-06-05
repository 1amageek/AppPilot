import Foundation
import ApplicationServices
import CoreGraphics

public protocol AccessibilityDriver: Sendable {
    func getTree(for window: WindowID, depth: Int) async throws -> AXNode
    func performAction(_ action: AXAction, at path: AXPath, in window: WindowID) async throws
    func canPerform(_ command: Command, in window: WindowID) async -> Bool
    func setValue(_ value: String, at path: AXPath, in window: WindowID) async throws
    func observeEvents(for window: WindowID, mask: AXMask) async -> AsyncStream<AXEvent>
}

public actor DefaultAccessibilityDriver: AccessibilityDriver {
    private var observers: [WindowID: ObserverInfo] = [:]
    
    private struct ObserverInfo {
        let observer: AXObserver
        let element: AXUIElement
        let runLoopSource: CFRunLoopSource
    }
    
    public init() {}
    
    public func getTree(for window: WindowID, depth: Int) async throws -> AXNode {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            throw PilotError.PERMISSION_DENIED(.accessibility)
        }
        
        // Get the AXUIElement for the window
        let element = try getWindowElement(windowID: window)
        
        // Build the tree recursively
        return try buildAXTree(element: element, depth: depth, currentDepth: 0)
    }
    
    public func performAction(_ action: AXAction, at path: AXPath, in window: WindowID) async throws {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            throw PilotError.PERMISSION_DENIED(.accessibility)
        }
        
        // Get the window element
        let windowElement = try getWindowElement(windowID: window)
        
        // Navigate to the target element using the path
        let targetElement = try navigateToElement(from: windowElement, path: path)
        
        // Perform the action
        let result = AXUIElementPerformAction(targetElement, action.rawValue as CFString)
        
        if result != AXError.success {
            throw PilotError.OS_FAILURE(api: "AXUIElementPerformAction", status: result.rawValue)
        }
    }
    
    public func canPerform(_ command: Command, in window: WindowID) async -> Bool {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            return false
        }
        
        // Check if AX can handle this command type
        switch command.kind {
        case .click, .type, .axAction:
            // Try to get the window element to ensure it's accessible
            do {
                let _ = try getWindowElement(windowID: window)
                return true
            } catch {
                // If we can't get the window element, AX route won't work
                return false
            }
        case .gesture:
            return false // Complex gestures should use UI events
        case .appleEvent:
            return false // Apple events use different driver
        }
    }
    
    public func setValue(_ value: String, at path: AXPath, in window: WindowID) async throws {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            throw PilotError.PERMISSION_DENIED(.accessibility)
        }
        
        // Get the window element
        let windowElement = try getWindowElement(windowID: window)
        
        // Navigate to the target element
        let targetElement = try navigateToElement(from: windowElement, path: path)
        
        // Set the value
        let result = AXUIElementSetAttributeValue(
            targetElement,
            kAXValueAttribute as CFString,
            value as CFTypeRef
        )
        
        if result != AXError.success {
            throw PilotError.OS_FAILURE(api: "AXUIElementSetAttributeValue", status: result.rawValue)
        }
    }
    
    public func observeEvents(for window: WindowID, mask: AXMask) async -> AsyncStream<AXEvent> {
        AsyncStream<AXEvent> { continuation in
            Task {
                // Check permissions
                guard AXIsProcessTrusted() else {
                    continuation.finish()
                    return
                }
                
                // Get window element
                guard let windowElement = try? self.getWindowElement(windowID: window) else {
                    continuation.finish()
                    return
                }
                
                // Get the process ID
                var pid: pid_t = 0
                let pidResult = AXUIElementGetPid(windowElement, &pid)
                if pidResult != AXError.success {
                    continuation.finish()
                    return
                }
                
                // Create observer
                var observer: AXObserver?
                let observerResult = AXObserverCreate(pid, { (observer, element, notification, refcon) in
                    // This callback will be called when events occur
                    guard let refcon = refcon else { return }
                    let cont = Unmanaged<StreamContinuation>.fromOpaque(refcon).takeUnretainedValue()
                    
                    // Map notification to event type
                    let eventType: AXEvent.EventType
                    switch notification as String {
                    case kAXCreatedNotification:
                        eventType = .created
                    case kAXMovedNotification:
                        eventType = .moved
                    case kAXResizedNotification:
                        eventType = .resized
                    case kAXTitleChangedNotification:
                        eventType = .titleChanged
                    case kAXFocusedUIElementChangedNotification:
                        eventType = .focusChanged
                    case kAXValueChangedNotification:
                        eventType = .valueChanged
                    default:
                        return // Unknown notification
                    }
                    
                    let event = AXEvent(
                        type: eventType,
                        window: cont.windowID,
                        timestamp: Date(),
                        data: AXEvent.EventData(description: notification as String)
                    )
                    
                    cont.yield(event)
                }, &observer)
                
                if observerResult != AXError.success {
                    continuation.finish()
                    return
                }
                
                guard let axObserver = observer else {
                    continuation.finish()
                    return
                }
                
                // Wrap continuation for callback
                let streamContinuation = StreamContinuation(
                    windowID: window,
                    yield: { event in
                        continuation.yield(event)
                    }
                )
                
                let refcon = Unmanaged.passUnretained(streamContinuation).toOpaque()
                
                // Add notifications based on mask
                if mask.contains(.created) {
                    AXObserverAddNotification(axObserver, windowElement, kAXCreatedNotification as CFString, refcon)
                }
                if mask.contains(.moved) {
                    AXObserverAddNotification(axObserver, windowElement, kAXMovedNotification as CFString, refcon)
                }
                if mask.contains(.resized) {
                    AXObserverAddNotification(axObserver, windowElement, kAXResizedNotification as CFString, refcon)
                }
                if mask.contains(.titleChanged) {
                    AXObserverAddNotification(axObserver, windowElement, kAXTitleChangedNotification as CFString, refcon)
                }
                if mask.contains(.focusChanged) {
                    AXObserverAddNotification(axObserver, windowElement, kAXFocusedUIElementChangedNotification as CFString, refcon)
                }
                if mask.contains(.valueChanged) {
                    AXObserverAddNotification(axObserver, windowElement, kAXValueChangedNotification as CFString, refcon)
                }
                
                // Get run loop source and add to main run loop
                let runLoopSource = AXObserverGetRunLoopSource(axObserver)
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
                
                // Store observer info
                let info = ObserverInfo(
                    observer: axObserver,
                    element: windowElement,
                    runLoopSource: runLoopSource
                )
                self.storeObserver(window, info: info)
                
                // Handle cleanup on termination
                continuation.onTermination = { _ in
                    Task {
                        await self.cleanupObserver(window)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getWindowElement(windowID: WindowID) throws -> AXUIElement {
        // Get window info to find the owning process
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID.id) as? [[String: Any]],
              let windowInfo = windowList.first,
              let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            throw PilotError.NOT_FOUND(.window, "Window ID: \(windowID.id)")
        }
        
        // Create application element
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get windows of the application
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        
        if result != AXError.success {
            throw PilotError.OS_FAILURE(api: "AXUIElementCopyAttributeValue", status: result.rawValue)
        }
        
        guard let windows = windowsValue as? [AXUIElement] else {
            throw PilotError.NOT_FOUND(.window, "No windows found for process")
        }
        
        // Get the original window info for matching
        let originalWindowInfo = windowInfo
        let expectedTitle = originalWindowInfo[kCGWindowName as String] as? String
        
        // Find the window with matching ID (preferred method)
        for window in windows {
            // Try to get window ID from AX element
            var idValue: CFTypeRef?
            let idResult = AXUIElementCopyAttributeValue(window, "_AXWindowNumber" as CFString, &idValue)
            
            if idResult == AXError.success,
               let windowNumber = idValue as? Int,
               windowNumber == Int(windowID.id) {
                return window
            }
        }
        
        // Fallback: match by title if window number matching failed
        if let expectedTitle = expectedTitle, !expectedTitle.isEmpty {
            for window in windows {
                var titleValue: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
                
                if titleResult == AXError.success,
                   let windowTitle = titleValue as? String,
                   windowTitle == expectedTitle {
                    return window
                }
            }
        }
        
        // Final fallback: if there's only one window, use it
        if windows.count == 1 {
            return windows[0]
        }
        
        throw PilotError.NOT_FOUND(.window, "Window not found in accessibility hierarchy")
    }
    
    private func buildAXTree(element: AXUIElement, depth: Int, currentDepth: Int) throws -> AXNode {
        // Stop if we've reached the depth limit
        guard currentDepth < depth else {
            return AXNode(role: nil, title: nil, value: nil, frame: nil, children: [])
        }
        
        // Get element attributes
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String
        
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String
        
        var valueValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueValue)
        let value = valueValue as? String
        
        // Get frame
        var frame: CGRect?
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == AXError.success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == AXError.success {
            
            var position = CGPoint.zero
            var size = CGSize.zero
            
            if let positionRef = positionValue {
                AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
            }
            
            if let sizeRef = sizeValue {
                AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            }
            
            frame = CGRect(origin: position, size: size)
        }
        
        // Get children
        var childrenValue: CFTypeRef?
        var children: [AXNode] = []
        
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == AXError.success,
           let childElements = childrenValue as? [AXUIElement] {
            
            children = childElements.compactMap { childElement in
                try? buildAXTree(element: childElement, depth: depth, currentDepth: currentDepth + 1)
            }
        }
        
        return AXNode(
            role: role,
            title: title,
            value: value,
            frame: frame,
            children: children
        )
    }
    
    private func navigateToElement(from root: AXUIElement, path: AXPath) throws -> AXUIElement {
        var currentElement = root
        
        for component in path.components {
            // Try to interpret component as an index
            if let index = Int(component) {
                // Get children
                var childrenValue: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(currentElement, kAXChildrenAttribute as CFString, &childrenValue)
                
                if result != AXError.success {
                    throw PilotError.NOT_FOUND(.axElement, "No children at path component: \(component)")
                }
                
                guard let children = childrenValue as? [AXUIElement],
                      index < children.count else {
                    throw PilotError.NOT_FOUND(.axElement, "Invalid index at path component: \(component)")
                }
                
                currentElement = children[index]
            } else {
                // Try to find child with matching role or identifier
                var childrenValue: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(currentElement, kAXChildrenAttribute as CFString, &childrenValue)
                
                if result != AXError.success {
                    throw PilotError.NOT_FOUND(.axElement, "No children at path component: \(component)")
                }
                
                guard let children = childrenValue as? [AXUIElement] else {
                    throw PilotError.NOT_FOUND(.axElement, "Invalid children at path component: \(component)")
                }
                
                var found = false
                for child in children {
                    var roleValue: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
                    
                    if let role = roleValue as? String, role == component {
                        currentElement = child
                        found = true
                        break
                    }
                }
                
                if !found {
                    throw PilotError.NOT_FOUND(.axElement, "No child with role: \(component)")
                }
            }
        }
        
        return currentElement
    }
    
    private func storeObserver(_ windowID: WindowID, info: ObserverInfo) {
        observers[windowID] = info
    }
    
    private func cleanupObserver(_ windowID: WindowID) {
        if let info = observers[windowID] {
            // Remove from run loop
            CFRunLoopRemoveSource(CFRunLoopGetMain(), info.runLoopSource, .defaultMode)
            
            // Remove all notifications
            AXObserverRemoveNotification(info.observer, info.element, kAXCreatedNotification as CFString)
            AXObserverRemoveNotification(info.observer, info.element, kAXMovedNotification as CFString)
            AXObserverRemoveNotification(info.observer, info.element, kAXResizedNotification as CFString)
            AXObserverRemoveNotification(info.observer, info.element, kAXTitleChangedNotification as CFString)
            AXObserverRemoveNotification(info.observer, info.element, kAXFocusedUIElementChangedNotification as CFString)
            AXObserverRemoveNotification(info.observer, info.element, kAXValueChangedNotification as CFString)
            
            observers[windowID] = nil
        }
    }
}

// Helper class to pass continuation to C callback
private class StreamContinuation {
    let windowID: WindowID
    let yield: (AXEvent) -> Void
    
    init(windowID: WindowID, yield: @escaping (AXEvent) -> Void) {
        self.windowID = windowID
        self.yield = yield
    }
}