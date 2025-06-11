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
    func findElement(in window: WindowHandle, role: ElementRole, title: String?, identifier: String?) async throws -> UIElement
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
        
        // Use AXUI's flat element dumping
        let axElements = try AXDumper.dumpWindow(bundleIdentifier: bundleId, windowIndex: windowIndex)
        
        // Convert AXElements to UIElements with improved filtering
        let uiElements = convertAXElementsToUIElements(axElements, windowHandle: windowHandle)
        
        // Apply precise filtering with AND logic
        return filterElementsWithANDLogic(uiElements, role: role, title: title, identifier: identifier)
    }
    
    public func findElement(in window: WindowHandle, role: ElementRole, title: String? = nil, identifier: String? = nil) async throws -> UIElement {
        // At least one of title or identifier must be provided
        guard title != nil || identifier != nil else {
            throw PilotError.invalidArgument("Either title or identifier must be provided")
        }
        
        let elements = try await findElements(in: window, role: role, title: title, identifier: identifier)
        
        // Handle results with improved logic
        switch elements.count {
        case 0:
            let criteria = [title.map {"title: '\($0)'"}, identifier.map {"identifier: '\($0)'"}].compactMap {$0}.joined(separator: ", ")
            throw PilotError.elementNotFound(role: role, title: "\(role.rawValue) with \(criteria)")
        case 1:
            return elements[0]
        default:
            // Multiple matches - use refined selection logic
            let refined = selectBestMatch(from: elements, role: role, title: title, identifier: identifier)
            return refined
        }
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
        // Use cached AXUIElement if available
        if let axElementRef = elementRefs[element.id] {
            return getStringAttribute(from: axElementRef, attribute: kAXValueAttribute)
        }
        
        // Fallback to live element search
        let axElement = try await findLiveAXElement(for: element)
        return getStringAttribute(from: axElement, attribute: kAXValueAttribute)
    }
    
    public func setValue(_ value: String, for element: UIElement) async throws {
        // Use cached AXUIElement if available
        let axElement: AXUIElement
        if let cachedElement = elementRefs[element.id] {
            axElement = cachedElement
        } else {
            axElement = try await findLiveAXElement(for: element)
        }
        
        // Direct value setting using AXUIElement reference
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
        // Use cached AXUIElement if available
        if let axElementRef = elementRefs[element.id] {
            // Direct AXUIElement reference validation (fast)
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axElementRef, kAXRoleAttribute as CFString, &value)
            return result == .success
        }
        
        // Fallback to element search if not cached
        do {
            let _ = try await findLiveAXElement(for: element)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Helper Methods for Improved Element Discovery
    
    private func convertAXElementsToUIElements(_ axElements: [AXElement], windowHandle: WindowHandle) -> [UIElement] {
        return axElements.compactMap { axElement in
            createUIElementFromAXElement(axElement, windowHandle: windowHandle)
        }
    }
    
    private func createUIElementFromAXElement(_ axElement: AXElement, windowHandle: WindowHandle) -> UIElement? {
        guard let roleString = axElement.role else { return nil }
        
        let role = ElementRole(rawValue: roleString) ?? .unknown
        let title = axElement.description  // AXUI uses 'description' for display text
        let identifier = axElement.identifier
        let isEnabled = axElement.state?.enabled ?? true
        
        // Create bounds from position and size
        let bounds: CGRect
        if let position = axElement.position, let size = axElement.size {
            bounds = CGRect(origin: CGPoint(x: position.x, y: position.y), size: CGSize(width: size.width, height: size.height))
        } else {
            bounds = CGRect.zero
        }
        
        // Generate unique ID based on element properties
        let elementId = "\(windowHandle.id)_\(roleString)_\(title?.hashValue ?? identifier?.hashValue ?? Int.random(in: 1000...9999))"
        
        return UIElement(
            id: elementId,
            role: role,
            title: title,
            value: axElement.description,
            identifier: identifier,
            bounds: bounds,
            isEnabled: isEnabled
        )
    }
    
    private func filterElementsWithANDLogic(_ elements: [UIElement], role: ElementRole?, title: String?, identifier: String?) -> [UIElement] {
        return elements.filter { element in
            // AND logic: all specified criteria must match
            
            // Role matching
            if let role = role, element.role != role {
                return false
            }
            
            // Title matching (case-insensitive, partial match)
            if let title = title {
                guard let elementTitle = element.title,
                      elementTitle.localizedCaseInsensitiveContains(title) else {
                    return false
                }
            }
            
            // Identifier matching (exact match)
            if let identifier = identifier, element.identifier != identifier {
                return false
            }
            
            // Additional quality filters
            return element.isEnabled &&
                   element.bounds.width > 0 &&
                   element.bounds.height > 0
        }
    }
    
    private func selectBestMatch(from elements: [UIElement], role: ElementRole, title: String?, identifier: String?) -> UIElement {
        // 1. If identifier is specified, prefer exact identifier matches
        if let identifier = identifier {
            let identifierMatches = elements.filter { element in
                element.identifier == identifier
            }
            
            if identifierMatches.count == 1 {
                return identifierMatches[0]
            }
            
            if !identifierMatches.isEmpty {
                // If multiple identifier matches, prefer enabled and visible ones
                let qualityMatches = identifierMatches.filter { element in
                    element.isEnabled && element.bounds.width > 0 && element.bounds.height > 0
                }
                return qualityMatches.isEmpty ? identifierMatches[0] : qualityMatches[0]
            }
        }
        
        // 2. If title is specified, prefer exact title matches
        if let title = title {
            let exactTitleMatches = elements.filter { element in
                element.title?.lowercased() == title.lowercased()
            }
            
            if exactTitleMatches.count == 1 {
                return exactTitleMatches[0]
            }
            
            if !exactTitleMatches.isEmpty {
                // If multiple exact title matches, prefer enabled and visible ones
                let qualityMatches = exactTitleMatches.filter { element in
                    element.isEnabled && element.bounds.width > 0 && element.bounds.height > 0
                }
                return qualityMatches.isEmpty ? exactTitleMatches[0] : qualityMatches[0]
            }
        }
        
        // 3. Fallback: prefer enabled and visible elements
        let qualityMatches = elements.filter { element in
            element.isEnabled && element.bounds.width > 0 && element.bounds.height > 0
        }
        
        if !qualityMatches.isEmpty {
            return qualityMatches[0]
        }
        
        // 4. Last resort: return the first element
        return elements[0]
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
        let axElement = try await findElementInAXTree(windowData.axWindow, targetElement: element)
        
        // Cache the found element for future use
        elementRefs[element.id] = axElement
        
        return axElement
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
        // Clear element references for specified window or all windows
        if let window = window {
            let keysToRemove = elementRefs.keys.filter { $0.hasPrefix(window.id) }
            for key in keysToRemove {
                elementRefs.removeValue(forKey: key)
            }
        } else {
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
        return AXDumper.checkAccessibilityPermissions()
    }
}

