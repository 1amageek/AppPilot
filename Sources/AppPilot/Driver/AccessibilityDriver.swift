import Foundation
import ApplicationServices
import AppKit
import AXUI
import OSLog
import Carbon

// MARK: - Accessibility Constants

/// Window number attribute for getting CGWindowID from AXUIElement
/// This attribute provides the bridge between Accessibility API and ScreenCaptureKit
private let kAXWindowNumberAttribute = "AXWindowNumber"

// MARK: - Accessibility Driver Protocol

public protocol AccessibilityDriver: Sendable {
    // Application and Window Management
    func getApplications() async throws -> [AppInfo]
    func findApplication(bundleId: String) async throws -> AppHandle
    func findApplication(name: String) async throws -> AppHandle
    func getWindows(for app: AppHandle) async throws -> [WindowInfo]
    func findWindow(app: AppHandle, title: String) async throws -> WindowHandle?
    func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle?
    func findWindowHandle(byCGWindowID cgWindowID: UInt32) async throws -> WindowHandle?
    
    // UI Element Discovery (ID-based)
    func findElements(in window: WindowHandle, role: Role?, title: String?, identifier: String?) async throws -> [AXElement]
    func findElement(in window: WindowHandle, role: Role, title: String?, identifier: String?) async throws -> AXElement
    func elementExists(with id: String) async throws -> Bool
    func value(for id: String) async throws -> String?
    func setValue(_ value: String, for id: String) async throws
    
    // Event Monitoring
    func observeEvents(for window: WindowHandle, mask: AXMask) async -> AsyncStream<AXEvent>
    func checkPermission() async -> Bool
    
    // Window Handle Validation
    func isWindowHandleValid(_ windowHandle: WindowHandle) async -> Bool
}

// MARK: - Default Accessibility Driver Implementation

public actor DefaultAccessibilityDriver: AccessibilityDriver {
    
    private var appHandles: [String: AppHandleData] = [:]
    private var windowHandles: [String: WindowHandleData] = [:]
    private let logger = Logger(subsystem: "com.apppilot.accessibility", category: "WindowResolution")
    
    private struct AppHandleData {
        let handle: AppHandle
        let app: NSRunningApplication
        let axApp: AXUIElement
    }
    
    private struct WindowHandleData {
        let handle: WindowHandle
        let appHandle: AppHandle
        let axWindow: AXUIElement
        let axPointerHash: Int  // Added: AXUIElement pointer hash for consistency
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
        
        // Log the application being queried
        logger.debug("Getting windows for app: \(appHandle.id, privacy: .public) (\(appData.app.localizedName ?? "Unknown", privacy: .public))")
        
        // Get windows from Accessibility API
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appData.axApp, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
            logger.warning("Failed to get windows for app \(appHandle.id, privacy: .public) - AX result: \(String(describing: result), privacy: .public)")
            return []
        }
        
        logger.debug("Found \(axWindows.count) window(s) from Accessibility API for \(appData.app.localizedName ?? "Unknown", privacy: .public)")
        
        var windows: [WindowInfo] = []
        
        for (index, axWindow) in axWindows.enumerated() {
            let windowHandle = generateWindowHandle(for: axWindow, appHandle: appHandle)
            
            let title = getStringAttribute(from: axWindow, attribute: kAXTitleAttribute)
            let isMain = getBoolAttribute(from: axWindow, attribute: kAXMainAttribute) ?? false
            let isVisible = !(getBoolAttribute(from: axWindow, attribute: kAXHiddenAttribute) ?? false)
            let bounds = try getWindowBounds(from: axWindow)
            
            // Verify window ownership by checking the parent application
            let windowOwnershipInfo = try await verifyWindowOwnership(axWindow: axWindow, expectedApp: appData)
            
            logger.debug("Processing window \(index + 1): '\(title ?? "No title", privacy: .public)' (\(windowHandle.id, privacy: .public))")
            
            if !windowOwnershipInfo.verified {
                logger.warning("Window ownership verification failed for '\(title ?? "No title", privacy: .public)': \(windowOwnershipInfo.issue ?? "Unknown issue", privacy: .public)")
                logger.info("Skipping window that belongs to: \(windowOwnershipInfo.actualOwner ?? "Unknown", privacy: .public)")
                continue
            }
            
            // Extract CGWindowID from accessibility window using kAXWindowNumberAttribute
            let cgWindowID = getCGWindowID(from: axWindow)
            
            if let cgWindowID = cgWindowID {
                logger.debug("Window \(index + 1) CGWindowID: \(cgWindowID)")
            } else {
                logger.debug("Window \(index + 1) CGWindowID: unavailable")
            }
            
            let windowInfo = WindowInfo(
                id: windowHandle,
                title: title,
                bounds: bounds,
                isVisible: isVisible,
                isMain: isMain,
                appName: appData.app.localizedName ?? "Unknown",
                windowID: cgWindowID
            )
            windows.append(windowInfo)
        }
        
        logger.info("Returning \(windows.count) verified window(s) for \(appData.app.localizedName ?? "Unknown", privacy: .public)")
        
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
    
    /// Find window handle by CGWindowID (cross-driver integration)
    /// 
    /// This method enables bridging between AccessibilityDriver and ScreenDriver by allowing
    /// lookup of accessibility window handles using ScreenCaptureKit CGWindowID values.
    ///
    /// - Parameter cgWindowID: The CGWindowID to search for
    /// - Returns: WindowHandle if found, nil otherwise
    /// - Throws: Accessibility-related errors if permission issues occur
    public func findWindowHandle(byCGWindowID cgWindowID: UInt32) async throws -> WindowHandle? {
        guard let windowData = findWindowByCGWindowID(cgWindowID) else {
            return nil
        }
        
        return windowData.handle
    }
    
    // MARK: - UI Element Discovery
    
    public func findElements(in windowHandle: WindowHandle, role: Role?, title: String?, identifier: String?) async throws -> [AXElement] {
        
        // Check accessibility permission first
        guard await checkPermission() else {
            throw PilotError.permissionDenied("Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility")
        }
        
        guard let windowData = findCanonicalWindowHandle(windowHandle.id) else {
            logWindowHandleResolutionFailure(windowHandle.id, context: "findElements")
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
        
        // Convert Role to AXUI.Role for filtering
        let axuiRole: AXUI.Role? = role.flatMap { roleToAXUIRole($0) }
        
        // Apply precise filtering with AND logic
        return filterElementsWithANDLogic(axElements, role: axuiRole, title: title, identifier: identifier)
    }
    
    public func findElement(in window: WindowHandle, role: Role, title: String? = nil, identifier: String? = nil) async throws -> AXElement {
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
    
    
    
    /// Find the canonical handle for a window using comprehensive lookup strategy
    private func findCanonicalWindowHandle(_ handleId: String) -> WindowHandleData? {
        // Direct ID lookup
        if let data = windowHandles[handleId] {
            return data
        }
        
        logger.debug("Direct lookup failed for handle '\(handleId, privacy: .public)', attempting recovery...")
        
        // Try to find by scanning all apps and refreshing window handles
        // This is a recovery mechanism for when handles become stale
        
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }
            
            // Find our app handle
            guard let appData = appHandles.values.first(where: { $0.app.processIdentifier == app.processIdentifier }) else {
                continue
            }
            
            // Get windows from Accessibility API
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appData.axApp, kAXWindowsAttribute as CFString, &windowsRef)
            
            guard result == .success, let axWindows = windowsRef as? [AXUIElement] else {
                continue
            }
            
            // Check if any of these windows should have the target handle ID
            for axWindow in axWindows {
                let regeneratedID = createConsistentWindowID(for: axWindow, appHandle: appData.handle)
                if regeneratedID == handleId {
                    // Found the window! Update our cache
                    let axPointerHash = Int(bitPattern: Unmanaged.passUnretained(axWindow).toOpaque())
                    let windowData = WindowHandleData(
                        handle: WindowHandle(id: handleId),
                        appHandle: appData.handle,
                        axWindow: axWindow,
                        axPointerHash: axPointerHash
                    )
                    windowHandles[handleId] = windowData
                    logger.debug("Recovered window handle '\(handleId, privacy: .public)' through regeneration")
                    return windowData
                }
            }
        }
        
        logger.warning("Failed to recover window handle '\(handleId, privacy: .public)'")
        return nil
    }
    
    
    
    /// Simple error reporting for window handle resolution failures
    private func logWindowHandleResolutionFailure(_ targetHandle: String, context: String) {
        logger.error("Window handle not found: '\(targetHandle, privacy: .public)' in \(context, privacy: .public)")
    }
    
    /// Find window handle by CGWindowID
    /// 
    /// This method searches all cached window handles for one that matches the specified CGWindowID.
    /// This provides direct lookup capability for integrating with ScreenCaptureKit.
    ///
    /// - Parameter cgWindowID: The CGWindowID to search for
    /// - Returns: WindowHandleData if found, nil otherwise
    private func findWindowByCGWindowID(_ cgWindowID: UInt32) -> WindowHandleData? {
        logger.debug("Searching for window with CGWindowID: \(cgWindowID)")
        
        // Search all cached windows for matching CGWindowID
        for (handleId, windowData) in windowHandles {
            if let currentCGWindowID = getCGWindowID(from: windowData.axWindow) {
                if currentCGWindowID == cgWindowID {
                    logger.debug("Found window handle '\(handleId, privacy: .public)' for CGWindowID: \(cgWindowID)")
                    return windowData
                }
            }
        }
        
        logger.debug("No window handle found for CGWindowID: \(cgWindowID)")
        return nil
    }
    
    /// Validate that CGWindowID from AX matches expected value
    /// 
    /// This method can be used to verify consistency between cached CGWindowID values
    /// and live AX data, helping detect stale window references.
    ///
    /// - Parameters:
    ///   - axWindow: The accessibility window element
    ///   - expectedCGWindowID: The expected CGWindowID
    /// - Returns: true if the CGWindowID matches or is unavailable, false if mismatched
    private func validateCGWindowIDConsistency(axWindow: AXUIElement, expectedCGWindowID: UInt32) -> Bool {
        guard let actualCGWindowID = getCGWindowID(from: axWindow) else {
            // If CGWindowID is unavailable, we can't validate but shouldn't fail
            return true
        }
        
        let isConsistent = actualCGWindowID == expectedCGWindowID
        if !isConsistent {
            logger.warning("CGWindowID mismatch - expected: \(expectedCGWindowID), actual: \(actualCGWindowID)")
        }
        
        return isConsistent
    }
    
    // MARK: - Private Helper Methods
    
    private func generateAppHandle(for app: NSRunningApplication) async throws -> AppHandle {
        // Check if we already have a handle for this app
        for (_, data) in appHandles {
            if data.app.processIdentifier == app.processIdentifier {
                return data.handle
            }
        }
        
        // Generate deterministic app handle based on bundle ID and process ID
        let bundleId = app.bundleIdentifier ?? "unknown"
        let processId = app.processIdentifier
        
        var hasher = Hasher()
        hasher.combine(bundleId)
        hasher.combine(processId)
        let hash = abs(hasher.finalize())
        
        let handle = AppHandle(id: "app_\(String(format: "%08X", hash))")
        
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
    
    private func generateWindowHandle(for axWindow: AXUIElement, appHandle: AppHandle) -> WindowHandle {
        // Get AXUIElement pointer hash for consistency
        let axPointerHash = Int(bitPattern: Unmanaged.passUnretained(axWindow).toOpaque())
        
        // Check if we already have a WindowHandle for this exact AXUIElement (by pointer)
        if let existingData = windowHandles.values.first(where: { $0.axPointerHash == axPointerHash }) {
            return existingData.handle
        }
        
        // Try to use CGWindowID as primary key (correct system specification approach)
        if let cgWindowID = getCGWindowID(from: axWindow) {
            let windowId = "win_cgid_\(cgWindowID)"
            
            // Check if we already have this CGWindowID-based handle
            if let existingData = windowHandles[windowId] {
                // Update the pointer hash in case the AXUIElement was recreated
                let updatedData = WindowHandleData(
                    handle: existingData.handle,
                    appHandle: existingData.appHandle,
                    axWindow: axWindow,
                    axPointerHash: axPointerHash
                )
                windowHandles[windowId] = updatedData
                return existingData.handle
            }
            
            // Create new CGWindowID-based handle
            let handle = WindowHandle(id: windowId)
            let windowData = WindowHandleData(
                handle: handle,
                appHandle: appHandle,
                axWindow: axWindow,
                axPointerHash: axPointerHash
            )
            windowHandles[windowId] = windowData
            return handle
        }
        
        // Fallback to property-based ID for windows without CGWindowID
        let consistentID = createConsistentWindowID(for: axWindow, appHandle: appHandle)
        if let existingData = windowHandles[consistentID] {
            // Update the pointer hash in case the AXUIElement was recreated
            let updatedData = WindowHandleData(
                handle: existingData.handle,
                appHandle: existingData.appHandle,
                axWindow: axWindow,
                axPointerHash: axPointerHash
            )
            windowHandles[consistentID] = updatedData
            return existingData.handle
        }
        
        // Create new property-based window handle
        let handle = WindowHandle(id: consistentID)
        
        let windowData = WindowHandleData(
            handle: handle,
            appHandle: appHandle,
            axWindow: axWindow,
            axPointerHash: axPointerHash
        )
        
        windowHandles[handle.id] = windowData
        
        return handle
    }
    
    
    
    private func createConsistentWindowID(for axWindow: AXUIElement, appHandle: AppHandle) -> String {
        // First try to get CGWindowID if available (most stable system identifier)
        if let cgWindowID = getCGWindowID(from: axWindow) {
            return "win_cgw_\(cgWindowID)"
        }
        
        // Second try to get AX identifier if available (stable and preferred for accessibility)
        if let axIdentifier = getStringAttribute(from: axWindow, attribute: kAXIdentifierAttribute),
           !axIdentifier.isEmpty {
            return "win_ax_\(axIdentifier)"
        }
        
        // Try to get more stable attributes
        let role = getStringAttribute(from: axWindow, attribute: kAXRoleAttribute) ?? ""
        let subrole = getStringAttribute(from: axWindow, attribute: kAXSubroleAttribute) ?? ""
        let position = getPositionAttribute(from: axWindow)
        let size = getSizeAttribute(from: axWindow)
        
        // Generate deterministic hash prioritizing stable properties
        var hasher = Hasher()
        hasher.combine(appHandle.id)
        hasher.combine(role)
        hasher.combine(subrole)
        
        // Use rounded position and size to reduce sensitivity to minor changes
        if let pos = position {
            hasher.combine(Int(pos.x / 10) * 10)  // Round to nearest 10 pixels
            hasher.combine(Int(pos.y / 10) * 10)
        }
        if let sz = size {
            hasher.combine(Int(sz.width / 10) * 10)  // Round to nearest 10 pixels
            hasher.combine(Int(sz.height / 10) * 10)
        }
        
        // Include title only for small windows (likely static UI elements)
        // For large windows, title changes frequently and shouldn't be used for ID
        if let sz = size, sz.width < 200 || sz.height < 100 {
            let title = getStringAttribute(from: axWindow, attribute: kAXTitleAttribute) ?? ""
            hasher.combine(title)
        }
        
        let hash = abs(hasher.finalize())
        return "win_\(String(format: "%08X", hash))"
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
    
    /// Check if a WindowHandle is valid and accessible
    public func isWindowHandleValid(_ windowHandle: WindowHandle) async -> Bool {
        guard let windowData = findCanonicalWindowHandle(windowHandle.id) else {
            return false
        }
        
        // Verify the AXUIElement is still valid
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(windowData.axWindow, kAXTitleAttribute as CFString, &value)
        return result == .success
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
    
    /// Get CGWindowID from AXUIElement using kAXWindowNumberAttribute
    /// 
    /// This provides the bridge between AccessibilityDriver windows and ScreenCaptureKit CGWindowID.
    /// The CGWindowID is a stable system identifier that can be used for direct window capture.
    ///
    /// - Parameter axWindow: The accessibility window element
    /// - Returns: The CGWindowID if available, nil otherwise
    private func getCGWindowID(from axWindow: AXUIElement) -> UInt32? {
        var windowNumber: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXWindowNumberAttribute as CFString, &windowNumber)
        
        guard result == .success, let windowNumber = windowNumber else {
            return nil
        }
        
        // Handle different possible types that kAXWindowNumberAttribute might return
        if let number = windowNumber as? NSNumber {
            return number.uint32Value
        } else if CFGetTypeID(windowNumber) == CFNumberGetTypeID() {
            let cfNumber = unsafeDowncast(windowNumber, to: CFNumber.self)
            var value: UInt32 = 0
            if CFNumberGetValue(cfNumber, .sInt32Type, &value) {
                return value
            }
        }
        
        return nil
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
    
    
    private func filterElementsWithANDLogic(_ elements: [AXElement], role: AXUI.Role?, title: String?, identifier: String?) -> [AXElement] {
        return elements.compactMap { element in
            // AND logic: all specified criteria must match
            
            // Role matching - compare against AXElement's role
            if let role = role, element.role != role {
                return nil
            }
            
            // Title matching (case-insensitive, partial match)
            if let title = title {
                guard let elementTitle = element.description,
                      elementTitle.localizedCaseInsensitiveContains(title) else {
                    return nil
                }
            }
            
            // Identifier matching (exact match)
            if let identifier = identifier, element.identifier != identifier {
                return nil
            }
            
            // Additional quality filters using AXElement properties
            let bounds = element.cgBounds
            guard element.isEnabled &&
                   bounds.width > 0 &&
                   bounds.height > 0 else {
                return nil
            }
            
            return element
        }
    }
    
    private func selectBestMatch(from elements: [AXElement], role: String, title: String?, identifier: String?) -> AXElement {
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
                element.description?.lowercased() == title.lowercased()
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
        guard let windowData = findCanonicalWindowHandle(windowHandle.id),
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
    
    // MARK: - Window Ownership Verification
    
    /// Window ownership verification result
    private struct WindowOwnershipInfo {
        let verified: Bool
        let issue: String?
        let actualOwner: String?
    }
    
    /// Verify that a window actually belongs to the expected application using multiple validation methods
    private func verifyWindowOwnership(axWindow: AXUIElement, expectedApp: AppHandleData) async throws -> WindowOwnershipInfo {
        let expectedPID = expectedApp.app.processIdentifier
        let expectedBundleId = expectedApp.app.bundleIdentifier
        let expectedAppName = expectedApp.app.localizedName
        
        // Method 1: Process ID verification (most reliable)
        if let actualPID = getWindowProcessId(from: axWindow) {
            if actualPID == expectedPID {
                logger.debug("Window ownership verified by PID for \(expectedAppName ?? "Unknown", privacy: .public)")
                return WindowOwnershipInfo(verified: true, issue: nil, actualOwner: nil)
            } else {
                // Find the actual application with this PID
                let runningApps = NSWorkspace.shared.runningApplications
                let actualApp = runningApps.first { $0.processIdentifier == actualPID }
                let actualOwner = actualApp?.localizedName ?? "Unknown"
                let actualBundleId = actualApp?.bundleIdentifier ?? "Unknown"
                
                logger.debug("Window PID mismatch: expected \(expectedPID), actual \(actualPID) (\(actualOwner, privacy: .public))")
                
                return WindowOwnershipInfo(
                    verified: false,
                    issue: "Window PID (\(actualPID)) ≠ Expected PID (\(expectedPID)). Window belongs to '\(actualOwner)' (\(actualBundleId))",
                    actualOwner: actualOwner
                )
            }
        }
        
        // Method 2: Bundle ID verification (fallback)
        if let expectedBundleId = expectedBundleId,
           let windowBundleId = getWindowBundleId(from: axWindow) {
            if windowBundleId == expectedBundleId {
                logger.debug("Window ownership verified by Bundle ID (PID unavailable) for \(expectedAppName ?? "Unknown", privacy: .public)")
                return WindowOwnershipInfo(
                    verified: true,
                    issue: "PID unavailable, verified by Bundle ID",
                    actualOwner: nil
                )
            } else {
                logger.debug("Window Bundle ID mismatch: expected \(expectedBundleId, privacy: .public), actual \(windowBundleId, privacy: .public)")
                return WindowOwnershipInfo(
                    verified: false,
                    issue: "Window Bundle ID (\(windowBundleId)) ≠ Expected Bundle ID (\(expectedBundleId))",
                    actualOwner: "Bundle ID: \(windowBundleId)"
                )
            }
        }
        
        // Method 3: Parent application verification (last resort)
        if let parentApp = getParentApplication(from: axWindow) {
            if let parentPID = getProcessId(from: parentApp) {
                if parentPID == expectedPID {
                    logger.debug("Window ownership verified by parent app (last resort) for \(expectedAppName ?? "Unknown", privacy: .public)")
                    return WindowOwnershipInfo(
                        verified: true,
                        issue: "Direct PID and Bundle ID unavailable, verified by parent app",
                        actualOwner: nil
                    )
                } else {
                    let runningApps = NSWorkspace.shared.runningApplications
                    let actualApp = runningApps.first { $0.processIdentifier == parentPID }
                    let actualOwner = actualApp?.localizedName ?? "Unknown"
                    
                    logger.debug("Parent App PID mismatch: expected \(expectedPID), actual \(parentPID) (\(actualOwner, privacy: .public))")
                    return WindowOwnershipInfo(
                        verified: false,
                        issue: "Parent App PID (\(parentPID)) ≠ Expected PID (\(expectedPID)). Parent is '\(actualOwner)'",
                        actualOwner: actualOwner
                    )
                }
            }
        }
        
        // Method 4: Complete failure - unable to verify ownership
        logger.warning("Unable to verify window ownership through any method for \(expectedAppName ?? "Unknown", privacy: .public)")
        return WindowOwnershipInfo(
            verified: false,
            issue: "Unable to verify window ownership - no PID, Bundle ID, or Parent App information available",
            actualOwner: "Unknown"
        )
    }
    
    /// Get bundle identifier from an application AXUIElement
    private func getApplicationBundleId(from axApp: AXUIElement) -> String? {
        // Try to get bundle identifier attribute
        if let bundleId = getStringAttribute(from: axApp, attribute: "AXBundleIdentifier") {
            return bundleId
        }
        
        // Alternative: try to get process ID and look up bundle ID
        if let pid = getProcessId(from: axApp) {
            let runningApps = NSWorkspace.shared.runningApplications
            return runningApps.first { $0.processIdentifier == pid }?.bundleIdentifier
        }
        
        return nil
    }
    
    /// Get process ID from a window AXUIElement
    private func getWindowProcessId(from axWindow: AXUIElement) -> pid_t? {
        // Get process ID directly from the window element
        var pid: pid_t = 0
        let result = AXUIElementGetPid(axWindow, &pid)
        
        if result == .success {
            return pid
        }
        
        return nil
    }
    
    /// Get process ID from an application AXUIElement
    private func getProcessId(from axApp: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(axApp, &pid)
        
        if result == .success {
            return pid
        }
        
        return nil
    }
    
    /// Get bundle identifier from a window AXUIElement
    private func getWindowBundleId(from axWindow: AXUIElement) -> String? {
        // Try to get the parent application first
        if let parentApp = getParentApplication(from: axWindow) {
            return getApplicationBundleId(from: parentApp)
        }
        
        // Alternative: try to get PID and look up bundle ID
        if let pid = getWindowProcessId(from: axWindow) {
            let runningApps = NSWorkspace.shared.runningApplications
            return runningApps.first { $0.processIdentifier == pid }?.bundleIdentifier
        }
        
        return nil
    }
    
    /// Get parent application AXUIElement from a window
    private func getParentApplication(from axWindow: AXUIElement) -> AXUIElement? {
        // Method 1: Try to get the parent application directly
        var appRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXParentAttribute as CFString, &appRef)
        
        if result == .success, let parentRef = appRef {
            // CoreFoundation type conversion - need to check type ID
            let axElementTypeID = AXUIElementGetTypeID()
            if CFGetTypeID(parentRef) == axElementTypeID {
                let parentElement = unsafeDowncast(parentRef, to: AXUIElement.self)
                
                // Check if this is the application element
                if let role = getStringAttribute(from: parentElement, attribute: kAXRoleAttribute),
                   role == kAXApplicationRole {
                    return parentElement
                }
                
                // If not, try to traverse up the hierarchy
                return getParentApplication(from: parentElement)
            }
        }
        
        // Method 2: Create application element from window's PID
        if let pid = getWindowProcessId(from: axWindow) {
            return AXUIElementCreateApplication(pid)
        }
        
        return nil
    }
}

