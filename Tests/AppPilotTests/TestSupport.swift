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
                let nameMatches = app.name.localizedCaseInsensitiveContains("TestApp")
                
                let bundleMatches = app.bundleIdentifier == "team.stamp.TestApp"
                
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
        
        // Select the best window (prefer windows with titles and reasonable size)
        let sortedWindows = windows.sorted { window1, window2 in
            // Prefer windows with titles
            let window1HasTitle = window1.title?.isEmpty == false
            let window2HasTitle = window2.title?.isEmpty == false
            if window1HasTitle != window2HasTitle {
                return window1HasTitle
            }
            
            // Prefer larger windows (more likely to be main window)
            let window1Size = window1.bounds.width * window1.bounds.height
            let window2Size = window2.bounds.width * window2.bounds.height
            return window1Size > window2Size
        }
        
        guard let window = sortedWindows.first else {
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
        
        // Get all elements for dynamic analysis
        let allElements = try await pilot.findElements(in: window.id)
        let rowElements = allElements.filter { element in
            element.role?.rawValue == "Row"
        }
        let imageElements = allElements.filter { element in
            element.role?.rawValue == "Image"
        }
        
        print("🔍 Found \(imageElements.count) image elements:")
        for img in imageElements {
            print("   - Image: value='\(img.description ?? "NO_VALUE")' id='\(img.identifier ?? "NO_ID")' at (\(String(format: "%.1f", img.centerPoint.x)), \(String(format: "%.1f", img.centerPoint.y)))")
        }
        
        print("🔍 Found \(rowElements.count) row elements:")
        for row in rowElements {
            let bounds = row.cgBounds
            print("   - Row: bounds=(\(String(format: "%.0f", bounds.minX)), \(String(format: "%.0f", bounds.minY)), \(String(format: "%.0f", bounds.width))x\(String(format: "%.0f", bounds.height)))")
        }
        
        // Strategy 1: Find target row by position and test type
        let targetRowIndex: Int
        switch testType {
        case .mouseClick:
            targetRowIndex = 0  // First row (mouse/click icon)
        case .keyboard:
            targetRowIndex = 1  // Second row (keyboard icon)
        case .wait:
            targetRowIndex = 2  // Third row (clock icon)
        }
        
        // Strategy 2: Find sidebar rows in left panel (assuming standard layout)
        let sidebarRows = rowElements.filter { row in
            // Sidebar rows are typically in the left portion and have reasonable height
            let bounds = row.cgBounds
            let isInLeftPanel = bounds.minX < window.bounds.midX
            let hasReasonableHeight = bounds.height > 30 && bounds.height < 100
            let hasReasonableWidth = bounds.width > 100
            
            return isInLeftPanel && hasReasonableHeight && hasReasonableWidth
        }.sorted { $0.cgBounds.minY < $1.cgBounds.minY }  // Sort by Y position (top to bottom)
        
        print("🎯 Found \(sidebarRows.count) sidebar rows (sorted by position)")
        for (index, row) in sidebarRows.enumerated() {
            let bounds = row.cgBounds
            print("   Row \(index): bounds=(\(String(format: "%.0f", bounds.minX)), \(String(format: "%.0f", bounds.minY)), \(String(format: "%.0f", bounds.width))x\(String(format: "%.0f", bounds.height)))")
        }
        
        // Strategy 3: Click the appropriate row
        if targetRowIndex < sidebarRows.count {
            let targetRow = sidebarRows[targetRowIndex]
            print("🎯 Clicking target row \(targetRowIndex) for \(testType)")
            
            let result = try await pilot.click(elementID: targetRow.id)
            
            if result.success {
                print("✅ Navigation successful via row \(targetRowIndex) click")
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms for UI update
                try await refreshWindow()
                return
            } else {
                print("⚠️ Row click result was unsuccessful, trying fallback...")
            }
        } else {
            print("⚠️ Not enough sidebar rows found (need \(targetRowIndex + 1), found \(sidebarRows.count))")
        }
        
        // Strategy 4: Fallback - try to find any clickable element in left panel
        print("🔄 Fallback: Looking for any clickable elements in left panel...")
        
        let leftPanelElements = allElements.filter { element in
            let isInLeftPanel = element.centerPoint.x < window.bounds.midX
            let isClickable = element.role?.rawValue == "Row" || 
                             element.role?.rawValue == "Button" || 
                             element.role?.rawValue == "Cell"
            let hasReasonableSize = element.cgBounds.width > 50 && element.cgBounds.height > 20
            
            return isInLeftPanel && isClickable && hasReasonableSize
        }.sorted { $0.cgBounds.minY < $1.cgBounds.minY }
        
        print("🔍 Found \(leftPanelElements.count) clickable elements in left panel")
        
        if targetRowIndex < leftPanelElements.count {
            let fallbackElement = leftPanelElements[targetRowIndex]
            print("🎯 Trying fallback element \(targetRowIndex): \(fallbackElement.role?.rawValue ?? "unknown")")
            
            let result = try await pilot.click(elementID: fallbackElement.id)
            
            if result.success {
                print("✅ Navigation successful via fallback element click")
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms for UI update
                try await refreshWindow()
                return
            }
        }
        
        // Strategy 5: Last resort - try to use image-based navigation by position
        print("🔄 Last resort: Image-based navigation by position...")
        
        // Sort images by Y position to find the right one for our test type
        let sortedImages = imageElements.filter { img in
            img.centerPoint.x < window.bounds.midX  // Left side images only
        }.sorted { $0.centerPoint.y < $1.centerPoint.y }
        
        if targetRowIndex < sortedImages.count {
            let targetImage = sortedImages[targetRowIndex]
            print("🎯 Trying image \(targetRowIndex): value='\(targetImage.description ?? "unknown")'")
            
            let result = try await pilot.click(elementID: targetImage.id)
            
            if result.success {
                print("✅ Navigation successful via image click")
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms for UI update
                try await refreshWindow()
                return
            }
        }
        
        print("❌ All navigation strategies failed")
        throw TestSessionError.navigationFailed
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
        // Try bundle ID first for more reliable detection
        let app = try await findApplication(bundleId: "team.stamp.TestApp")
        
        guard let window = try await findWindow(app: app, index: 0) else {
            throw PilotError.windowNotFound(WindowHandle(id: "not_found"))
        }
        return (app: app, window: window)
    }
}
