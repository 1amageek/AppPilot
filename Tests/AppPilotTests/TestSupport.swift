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
        
        // Map test types to expected image identifiers (from debug output)
        let imageIdentifier: String
        switch testType {
        case .mouseClick:
            imageIdentifier = "cursorarrow.click"
        case .keyboard:
            imageIdentifier = "keyboard"
        case .wait:
            imageIdentifier = "clock"
        }
        
        // Debug: List all elements to understand the structure
        let allElements = try await pilot.findElements(in: window.id)
        let imageElements = allElements.filter { element in
            element.elementRole == .image
        }
        let rowElements = allElements.filter { element in
            element.elementRole == .row
        }
        
        print("🔍 Found \(imageElements.count) image elements:")
        for img in imageElements {
            print("   - Image: value='\(img.value ?? "NO_VALUE")' id='\(img.identifier ?? "NO_ID")' at (\(String(format: "%.1f", img.centerPoint.x)), \(String(format: "%.1f", img.centerPoint.y)))")
        }
        
        print("🔍 Found \(rowElements.count) row elements:")
        for row in rowElements {
            let bounds = row.cgBounds
            print("   - Row: bounds=(\(String(format: "%.0f", bounds.minX)), \(String(format: "%.0f", bounds.minY)), \(String(format: "%.0f", bounds.width))x\(String(format: "%.0f", bounds.height)))")
        }
        
        // Strategy 1: Find the target image by identifier
        var targetIcon: UIElement?
        
        // Find the specific image with matching identifier
        let imagesByIdentifier = imageElements.filter { $0.identifier == imageIdentifier }
        if let foundImage = imagesByIdentifier.first {
            targetIcon = foundImage
            print("🎯 Found target image by identifier: '\(imageIdentifier)' at (\(String(format: "%.1f", foundImage.centerPoint.x)), \(String(format: "%.1f", foundImage.centerPoint.y)))")
        } else {
            print("⚠️ Image with identifier '\(imageIdentifier)' not found")
            
            // Strategy 2: Fallback - try to find by row containing the image
            print("🔄 Trying fallback strategy: search by row...")
            
            // Look for rows that might contain our target
            for row in rowElements {
                // Get all elements within this row's bounds
                let elementsInRow = allElements.filter { element in
                    row.cgBounds.contains(CGPoint(x: element.centerPoint.x, y: element.centerPoint.y))
                }
                
                // Check if any image in this row has our target identifier
                let imagesInRow = elementsInRow.filter { element in
                    element.elementRole == ElementRole.image
                }
                let hasTargetImage = imagesInRow.contains { element in
                    element.identifier == imageIdentifier
                }
                
                if hasTargetImage {
                    print("🎯 Found row containing target image, clicking row instead")
                    let result = try await pilot.click(elementID: row.id)
                    
                    if result.success {
                        print("✅ Navigation successful via row click")
                        try await Task.sleep(nanoseconds: 500_000_000) // 500ms for UI update
                        try await refreshWindow()
                        return
                    }
                }
            }
            
            throw TestSessionError.navigationFailed
        }
        
        // Strategy 3: Click the target image directly
        if let icon = targetIcon {
            print("🔄 Clicking target image directly")
            let result = try await pilot.click(elementID: icon.id)
            
            if result.success {
                print("✅ Navigation successful via direct image click")
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms for UI update
                try await refreshWindow()
            } else {
                print("❌ Direct image click failed, trying parent row")
                
                // Strategy 4: Fallback to parent row click
                print("🔍 Searching for parent row containing the target image...")
                
                for row in rowElements {
                    // Check if the image is within this row's bounds
                    if row.cgBounds.contains(CGPoint(x: icon.centerPoint.x, y: icon.centerPoint.y)) {
                        print("🎯 Found parent row, clicking row as fallback")
                        do {
                            let result = try await pilot.click(elementID: row.id)
                            
                            if result.success {
                                print("✅ Navigation successful via parent row click")
                                try await Task.sleep(nanoseconds: 500_000_000) // 500ms for UI update
                                try await refreshWindow()
                                return
                            }
                        } catch {
                            print("⚠️ Row click failed: \(error)")
                            continue
                        }
                    }
                }
                
                print("❌ All navigation attempts failed")
                throw TestSessionError.navigationFailed
            }
        }
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
