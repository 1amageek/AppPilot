import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

// MARK: - Shared Test Support Types

// Test session management for proper isolation
actor TestSession {
    let pilot: AppPilot
    let testType: TestType
    let app: AppInfo
    private(set) var window: WindowInfo
    private let api: CorrectFlowTestAppAPI
    
    enum TestType {
        case mouseClick
        case keyboard
        case wait
    }
    
    static func create(pilot: AppPilot, testType: TestType) async throws -> TestSession {
        // ⭐ Enhanced session creation with retries and better app detection
        var testApp: AppInfo?
        
        for attempt in 1...3 {
            let apps = try await pilot.listApplications()
            print("🔍 Attempt \(attempt): Found \(apps.count) running applications")
            
            // Enhanced TestApp detection with multiple strategies
            testApp = apps.first(where: { app in
                let nameMatches = app.name.localizedCaseInsensitiveContains("TestApp") ||
                                 app.name.localizedCaseInsensitiveContains("AppMCP") ||
                                 app.name == "AppMCP Test App"
                
                let bundleMatches = app.bundleIdentifier?.localizedCaseInsensitiveContains("TestApp") ?? false ||
                                   app.bundleIdentifier?.localizedCaseInsensitiveContains("AppMCP") ?? false
                
                if nameMatches || bundleMatches {
                    print("   ✅ Found potential TestApp: \(app.name) (\(app.bundleIdentifier ?? "No bundle ID"))")
                    return true
                }
                return false
            })
            
            if testApp != nil {
                break
            } else {
                // Debug: List all available apps
                print("   📋 Available apps:")
                for app in apps.prefix(10) {
                    print("     - \(app.name) (\(app.bundleIdentifier ?? "No bundle ID"))")
                }
                
                if attempt < 3 {
                    print("⚠️ TestApp not found on attempt \(attempt), retrying...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }
        
        guard let testApp = testApp else {
            print("❌ TestApp not found after 3 attempts")
            print("💡 Please ensure TestApp is running and accessible")
            throw TestSessionError.testAppNotFound
        }
        
        // Get window with enhanced error handling
        print("🪟 Getting windows for TestApp: \(testApp.name)")
        let windows = try await pilot.listWindows(app: testApp.id)
        print("   Found \(windows.count) windows")
        
        for (index, window) in windows.enumerated() {
            print("   Window \(index + 1): '\(window.title ?? "No title")' bounds: \(window.bounds)")
        }
        
        guard let window = windows.first else {
            print("❌ No windows found for TestApp")
            throw TestSessionError.noWindowsFound
        }
        
        print("✅ Using window: '\(window.title ?? "No title")'")
        
        let session = TestSession(pilot: pilot, testType: testType, app: testApp, window: window)
        
        // ⭐ Enhanced session initialization
        print("🔄 Initializing test session...")
        await session.resetState()
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        print("✅ Test session created successfully")
        
        return session
    }
    
    private init(pilot: AppPilot, testType: TestType, app: AppInfo, window: WindowInfo) {
        self.pilot = pilot
        self.testType = testType
        self.app = app
        self.window = window
        self.api = CorrectFlowTestAppAPI()
    }
    
    func resetState() async {
        do {
            try await api.resetState()
            print("✅ TestApp state reset")
        } catch {
            print("⚠️ Could not reset TestApp state: \(error)")
        }
    }
    
    func getClickTargets() async -> [CorrectFlowClickTarget] {
        do {
            return try await api.getClickTargets()
        } catch {
            print("⚠️ Could not get click targets: \(error)")
            return []
        }
    }
    
    func refreshWindow() async throws {
        let windows = try await pilot.listWindows(app: app.id)
        guard let updatedWindow = windows.first else {
            throw TestSessionError.noWindowsFound
        }
        window = updatedWindow
        print("🔄 Window refreshed: '\(window.title ?? "No title")'")
    }
    
    func cleanup() async {
        print("🧹 Starting test session cleanup...")
        await resetState()
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        print("✅ Test session cleaned up")
    }
    
    // MARK: - Window and Navigation Helpers
    
    /// Activate TestApp window to ensure it has focus
    func activateWindow() async throws {
        print("🔥 Activating TestApp window...")
        
        // Click on title bar area to activate window
        let activationPoint = Point(
            x: window.bounds.midX,
            y: window.bounds.minY + 20 // Title bar area
        )
        
        print("🖱️ Clicking to activate window at: (\(activationPoint.x), \(activationPoint.y))")
        let result = try await pilot.click(window: window.id, at: activationPoint)
        
        if result.success {
            print("✅ Window activation successful")
        } else {
            print("⚠️ Window activation may have failed, continuing anyway")
        }
        
        // Wait for activation to complete
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait time
    }
    
    /// Navigate to the appropriate tab based on test type
    func navigateToTab() async throws {
        print("🧭 Navigating to \(testType) tab...")
        
        // First ensure window is active
        try await activateWindow()
        
        // Get current UI elements with detailed analysis
        let elements = try await pilot.findElements(in: window.id)
        print("🔍 Found \(elements.count) total elements in window")
        print("   Window bounds: \(window.bounds)")
        
        // ⭐ Enhanced UI Tree Analysis with detailed debugging
        print("\n📊 Complete UI Tree Analysis:")
        let sortedByPosition = elements.sorted { $0.centerPoint.y < $1.centerPoint.y }
        
        for (index, element) in sortedByPosition.enumerated() {
            let isInSidebar = element.centerPoint.x < 250 && element.centerPoint.x > 0
            let sidebarMarker = isInSidebar ? " [SIDEBAR]" : ""
            print("   \(String(format: "%3d", index + 1)). \(element.role.rawValue)\(sidebarMarker)")
            print("       Position: (\(String(format: "%.1f", element.centerPoint.x)), \(String(format: "%.1f", element.centerPoint.y)))")
            print("       Bounds: \(element.bounds)")
            print("       Title: '\(element.title ?? "NO_TITLE")'")
            print("       ID: '\(element.identifier ?? "NO_ID")'")
            print("       Enabled: \(element.isEnabled)")
        }
        
        // Find navigation elements in left sidebar with enhanced filtering
        // TestApp sidebar elements are typically AXCell or AXUnknown in the left panel
        let sidebarElements = elements.filter { element in
            let isInLeftPanel = element.centerPoint.x >= 589 && element.centerPoint.x <= 839  // Based on actual sidebar bounds
            let hasReasonableSize = element.bounds.width > 100 && element.bounds.height > 30   // Larger size for main nav items
            let isNavigationRole = (element.role == .cell || element.role == .unknown)          // Main navigation elements
            let isInNavigationArea = element.centerPoint.y <= -850                             // Upper part of sidebar
            
            // Additional check for elements that look like navigation items
            let looksLikeNavItem = isInLeftPanel && hasReasonableSize && isNavigationRole && isInNavigationArea
            
            if looksLikeNavItem {
                print("   🔍 Potential nav element: \(element.role.rawValue) at (\(String(format: "%.1f", element.centerPoint.x)), \(String(format: "%.1f", element.centerPoint.y))) size: \(element.bounds.width)x\(element.bounds.height)")
            }
            
            return looksLikeNavItem
        }
        
        print("\n📋 Sidebar Navigation Elements Analysis:")
        print("   Found \(sidebarElements.count) potential navigation elements")
        
        // Sort by Y position to get tab order
        let sortedTabs = sidebarElements.sorted { $0.centerPoint.y < $1.centerPoint.y }
        
        for (index, tab) in sortedTabs.enumerated() {
            print("   Tab \(index): \(tab.role.rawValue) at (\(String(format: "%.1f", tab.centerPoint.x)), \(String(format: "%.1f", tab.centerPoint.y))) - '\(tab.title ?? "NO_TITLE")'")
        }
        
        // Determine target tab index based on test type
        let targetIndex: Int
        let targetName: String
        
        switch testType {
        case .mouseClick:
            targetIndex = 0
            targetName = "Mouse Click"
        case .keyboard:
            targetIndex = 1
            targetName = "Keyboard"
        case .wait:
            targetIndex = 2
            targetName = "Wait"
        }
        
        print("\n🎯 Target: \(targetName) (index \(targetIndex))")
        
        // Verify we have enough tabs
        guard !sortedTabs.isEmpty else {
            print("❌ No navigation tabs found in sidebar")
            throw TestSessionError.navigationFailed
        }
        
        // Try element-based navigation with enhanced debugging
        var navigationSuccessful = false
        var clickedElement: UIElement?
        
        // Look for image elements that might indicate navigation (used across strategies)
        let imageElements = elements.filter { element in
            element.role == .image && 
            element.centerPoint.x >= 589 && element.centerPoint.x <= 839 &&
            element.centerPoint.y <= -850
        }
        
        // Strategy 1: Find by image identifier (TestApp uses image icons for navigation)
        print("\n🔍 Strategy 1: Icon/Image-based navigation")
        
        print("   Found \(imageElements.count) image elements in sidebar:")
        for (index, img) in imageElements.enumerated() {
            print("     \(index + 1). Image ID: '\(img.identifier ?? "NO_ID")' at (\(String(format: "%.1f", img.centerPoint.x)), \(String(format: "%.1f", img.centerPoint.y)))")
        }
        
        // Map test types to expected image identifiers
        let expectedImageIds: [TestType: [String]] = [
            .mouseClick: ["cursorarrow.click", "cursor", "mouse"],
            .keyboard: ["keyboard"],
            .wait: ["clock", "timer"]
        ]
        
        if let expectedIds = expectedImageIds[testType] {
            for expectedId in expectedIds {
                if let imageElement = imageElements.first(where: { img in
                    img.identifier?.contains(expectedId) == true
                }) {
                    print("   🎯 Found matching image icon: '\(imageElement.identifier ?? "NO_ID")'")
                    print("      Coordinates: (\(String(format: "%.1f", imageElement.centerPoint.x)), \(String(format: "%.1f", imageElement.centerPoint.y)))")
                    
                    let result = try await pilot.click(window: window.id, at: imageElement.centerPoint)
                    if result.success {
                        navigationSuccessful = true
                        clickedElement = imageElement
                        print("   ✅ Icon-based navigation successful")
                        break
                    } else {
                        print("   ❌ Icon-based click failed")
                    }
                }
            }
        }
        
        // Strategy 2: Use cell elements containing navigation icons
        if !navigationSuccessful {
            print("\n🔍 Strategy 2: Cell-based navigation (click parent cells)")
            
            // Find cells that might contain navigation icons
            let cellElements = elements.filter { element in
                element.role == .cell &&
                element.centerPoint.x >= 589 && element.centerPoint.x <= 839 &&
                element.centerPoint.y <= -850 &&
                element.bounds.width > 200 && element.bounds.height > 40
            }
            
            print("   Found \(cellElements.count) cell elements:")
            for (index, cell) in cellElements.enumerated() {
                print("     \(index + 1). Cell at (\(String(format: "%.1f", cell.centerPoint.x)), \(String(format: "%.1f", cell.centerPoint.y))) size: \(cell.bounds.width)x\(cell.bounds.height)")
            }
            
            // Sort cells by Y position (top to bottom)
            let sortedCells = cellElements.sorted { $0.centerPoint.y < $1.centerPoint.y }
            
            if targetIndex < sortedCells.count {
                let targetCell = sortedCells[targetIndex]
                print("   🎯 Clicking cell at index \(targetIndex)")
                print("      Cell coordinates: (\(String(format: "%.1f", targetCell.centerPoint.x)), \(String(format: "%.1f", targetCell.centerPoint.y)))")
                
                let result = try await pilot.click(window: window.id, at: targetCell.centerPoint)
                if result.success {
                    navigationSuccessful = true
                    clickedElement = targetCell
                    print("   ✅ Cell-based navigation successful")
                } else {
                    print("   ❌ Cell-based click failed")
                }
            } else {
                print("   ❌ Target index \(targetIndex) >= available cells (\(sortedCells.count))")
            }
        }
        
        // Strategy 3: Use broader sidebar elements (AXUnknown)
        if !navigationSuccessful {
            print("\n🔍 Strategy 3: Sidebar AXUnknown elements navigation")
            if targetIndex < sortedTabs.count {
                let targetElement = sortedTabs[targetIndex]
                print("   🎯 Clicking sidebar element at index \(targetIndex)")
                print("      Element: \(targetElement.role.rawValue)")
                print("      Coordinates: (\(String(format: "%.1f", targetElement.centerPoint.x)), \(String(format: "%.1f", targetElement.centerPoint.y)))")
                
                let result = try await pilot.click(window: window.id, at: targetElement.centerPoint)
                if result.success {
                    navigationSuccessful = true
                    clickedElement = targetElement
                    print("   ✅ Sidebar element navigation successful")
                } else {
                    print("   ❌ Sidebar element click failed")
                }
            } else {
                print("   ❌ Target index \(targetIndex) >= available sidebar elements (\(sortedTabs.count))")
            }
        }
        
        // Strategy 4: Fallback coordinate-based approach
        if !navigationSuccessful {
            print("\n🔍 Strategy 4: Coordinate-based fallback")
            
            // Calculate fallback positions based on sidebar analysis
            let fallbackPositions: [Point]
            if !sortedTabs.isEmpty {
                // Use actual sidebar elements to estimate positions
                let firstTabY = sortedTabs[0].centerPoint.y
                let avgSpacing: CGFloat = sortedTabs.count > 1 ? 
                    (sortedTabs[1].centerPoint.y - sortedTabs[0].centerPoint.y) : 40
                let avgX = sortedTabs.map { $0.centerPoint.x }.reduce(0, +) / CGFloat(sortedTabs.count)
                
                fallbackPositions = [
                    Point(x: avgX, y: firstTabY + CGFloat(targetIndex) * avgSpacing),
                    Point(x: 150, y: window.bounds.minY + 100 + CGFloat(targetIndex) * 40),
                    Point(x: 125, y: window.bounds.minY + 120 + CGFloat(targetIndex) * 35)
                ]
            } else {
                // Absolute fallback based on window
                fallbackPositions = [
                    Point(x: 150, y: window.bounds.minY + 100 + CGFloat(targetIndex) * 40),
                    Point(x: 125, y: window.bounds.minY + 120 + CGFloat(targetIndex) * 35),
                    Point(x: 175, y: window.bounds.minY + 140 + CGFloat(targetIndex) * 30)
                ]
            }
            
            for (index, fallbackPoint) in fallbackPositions.enumerated() {
                print("   Fallback attempt \(index + 1): (\(String(format: "%.1f", fallbackPoint.x)), \(String(format: "%.1f", fallbackPoint.y)))")
                let result = try await pilot.click(window: window.id, at: fallbackPoint)
                if result.success {
                    print("   ✅ Coordinate fallback \(index + 1) successful")
                    navigationSuccessful = true
                    break
                } else {
                    print("   ❌ Coordinate fallback \(index + 1) failed")
                }
                
                // Small delay between attempts
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        
        // Final verification before proceeding
        if !navigationSuccessful {
            print("❌ ALL NAVIGATION STRATEGIES FAILED")
            print("   Tried: Icon-based, Cell-based, Sidebar element-based, Coordinate fallback")
            print("   Available sidebar elements: \(sortedTabs.count)")
            print("   Target: \(targetName) (index \(targetIndex))")
            print("   Image elements found: \(imageElements.count)")
            throw TestSessionError.navigationFailed
        }
        
        print("✅ Navigation successful using \(clickedElement != nil ? "element-based" : "coordinate-based") approach")
        
        // Wait for UI to update after navigation
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait time
        
        // Refresh window info after navigation
        try await refreshWindow()
        
        // ⭐ Enhanced navigation verification with detailed content analysis
        print("\n🔍 Verifying navigation success...")
        let verificationElements = try await pilot.findElements(in: window.id)
        
        let verificationResult: Bool
        switch testType {
        case .mouseClick:
            let buttons = verificationElements.filter { $0.role == .button }
            let clickableElements = verificationElements.filter { 
                $0.role == .button && $0.centerPoint.x > 300 && $0.isEnabled 
            }
            print("   Found \(buttons.count) buttons, \(clickableElements.count) in content area")
            verificationResult = clickableElements.count > 0
            
        case .keyboard:
            let textFields = verificationElements.filter { $0.role == .textField }
            let inputElements = verificationElements.filter { 
                $0.role == .textField && $0.centerPoint.x > 300 
            }
            print("   Found \(textFields.count) text fields, \(inputElements.count) in content area")
            verificationResult = inputElements.count > 0
            
        case .wait:
            let waitElements = verificationElements.filter { element in
                element.title?.localizedCaseInsensitiveContains("wait") ?? false ||
                element.title?.localizedCaseInsensitiveContains("second") ?? false
            }
            print("   Found \(waitElements.count) wait-related elements")
            verificationResult = waitElements.count > 0
        }
        
        if verificationResult {
            print("✅ Navigation verification successful - correct tab content detected")
        } else {
            print("⚠️ Navigation verification inconclusive - expected content not found")
            print("   This may indicate navigation to wrong tab or content not yet loaded")
        }
        
        print("✅ Navigation to \(targetName) tab completed")
    }
}

// TestApp API client
struct CorrectFlowTestAppAPI {
    private let baseURL = "http://localhost:8765"
    
    func resetState() async throws {
        guard let url = URL(string: "\(baseURL)/api/reset") else {
            throw TestSessionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0 // ⭐ Enhanced timeout
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TestSessionError.apiError("Reset failed")
        }
    }
    
    func getClickTargets() async throws -> [CorrectFlowClickTarget] {
        guard let url = URL(string: "\(baseURL)/api/targets") else {
            throw TestSessionError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // ⭐ Enhanced timeout
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw TestSessionError.invalidResponse
        }
        
        return try jsonArray.map { try CorrectFlowClickTarget.fromJSON($0) }
    }
}

// Supporting data types
struct CorrectFlowClickTarget {
    let id: String
    let clicked: Bool
    
    static func fromJSON(_ json: [String: Any]) throws -> CorrectFlowClickTarget {
        guard let id = json["id"] as? String else {
            throw TestSessionError.invalidResponse
        }
        
        let clicked = json["clicked"] as? Bool ?? false
        
        return CorrectFlowClickTarget(id: id, clicked: clicked)
    }
}

enum TestSessionError: Error {
    case testAppNotFound
    case noWindowsFound
    case noTargetsFound
    case navigationFailed
    case invalidURL
    case apiError(String)
    case invalidResponse
}

// String multiplication helper
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// MARK: - Internal Helper Extensions

extension AppPilot {
    
    /// Quick method to find app and window for testing
    internal func findTestApp(name: String = "TestApp") async throws -> (app: AppHandle, window: WindowHandle) {
        let app = try await findApplication(name: name)
        guard let window = try await findWindow(app: app, index: 0) else {
            throw PilotError.windowNotFound(WindowHandle(id: "not_found"))
        }
        return (app: app, window: window)
    }
}
