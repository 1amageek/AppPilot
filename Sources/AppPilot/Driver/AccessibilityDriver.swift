import Foundation
import ApplicationServices
import AppKit
import AXUI
import CryptoKit

// MARK: - Accessibility Driver Protocol

public protocol AccessibilityDriver: Sendable {
    // Application and Window Management
    func getApplications() async throws -> [AppInfo]
    func findApplication(bundleId: String) async throws -> AppHandle
    func findApplication(name: String) async throws -> AppHandle
    func getWindows(for app: AppHandle) async throws -> [WindowInfo]
    func findWindow(app: AppHandle, title: String) async throws -> WindowHandle?
    func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle?
    
    // UI Element Discovery (ID-based)
    func findElements(in window: WindowHandle, role: Role?, title: String?, identifier: String?) async throws -> [AIElement]
    func findElement(in window: WindowHandle, role: Role, title: String?, identifier: String?) async throws -> AIElement
    func elementExists(with id: String) async throws -> Bool
    func value(for id: String) async throws -> String?
    func setValue(_ value: String, for id: String) async throws
    
    // Event Monitoring
    func observeEvents(for window: WindowHandle, mask: AXMask) async -> AsyncStream<AXEvent>
    func checkPermission() async -> Bool
}

// MARK: - Default Accessibility Driver Implementation

public actor DefaultAccessibilityDriver: AccessibilityDriver {
    
    private var handleCounter = 0
    private var appHandles: [String: AppHandleData] = [:]
    private var windowHandles: [String: WindowHandleData] = [:]
    
    private struct AppHandleData {
        let handle: AppHandle
        let app: NSRunningApplication
        let axApp: AXUIElement
    }
    
    private struct WindowHandleData {
        let handle: WindowHandle
        let appHandle: AppHandle
        let axWindow: AXUIElement
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
    
    public func findElements(in windowHandle: WindowHandle, role: Role?, title: String?, identifier: String?) async throws -> [AIElement] {
        
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
        
        // Convert AXElements to AIElements with improved filtering
        let aiElements = convertAXElementsToAIElements(axElements, windowHandle: windowHandle)
        
        
        // Convert Role to AXUI.Role for filtering
        let axuiRole: AXUI.Role? = role.flatMap { roleToAXUIRole($0) }
        
        // Apply precise filtering with AND logic
        return filterElementsWithANDLogic(aiElements, role: axuiRole, title: title, identifier: identifier)
    }
    
    public func findElement(in window: WindowHandle, role: Role, title: String? = nil, identifier: String? = nil) async throws -> AIElement {
        // At least one of title or identifier must be provided
        guard title != nil || identifier != nil else {
            throw PilotError.invalidArgument("Either title or identifier must be provided")
        }
        
        let elements = try await findElements(in: window, role: role, title: title, identifier: identifier)
        
        // Handle results with improved logic
        switch elements.count {
        case 0:
            let criteria = [title.map {"title: '\($0)'"}, identifier.map {"identifier: '\($0)'"}].compactMap {$0}.joined(separator: ", ")
            throw PilotError.elementNotFound(role: role.rawValue, title: "\(role.rawValue) with \(criteria)")
        case 1:
            return elements[0]
        default:
            // Multiple matches - use refined selection logic
            let refined = selectBestMatch(from: elements, role: role.rawValue, title: title, identifier: identifier)
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
            axApp: axApp
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
            axWindow: axWindow
        )
        
        return handle
    }
    
    private func createConsistentWindowID(for axWindow: AXUIElement, appHandle: AppHandle) throws -> String {
        // First try to get AX identifier if available (most stable)
        if let axIdentifier = getStringAttribute(from: axWindow, attribute: kAXIdentifierAttribute),
           !axIdentifier.isEmpty {
            return "win_ax_\(axIdentifier)"
        }
        
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
        
        // Use SHA256 for stable, consistent hashing across app restarts
        let stableHash = createStableHash(from: combinedString)
        return "win_\(stableHash)"
    }
    
    /// Create a stable hash that doesn't change between app restarts
    private func createStableHash(from input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        
        // Take first 8 bytes of SHA256 hash and convert to hex
        let hashBytes = digest.prefix(8)
        let hexString = hashBytes.map { String(format: "%02X", $0) }.joined()
        
        return hexString
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
    
    
    
    
    /// Generic attribute getter that handles different types safely
    private func axValue<T>(_ element: AXUIElement, _ attribute: String, as type: T.Type = T.self) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? T
    }
    
    /// Specialized attribute getters using the generic method
    private func getStringAttribute(from element: AXUIElement, attribute: String) -> String? {
        return axValue(element, attribute, as: String.self)
    }
    
    private func getBoolAttribute(from element: AXUIElement, attribute: String) -> Bool? {
        return axValue(element, attribute, as: Bool.self)
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
    
    
    // MARK: - Element Value Operations (ID-based)
    
    public func value(for id: String) async throws -> String? {
        // Find element by ID using AXUI
        guard let element = try await findElement(by: id) else {
            throw PilotError.elementNotAccessible(id)
        }
        
        // Return value from AXElement
        return element.description
    }
    
    public func setValue(_ value: String, for id: String) async throws {
        // setValue operation requires access to native AXUIElement
        // Since AXUI's axElementRef is internal, we need to re-search for the element
        // using the traditional AX tree traversal approach for live operations
        
        guard let element = try await findElement(by: id) else {
            throw PilotError.elementNotAccessible(id)
        }
        
        // Find the live AXUIElement for this element by searching all windows
        let axElement = try await findLiveAXElementForId(id, element: element)
        
        // Direct value setting using AXUIElement reference
        let result = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, value as CFString)
        
        switch result {
        case .success:
            return
        case .invalidUIElement:
            throw PilotError.elementNotAccessible(id)
        case .attributeUnsupported:
            throw PilotError.invalidArgument("Element does not support value setting")
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
    
    public func elementExists(with id: String) async throws -> Bool {
        // Use AXUI to check if element exists by ID
        return (try await findElement(by: id)) != nil
    }
    
    // MARK: - Helper Methods for Improved Element Discovery
    
    private func convertAXElementsToAIElements(_ axElements: [AXElement], windowHandle: WindowHandle) -> [AIElement] {
        return axElements.compactMap { axElement in
            createAIElementFromAXElement(axElement, windowHandle: windowHandle)
        }
    }
    
    private func createAIElementFromAXElement(_ axElement: AXElement, windowHandle: WindowHandle) -> AIElement? {
        guard let _ = axElement.role else { return nil }
        
        // Convert AXElement to AIElement using the convertToAIFormat method
        return axElement.convertToAIFormat()
    }
    
    private func filterElementsWithANDLogic(_ elements: [AIElement], role: AXUI.Role?, title: String?, identifier: String?) -> [AIElement] {
        return elements.filter { element in
            // AND logic: all specified criteria must match
            
            // Role matching - compare against AXElement's role
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
            
            // Additional quality filters using AIElement properties
            let bounds = element.boundsAsRect
            return element.isEnabled &&
                   bounds.width > 0 &&
                   bounds.height > 0
        }
    }
    
    private func selectBestMatch(from elements: [AIElement], role: String, title: String?, identifier: String?) -> AIElement {
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
                    let bounds = element.cgBounds
                    return element.isEnabled && bounds.width > 0 && bounds.height > 0
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
                    let bounds = element.cgBounds
                    return element.isEnabled && bounds.width > 0 && bounds.height > 0
                }
                return qualityMatches.isEmpty ? exactTitleMatches[0] : qualityMatches[0]
            }
        }
        
        // 3. Fallback: prefer enabled and visible elements
        let qualityMatches = elements.filter { element in
            let bounds = element.cgBounds
            return element.isEnabled && bounds.width > 0 && bounds.height > 0
        }
        
        if !qualityMatches.isEmpty {
            return qualityMatches[0]
        }
        
        // 4. Last resort: return the first element
        return elements[0]
    }
    
    // MARK: - ID-based Element Lookup
    
    private func findElement(by elementId: String) async throws -> AXElement? {
        // Search through all windows for the element
        for (_, windowData) in windowHandles {
            do {
                let bundleId = appHandles[windowData.appHandle.id]?.app.bundleIdentifier ?? ""
                let windowIndex = try await getWindowIndex(for: windowData.handle)
                
                // Use AXUI to dump elements and find by ID
                let elements = try AXDumper.dumpWindow(
                    bundleIdentifier: bundleId,
                    windowIndex: windowIndex,
                    includeZeroSize: false
                )
                
                // Find element with matching ID
                if let element = elements.first(where: { $0.id == elementId }) {
                    return element
                }
            } catch {
                // Continue searching in other windows
                continue
            }
        }
        
        return nil
    }
    
    private func getWindowIndex(for windowHandle: WindowHandle) async throws -> Int {
        guard let windowData = windowHandles[windowHandle.id],
              let _ = appHandles[windowData.appHandle.id] else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        let windows = try await getWindows(for: windowData.appHandle)
        guard let index = windows.firstIndex(where: { $0.id == windowHandle }) else {
            throw PilotError.windowNotFound(windowHandle)
        }
        
        return index
    }
    
    /// Find live AXUIElement for an element ID by searching AX tree
    private func findLiveAXElementForId(_ id: String, element: AXElement) async throws -> AXUIElement {
        // Search through all windows to find a live AXUIElement matching the element properties
        for (_, windowData) in windowHandles {
            if let foundElement = try? await findElementInAXTree(windowData.axWindow, targetElement: element) {
                return foundElement
            }
        }
        
        throw PilotError.elementNotAccessible(id)
    }
    
    /// Search AX tree for an element matching the target AXElement
    private func findElementInAXTree(_ rootAXElement: AXUIElement, targetElement: AXElement, depth: Int = 0, maxDepth: Int = 10) async throws -> AXUIElement {
        guard depth < maxDepth else {
            throw PilotError.elementNotAccessible(targetElement.id)
        }
        
        // Check if current element matches the target element
        if axElementMatches(rootAXElement, target: targetElement) {
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
    
    /// Check if AXUIElement matches target AXElement
    private func axElementMatches(_ axElement: AXUIElement, target: AXElement) -> Bool {
        let role = getStringAttribute(from: axElement, attribute: kAXRoleAttribute)
        let description = getStringAttribute(from: axElement, attribute: kAXDescriptionAttribute)
        let identifier = getStringAttribute(from: axElement, attribute: kAXIdentifierAttribute)
        let position = getPositionAttribute(from: axElement)
        let size = getSizeAttribute(from: axElement)
        
        // Match based on role, identifier, and position/size
        let roleMatches = role == target.role?.rawValue
        let identifierMatches = identifier == target.identifier
        let descriptionMatches = description == target.description
        
        // Position/size matching with small tolerance
        let positionMatches: Bool = {
            guard let pos = position, let targetPos = target.position else { 
                return position == nil && target.position == nil 
            }
            return abs(pos.x - targetPos.x) < 2 && abs(pos.y - targetPos.y) < 2
        }()
        
        let sizeMatches: Bool = {
            guard let sz = size, let targetSz = target.size else { 
                return size == nil && target.size == nil 
            }
            return abs(sz.width - targetSz.width) < 2 && abs(sz.height - targetSz.height) < 2
        }()
        
        // Element matches if role and identifier match and at least one other property matches
        return roleMatches && identifierMatches && (descriptionMatches || (positionMatches && sizeMatches))
    }
    
    
    
    
    // MARK: - Event Monitoring
    
    public func observeEvents(for window: WindowHandle, mask: AXMask) async -> AsyncStream<AXEvent> {
        return AsyncStream { continuation in
            Task {
                guard let windowData = windowHandles[window.id] else {
                    continuation.finish()
                    return
                }
                
                #if DEBUG
                // DEBUG: Simplified event monitoring implementation
                // For now, generate mock events based on the mask
                // TODO: Replace with real AXObserver implementation
                
                // Create AXObserver for the application (for future real implementation)
                let _ = appHandles[windowData.appHandle.id]!
                
                // Schedule mock event generation
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
                #else
                // PRODUCTION: Real AXObserver implementation
                // TODO: Implement real accessibility event monitoring using AXObserver
                
                guard let appData = appHandles[windowData.appHandle.id] else {
                    continuation.finish()
                    return
                }
                
                // For now, finish immediately in production builds
                // Real implementation would set up AXObserver with proper callbacks
                print("Event monitoring not yet implemented for production builds")
                continuation.finish()
                #endif
            }
        }
    }
    
    public func checkPermission() async -> Bool {
        return AXDumper.checkAccessibilityPermissions()
    }
    
    // MARK: - String to AXUI.Role Conversion
    
    /// Convert Role to AXUI.Role
    private func roleToAXUIRole(_ role: Role) -> AXUI.Role? {
        switch role {
        case .button:
            return .button
        case .field, .textField:
            return .field
        case .text, .staticText:
            return .text
        case .link:
            return .link
        case .image:
            return .image
        case .check, .checkBox:
            return .check
        case .radio, .radioButton:
            return .radio
        case .slider:
            return .slider
        default:
            return nil
        }
    }
}

