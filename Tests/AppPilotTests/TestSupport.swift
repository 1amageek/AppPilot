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
