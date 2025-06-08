import Foundation
import ApplicationServices
import AppKit

// MARK: - Accessibility Driver Protocol (v3.0 - Element Discovery)

public protocol AccessibilityDriver: Sendable {
    // Application and Window Management
    func getApplications() async throws -> [AppInfo]
    func findApplication(bundleId: String) async throws -> AppHandle
    func findApplication(name: String) async throws -> AppHandle
    func getWindows(for app: AppHandle) async throws -> [WindowInfo]
    func findWindow(app: AppHandle, title: String) async throws -> WindowHandle?
    func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle?
    
    // UI Element Discovery
    func findElements(in window: WindowHandle, role: ElementRole?, title: String?, identifier: String?) async throws -> [UIElement]
    func findElement(in window: WindowHandle, role: ElementRole, title: String) async throws -> UIElement
    func elementExists(_ element: UIElement) async throws -> Bool
    func getValue(from element: UIElement) async throws -> String?
    func setValue(_ value: String, for element: UIElement) async throws
    
    // Cache Management
    func clearElementCache(for window: WindowHandle?) async
    
    // Event Monitoring
    func observeEvents(for window: WindowHandle, mask: AXMask) async -> AsyncStream<AXEvent>
    func checkPermission() async -> Bool
}

// MARK: - Default Accessibility Driver Implementation (v3.0)

public actor DefaultAccessibilityDriver: AccessibilityDriver {
    
    private var handleCounter = 0
    private var appHandles: [String: AppHandleData] = [:]
    private var windowHandles: [String: WindowHandleData] = [:]
    private var elementCache: [String: [UIElement]] = [:]
    private var elementRefs: [String: AXUIElement] = [:]  // Store AXUIElement references for live operations
    private var cacheTimeout: TimeInterval = 30.0
    private var lastCacheUpdate: Date = Date.distantPast
    
    private struct AppHandleData {
        let handle: AppHandle
        let app: NSRunningApplication
        let axApp: AXUIElement
        let createdAt: Date
    }
    
    private struct WindowHandleData {
        let handle: WindowHandle
        let appHandle: AppHandle
        let axWindow: AXUIElement
        let createdAt: Date
    }
    
    public init() {}
    
    // MARK: - Application Management
    
    public func getApplications() async throws -> [AppInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        var apps: [AppInfo] = []
        
        for app in runningApps {
            guard let name = app.localizedName,
                  app.activationPolicy == .regular else { continue }
            
            let handle = try await generateAppHandle(for: app)
            
            let appInfo = AppInfo(
                id: handle,
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                isActive: app.isActive
            )
            apps.append(appInfo)
        }
        
        return apps.sorted { $0.name < $1.name }
    }
    
    public func findApplication(bundleId: String) async throws -> AppHandle {
        let runningApps = NSWorkspace.shared.runningApplications
        
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw PilotError.applicationNotFound(bundleId)
        }
        
        return try await generateAppHandle(for: app)
    }
    
    public func findApplication(name: String) async throws -> AppHandle {
        let runningApps = NSWorkspace.shared.runningApplications
        
        let candidates = runningApps.filter { app in
            app.localizedName?.localizedCaseInsensitiveContains(name) == true
        }
        
        guard let app = candidates.first else {
            throw PilotError.applicationNotFound(name)
        }
        
        return try await generateAppHandle(for: app)
    }
    
    public func getWindows(for appHandle: AppHandle) async throws -> [WindowInfo] {
        guard let appData = appHandles[appHandle.id] else {
            throw PilotError.applicationNotFound(appHandle.id)
        }
        
        // Get windows from Accessibility API
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appData.axApp, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
            return []
        }
        
        var windows: [WindowInfo] = []
        
        for (_, axWindow) in axWindows.enumerated() {
            let windowHandle = try await generateWindowHandle(for: axWindow, appHandle: appHandle)
            
            let title = getStringAttribute(from: axWindow, attribute: kAXTitleAttribute)
            let isMain = getBoolAttribute(from: axWindow, attribute: kAXMainAttribute) ?? false
            let isVisible = !(getBoolAttribute(from: axWindow, attribute: kAXHiddenAttribute) ?? false)
            let bounds = try getWindowBounds(from: axWindow)
            
            let windowInfo = WindowInfo(
                id: windowHandle,
                title: title,
                bounds: bounds,
                isVisible: isVisible,
                isMain: isMain,
                appName: appData.app.localizedName ?? "Unknown"
            )
            windows.append(windowInfo)
        }
        
        return windows
    }
    
    public func findWindow(app: AppHandle, title: String) async throws -> WindowHandle? {
        let windows = try await getWindows(for: app)
        
        let window = windows.first(where: { 
            $0.title?.localizedCaseInsensitiveContains(title) == true 
        })
        
        return window?.id
    }
    
    public func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle? {
        let windows = try await getWindows(for: app)
        
        guard index >= 0 && index < windows.count else {
            return nil
        }
        
        return windows[index].id
    }
    
    // MARK: - UI Element Discovery
    
    public func findElements(in windowHandle: WindowHandle, role: ElementRole?, title: String?, identifier: String?) async throws -> [UIElement] {
        
        // Check accessibility permission first
        guard await checkPermission() else {
            throw PilotError.permissionDenied("Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility")
        }
        
        // Check cache first
        let cacheKey = "\(windowHandle.id)-\(role?.rawValue ?? "all")-\(title ?? "")-\(identifier ?? "")"
        if let cached = elementCache[cacheKey],
           Date().timeIntervalSince(lastCacheUpdate) < cacheTimeout {
            return cached
        }
        
        guard let windowData = windowHandles[windowHandle.id] else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        // Extract all elements from AX tree
        let allElements = try await extractElementsFromWindow(windowData.axWindow, windowHandle: windowHandle)
        
        // Filter based on criteria
        let filteredElements = allElements.filter { element in
            // Match role if specified
            if let role = role, element.role != role { return false }
            
            // Match title if specified (case-insensitive, partial match)
            if let title = title {
                guard let elementTitle = element.title,
                      elementTitle.localizedCaseInsensitiveContains(title) else { return false }
            }
            
            // Match identifier if specified
            if let identifier = identifier, element.identifier != identifier { return false }
            
            return true
        }
        
        // Cache the results
        elementCache[cacheKey] = filteredElements
        lastCacheUpdate = Date()
        
        return filteredElements
    }
    
    public func findElement(in window: WindowHandle, role: ElementRole, title: String) async throws -> UIElement {
        let elements = try await findElements(in: window, role: role, title: title, identifier: nil)
        
        if elements.isEmpty {
            throw PilotError.elementNotFound(role: role, title: title)
        }
        
        if elements.count > 1 {
            throw PilotError.multipleElementsFound(role: role, title: title, count: elements.count)
        }
        
        return elements[0]
    }
    
    
    // MARK: - Private Helper Methods
    
    private func generateAppHandle(for app: NSRunningApplication) async throws -> AppHandle {
        // Check if we already have a handle for this app
        for (_, data) in appHandles {
            if data.app.processIdentifier == app.processIdentifier {
                return data.handle
            }
        }
        
        handleCounter += 1
        let handle = AppHandle(id: "app_\(String(format: "%04X", handleCounter))")
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        // Verify accessibility
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        guard result == .success else {
            throw PilotError.permissionDenied("Cannot access application \(app.localizedName ?? "Unknown"). Please grant accessibility permissions.")
        }
        
        appHandles[handle.id] = AppHandleData(
            handle: handle,
            app: app,
            axApp: axApp,
            createdAt: Date()
        )
        
        return handle
    }
    
    private func generateWindowHandle(for axWindow: AXUIElement, appHandle: AppHandle) async throws -> WindowHandle {
        // Create a consistent ID based on window properties
        let windowID = createConsistentWindowID(for: axWindow, appHandle: appHandle)
        
        // Check if we already have a handle for this window
        if let existingData = windowHandles[windowID] {
            return existingData.handle
        }
        
        let handle = WindowHandle(id: windowID)
        
        windowHandles[handle.id] = WindowHandleData(
            handle: handle,
            appHandle: appHandle,
            axWindow: axWindow,
            createdAt: Date()
        )
        
        return handle
    }
    
    private func createConsistentWindowID(for axWindow: AXUIElement, appHandle: AppHandle) -> String {
        // Try to get window title for consistency
        let title = getStringAttribute(from: axWindow, attribute: kAXTitleAttribute) ?? "NoTitle"
        
        // Get window position for additional uniqueness
        let position = getPositionAttribute(from: axWindow) ?? CGPoint.zero
        
        // Get window size
        let size = getSizeAttribute(from: axWindow) ?? CGSize.zero
        
        // Create a consistent ID based on app + title + position + size
        let components = [
            appHandle.id,
            title.replacingOccurrences(of: " ", with: "_"),
            String(format: "%.0f", position.x),
            String(format: "%.0f", position.y),
            String(format: "%.0f", size.width),
            String(format: "%.0f", size.height)
        ]
        
        let combinedString = components.joined(separator: "_")
        
        // Create a hash for a shorter, consistent ID
        let hash = combinedString.hash
        return "win_\(String(format: "%08X", abs(hash)))"
    }
    
    private func getPositionAttribute(from element: AXUIElement) -> CGPoint? {
        var positionRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        
        guard result == .success, let positionValue = positionRef else { return nil }
        
        var point = CGPoint.zero
        if AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) {
            return point
        }
        return nil
    }
    
    private func getSizeAttribute(from element: AXUIElement) -> CGSize? {
        var sizeRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        guard result == .success, let sizeValue = sizeRef else { return nil }
        
        var size = CGSize.zero
        if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
            return size
        }
        return nil
    }
    
    private func extractElementsFromWindow(_ axWindow: AXUIElement, windowHandle: WindowHandle, depth: Int = 0, maxDepth: Int = 10) async throws -> [UIElement] {
        guard depth < maxDepth else { 
            return [] 
        }
        
        var elements: [UIElement] = []
        
        // Process current element
        if let element = try? createUIElement(from: axWindow, windowHandle: windowHandle, depth: depth) {
            elements.append(element)
        }
        
        // Get children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success, let children = childrenRef as? [AXUIElement] {
            for child in children.prefix(50) { // Limit to prevent excessive recursion
                let childElements = try await extractElementsFromWindow(child, windowHandle: windowHandle, depth: depth + 1, maxDepth: maxDepth)
                elements.append(contentsOf: childElements)
            }
        }
        
        return elements
    }
    
    private func createUIElement(from axElement: AXUIElement, windowHandle: WindowHandle, depth: Int) throws -> UIElement? {
        guard let roleString = getStringAttribute(from: axElement, attribute: kAXRoleAttribute) else {
            return nil
        }
        
        let role = ElementRole(rawValue: roleString) ?? .unknown
        let title = getStringAttribute(from: axElement, attribute: kAXTitleAttribute)
        let value = getStringAttribute(from: axElement, attribute: kAXValueAttribute)
        let identifier = getStringAttribute(from: axElement, attribute: kAXIdentifierAttribute)
        let isEnabled = getBoolAttribute(from: axElement, attribute: kAXEnabledAttribute) ?? true
        
        // Get element bounds
        let bounds = (try? getElementBounds(from: axElement)) ?? CGRect.zero
        
        // Generate unique ID based on actual element properties
        let elementId = "\(windowHandle.id)_\(roleString)_\(depth)_\(title?.hashValue ?? identifier?.hashValue ?? Int.random(in: 1000...9999))"
        
        let uiElement = UIElement(
            id: elementId,
            role: role,
            title: title,
            value: value,
            identifier: identifier,
            bounds: bounds,
            isEnabled: isEnabled
        )
        
        // Store the AXUIElement reference for live operations
        elementRefs[elementId] = axElement
        
        return uiElement
    }
    
    private func getStringAttribute(from element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }
    
    private func getBoolAttribute(from element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? Bool
    }
    
    private func getWindowBounds(from window: AXUIElement) throws -> CGRect {
        // Get position
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        
        guard positionResult == .success, let position = positionValue as! AXValue? else {
            throw PilotError.accessibilityTreeUnavailable(WindowHandle(id: "unknown"))
        }
        
        var windowOrigin = CGPoint.zero
        guard AXValueGetValue(position, .cgPoint, &windowOrigin) else {
            throw PilotError.accessibilityTreeUnavailable(WindowHandle(id: "unknown"))
        }
        
        // Get size
        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        
        guard sizeResult == .success, let size = sizeValue as! AXValue? else {
            throw PilotError.accessibilityTreeUnavailable(WindowHandle(id: "unknown"))
        }
        
        var windowSize = CGSize.zero
        guard AXValueGetValue(size, .cgSize, &windowSize) else {
            throw PilotError.accessibilityTreeUnavailable(WindowHandle(id: "unknown"))
        }
        
        return CGRect(origin: windowOrigin, size: windowSize)
    }
    
    private func getElementBounds(from element: AXUIElement) throws -> CGRect {
        // Similar to getWindowBounds but for UI elements
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        
        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        if positionResult == .success && sizeResult == .success,
           let position = positionValue as! AXValue?,
           let size = sizeValue as! AXValue? {
            
            var origin = CGPoint.zero
            var elementSize = CGSize.zero
            
            if AXValueGetValue(position, .cgPoint, &origin) &&
               AXValueGetValue(size, .cgSize, &elementSize) {
                return CGRect(origin: origin, size: elementSize)
            }
        }
        
        return CGRect.zero
    }
    
    // MARK: - Element Value Operations
    
    public func getValue(from element: UIElement) async throws -> String? {
        guard let axElement = elementRefs[element.id] else {
            // Element reference not found, try to return cached value
            return element.value
        }
        
        // Get live value from the AXUIElement
        return getStringAttribute(from: axElement, attribute: kAXValueAttribute)
    }
    
    public func setValue(_ value: String, for element: UIElement) async throws {
        guard let axElement = elementRefs[element.id] else {
            throw PilotError.elementNotAccessible(element.id)
        }
        
        // Set the value using AXUIElementSetAttributeValue
        let result = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, value as CFString)
        
        switch result {
        case .success:
            return
        case .invalidUIElement:
            throw PilotError.elementNotAccessible(element.id)
        case .attributeUnsupported:
            throw PilotError.invalidArgument("Element \(element.role.rawValue) does not support value setting")
        case .cannotComplete:
            throw PilotError.osFailure(api: "AXUIElementSetAttributeValue", code: Int32(result.rawValue))
        case .notImplemented:
            throw PilotError.osFailure(api: "AXUIElementSetAttributeValue", code: Int32(result.rawValue))
        case .illegalArgument:
            throw PilotError.invalidArgument("Invalid value '\(value)' for element")
        case .failure:
            throw PilotError.osFailure(api: "AXUIElementSetAttributeValue", code: Int32(result.rawValue))
        default:
            throw PilotError.osFailure(api: "AXUIElementSetAttributeValue", code: Int32(result.rawValue))
        }
    }
    
    public func elementExists(_ element: UIElement) async throws -> Bool {
        guard let axElement = elementRefs[element.id] else {
            return false
        }
        
        // Check if the element still exists by trying to get its role
        var roleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleRef)
        return result == .success
    }
    
    // MARK: - Cache Management
    
    public func clearElementCache(for window: WindowHandle?) async {
        if let window = window {
            elementCache.removeValue(forKey: window.id)
            // Also clear element references for this window
            let keysToRemove = elementRefs.keys.filter { $0.hasPrefix(window.id) }
            for key in keysToRemove {
                elementRefs.removeValue(forKey: key)
            }
        } else {
            elementCache.removeAll()
            elementRefs.removeAll()
        }
    }
    
    // MARK: - Event Monitoring
    
    public func observeEvents(for window: WindowHandle, mask: AXMask) async -> AsyncStream<AXEvent> {
        return AsyncStream { continuation in
            Task {
                guard let windowData = windowHandles[window.id] else {
                    continuation.finish()
                    return
                }
                
                // Create AXObserver for the application (for future real implementation)
                let _ = appHandles[windowData.appHandle.id]!
                
                // Simplified event monitoring implementation
                // For now, generate mock events based on the mask
                
                // Schedule event generation
                Task {
                    for eventType in [AXEvent.EventType.created, .moved, .resized, .titleChanged, .focusChanged, .valueChanged] {
                        // Check if this event type is requested in the mask
                        let shouldEmit = switch eventType {
                        case .created: mask.contains(.created)
                        case .moved: mask.contains(.moved)
                        case .resized: mask.contains(.resized)
                        case .titleChanged: mask.contains(.titleChanged)
                        case .focusChanged: mask.contains(.focusChanged)
                        case .valueChanged: mask.contains(.valueChanged)
                        default: false
                        }
                        
                        if shouldEmit {
                            let event = AXEvent(
                                type: eventType,
                                windowHandle: window,
                                timestamp: Date(),
                                description: "Simulated \(eventType) event"
                            )
                            continuation.yield(event)
                            
                            // Wait between events
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        }
                    }
                    
                    // Finish after generating sample events
                    continuation.finish()
                }
            }
        }
    }
    
    public func checkPermission() async -> Bool {
        return AXIsProcessTrusted()
    }
}

