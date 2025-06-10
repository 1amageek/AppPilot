import Foundation
import ApplicationServices
import AppKit
import AXUI

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
    
    // UI Tree Dumping
    func dumpUITree(for window: WindowHandle, maxDepth: Int) async throws -> String
    func getUITree(for window: WindowHandle, maxDepth: Int) async throws -> UIElementTree
    
    // Event Monitoring
    func observeEvents(for window: WindowHandle, mask: AXMask) async -> AsyncStream<AXEvent>
    func checkPermission() async -> Bool
}

// MARK: - Default Accessibility Driver Implementation (v3.0)

public actor DefaultAccessibilityDriver: AccessibilityDriver {
    
    private var handleCounter = 0
    private var appHandles: [String: AppHandleData] = [:]
    private var windowHandles: [String: WindowHandleData] = [:]
    private var elementRefs: [String: AXUIElement] = [:]  // Store AXUIElement references for live operations
    
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
        
        guard let windowData = windowHandles[windowHandle.id] else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        // Use AXUI to get the bundle identifier for this window's app
        guard let appData = appHandles[windowData.appHandle.id],
              let bundleId = appData.app.bundleIdentifier else {
            throw PilotError.applicationNotFound(windowData.appHandle.id)
        }
        
        // Get window index
        let windows = try await getWindows(for: windowData.appHandle)
        guard let windowIndex = windows.firstIndex(where: { $0.id == windowHandle }) else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        // Use AXUI's efficient dumping with filtering
        let filter = determineAXUIFilter(role: role)
        let axDump: String
        
        if let filter = filter {
            axDump = try AXDumper.dumpWindow(bundleIdentifier: bundleId, windowIndex: windowIndex, filter: filter)
        } else {
            axDump = try AXDumper.dumpWindow(bundleIdentifier: bundleId, windowIndex: windowIndex)
        }
        
        // Parse AX dump and convert to UIElements
        let axProperties = try AXParser.parse(content: axDump)
        let uiElements = try convertAXPropertiesToUIElements(axProperties, windowHandle: windowHandle, bundleId: bundleId, windowIndex: windowIndex)
        
        // Apply additional filtering for title and identifier
        let filteredElements = uiElements.filter { element in
            // Match title if specified (case-insensitive, partial match)
            if let title = title {
                guard let elementTitle = element.title,
                      elementTitle.localizedCaseInsensitiveContains(title) else { return false }
            }
            
            // Match identifier if specified
            if let identifier = identifier, element.identifier != identifier { return false }
            
            return true
        }
        
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
        let windowID = try createConsistentWindowID(for: axWindow, appHandle: appHandle)
        
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
    
    private func createConsistentWindowID(for axWindow: AXUIElement, appHandle: AppHandle) throws -> String {
        // Try to get window title for consistency
        let title = getStringAttribute(from: axWindow, attribute: kAXTitleAttribute) ?? "NoTitle"
        
        // Get window position for additional uniqueness
        guard let position = getPositionAttribute(from: axWindow) else {
            throw PilotError.accessibilityTreeUnavailable(WindowHandle(id: "position_unavailable"))
        }
        
        // Get window size
        guard let size = getSizeAttribute(from: axWindow) else {
            throw PilotError.accessibilityTreeUnavailable(WindowHandle(id: "size_unavailable"))
        }
        
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
    
    private func determineAXUIFilter(role: ElementRole?) -> String? {
        guard let role = role else { return nil }
        
        switch role {
        case .button:
            return "button"
        case .textField:
            return "textfield"
        case .checkBox:
            return "checkbox"
        case .radioButton:
            return "radiobutton"
        case .slider:
            return "slider"
        case .popUpButton:
            return "popupbutton"
        case .tab:
            return "tab"
        case .menuItem:
            return "menuitem"
        case .link:
            return "link"
        default:
            return "interactive"  // For unknown interactive elements
        }
    }
    
    private func convertAXPropertiesToUIElements(_ axProperties: AXProperties, windowHandle: WindowHandle, bundleId: String, windowIndex: Int, depth: Int = 0) throws -> [UIElement] {
        var elements: [UIElement] = []
        
        // Convert current element if it has useful properties
        if let role = axProperties.role, !role.isEmpty {
            if let element = createUIElementFromAXProperties(axProperties, windowHandle: windowHandle, bundleId: bundleId, windowIndex: windowIndex, depth: depth) {
                elements.append(element)
            }
        }
        
        // Process children recursively
        for (_, child) in axProperties.children.enumerated() {
            let childElements = try convertAXPropertiesToUIElements(child, windowHandle: windowHandle, bundleId: bundleId, windowIndex: windowIndex, depth: depth + 1)
            elements.append(contentsOf: childElements)
        }
        
        return elements
    }
    
    private func createUIElementFromAXProperties(_ axProperties: AXProperties, windowHandle: WindowHandle, bundleId: String, windowIndex: Int, depth: Int) -> UIElement? {
        guard let roleString = axProperties.role else { return nil }
        
        let role = ElementRole(rawValue: roleString) ?? .unknown
        let title = axProperties.value  // AXUI uses 'value' for display text
        let identifier = axProperties.identifier
        let isEnabled = axProperties.enabled ?? true
        
        // Create bounds from position and size
        let bounds: CGRect
        if let position = axProperties.position, let size = axProperties.size {
            bounds = CGRect(origin: position, size: size)
        } else {
            bounds = CGRect.zero
        }
        
        // Generate unique ID
        let elementId = "\(windowHandle.id)_\(bundleId)_\(windowIndex)_\(roleString)_\(depth)_\(title?.hashValue ?? identifier?.hashValue ?? Int.random(in: 1000...9999))"
        
        let uiElement = UIElement(
            id: elementId,
            role: role,
            title: title,
            value: axProperties.value,
            identifier: identifier,
            bounds: bounds,
            isEnabled: isEnabled
        )
        
        // Note: We don't store AXUIElement references from AXUI dumps
        // These would need to be obtained fresh when performing actions
        
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
    
    
    // MARK: - Element Value Operations
    
    public func getValue(from element: UIElement) async throws -> String? {
        // For AXUI-based elements, we need to refresh the element data
        // since we don't maintain persistent AXUIElement references
        return try await refreshElementAndGetValue(element)
    }
    
    public func setValue(_ value: String, for element: UIElement) async throws {
        // For AXUI-based elements, we need to find the current AXUIElement
        let axElement = try await findLiveAXElement(for: element)
        
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
        do {
            let _ = try await findLiveAXElement(for: element)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Helper Methods for Live Element Operations
    
    private func refreshElementAndGetValue(_ element: UIElement) async throws -> String? {
        let axElement = try await findLiveAXElement(for: element)
        return getStringAttribute(from: axElement, attribute: kAXValueAttribute)
    }
    
    private func findLiveAXElement(for element: UIElement) async throws -> AXUIElement {
        // Parse element ID to get window information
        let components = element.id.components(separatedBy: "_")
        guard components.count >= 3 else {
            throw PilotError.elementNotAccessible(element.id)
        }
        
        let windowId = components[0] + "_" + components[1]
        guard let windowData = windowHandles[windowId] else {
            throw PilotError.windowNotFound(WindowHandle(id: windowId))
        }
        
        // Find the element by traversing the AX tree based on its properties
        return try await findElementInAXTree(windowData.axWindow, targetElement: element)
    }
    
    private func findElementInAXTree(_ rootAXElement: AXUIElement, targetElement: UIElement, depth: Int = 0, maxDepth: Int = 10) async throws -> AXUIElement {
        guard depth < maxDepth else {
            throw PilotError.elementNotAccessible(targetElement.id)
        }
        
        // Check if current element matches
        if elementMatches(rootAXElement, target: targetElement) {
            return rootAXElement
        }
        
        // Search children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(rootAXElement, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success, let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = try? await findElementInAXTree(child, targetElement: targetElement, depth: depth + 1, maxDepth: maxDepth) {
                    return found
                }
            }
        }
        
        throw PilotError.elementNotAccessible(targetElement.id)
    }
    
    private func elementMatches(_ axElement: AXUIElement, target: UIElement) -> Bool {
        let role = getStringAttribute(from: axElement, attribute: kAXRoleAttribute)
        let title = getStringAttribute(from: axElement, attribute: kAXTitleAttribute)
        let value = getStringAttribute(from: axElement, attribute: kAXValueAttribute)
        let identifier = getStringAttribute(from: axElement, attribute: kAXIdentifierAttribute)
        
        // Match based on role and at least one other property
        return role == target.role.rawValue &&
               ((title == target.title && title != nil) ||
                (value == target.value && value != nil) ||
                (identifier == target.identifier && identifier != nil))
    }
    
    // MARK: - Cache Management
    
    public func clearElementCache(for window: WindowHandle?) async {
        // Clear element references (no longer using cache mechanism)
        if let window = window {
            let keysToRemove = elementRefs.keys.filter { $0.hasPrefix(window.id) }
            for key in keysToRemove {
                elementRefs.removeValue(forKey: key)
            }
        } else {
            elementRefs.removeAll()
        }
    }
    
    // MARK: - UI Tree Dumping
    
    public func dumpUITree(for window: WindowHandle, maxDepth: Int = 5) async throws -> String {
        guard await checkPermission() else {
            throw PilotError.permissionDenied("Accessibility permission required for UI tree analysis")
        }
        
        guard let windowData = windowHandles[window.id] else {
            throw PilotError.windowNotFound(window)
        }
        
        // Use AXUI to get the bundle identifier and window index
        guard let appData = appHandles[windowData.appHandle.id],
              let bundleId = appData.app.bundleIdentifier else {
            throw PilotError.applicationNotFound(windowData.appHandle.id)
        }
        
        let windows = try await getWindows(for: windowData.appHandle)
        guard let windowIndex = windows.firstIndex(where: { $0.id == window }) else {
            throw PilotError.windowNotFound(window)
        }
        
        // Use AXUI's efficient dumping for hierarchical view
        let axDump = try AXDumper.dumpWindow(bundleIdentifier: bundleId, windowIndex: windowIndex)
        
        // Convert to JSON for more compact representation
        let jsonOutput = try AXConverter.convertToPrettyJSON(axDump: axDump)
        
        return jsonOutput
    }
    
    public func getUITree(for window: WindowHandle, maxDepth: Int = 5) async throws -> UIElementTree {
        guard await checkPermission() else {
            throw PilotError.permissionDenied("Accessibility permission required for UI tree analysis")
        }
        
        guard let windowData = windowHandles[window.id] else {
            throw PilotError.windowNotFound(window)
        }
        
        // Use AXUI to get comprehensive window information
        guard let appData = appHandles[windowData.appHandle.id],
              let bundleId = appData.app.bundleIdentifier else {
            throw PilotError.applicationNotFound(windowData.appHandle.id)
        }
        
        let windows = try await getWindows(for: windowData.appHandle)
        guard let windowIndex = windows.firstIndex(where: { $0.id == window }) else {
            throw PilotError.windowNotFound(window)
        }
        
        // Get hierarchical AX dump
        let axDump = try AXDumper.dumpWindow(bundleIdentifier: bundleId, windowIndex: windowIndex)
        let axProperties = try AXParser.parse(content: axDump)
        
        return try buildUITreeFromAXProperties(axProperties, windowHandle: window, bundleId: bundleId, windowIndex: windowIndex, depth: 0, maxDepth: maxDepth)
    }
    
    private func buildUITreeFromAXProperties(_ axProperties: AXProperties, windowHandle: WindowHandle, bundleId: String, windowIndex: Int, depth: Int, maxDepth: Int) throws -> UIElementTree {
        guard depth <= maxDepth else {
            // Return empty tree for elements beyond max depth
            let dummyElement = UIElement(
                id: "depth_limit_\(depth)",
                role: .unknown,
                title: "...",
                bounds: CGRect.zero,
                isEnabled: false
            )
            return UIElementTree(element: dummyElement, children: [], depth: depth)
        }
        
        // Create UIElement for current AX properties
        let element = createUIElementFromAXPropertiesForTree(axProperties, windowHandle: windowHandle, bundleId: bundleId, windowIndex: windowIndex, depth: depth)
        
        // Process children
        var children: [UIElementTree] = []
        for (_, child) in axProperties.children.enumerated() {
            if depth + 1 <= maxDepth {
                let childTree = try buildUITreeFromAXProperties(child, windowHandle: windowHandle, bundleId: bundleId, windowIndex: windowIndex, depth: depth + 1, maxDepth: maxDepth)
                children.append(childTree)
            }
        }
        
        return UIElementTree(element: element, children: children, depth: depth)
    }
    
    private func createUIElementFromAXPropertiesForTree(_ axProperties: AXProperties, windowHandle: WindowHandle, bundleId: String, windowIndex: Int, depth: Int) -> UIElement {
        let roleString = axProperties.role ?? "AXUnknown"
        let role = ElementRole(rawValue: roleString) ?? .unknown
        let title = axProperties.value  // AXUI uses 'value' for display text
        let identifier = axProperties.identifier
        let isEnabled = axProperties.enabled ?? true
        
        // Create bounds from position and size
        let bounds: CGRect
        if let position = axProperties.position, let size = axProperties.size {
            bounds = CGRect(origin: position, size: size)
        } else {
            bounds = CGRect.zero
        }
        
        // Generate ID for tree
        let elementId = "\(windowHandle.id)_\(bundleId)_\(windowIndex)_\(roleString)_\(depth)_\(title?.hashValue ?? identifier?.hashValue ?? bounds.hashValue)"
        
        return UIElement(
            id: elementId,
            role: role,
            title: title,
            value: axProperties.value,
            identifier: identifier,
            bounds: bounds,
            isEnabled: isEnabled
        )
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
        return AXDumper.checkAccessibilityPermissions()
    }
}

