import Foundation
import ApplicationServices

public actor TestAppDiscovery {
    private let config: TestConfiguration
    
    public init(config: TestConfiguration) {
        self.config = config
    }
    
    // MARK: - App Discovery
    
    public func findTestApp() async throws -> App {
        let apps = try await listAllApplications()
        
        // Try to find by bundle ID first
        if let app = apps.first(where: { $0.bundleIdentifier == config.testAppBundleID }) {
            return app
        }
        
        // Fallback to finding by name
        if let app = apps.first(where: { $0.name.contains("TestApp") || $0.name.contains("AppMCP") }) {
            return app
        }
        
        throw TestAppDiscoveryError.testAppNotFound
    }
    
    public func findTestAppWindow() async throws -> Window {
        let app = try await findTestApp()
        let windows = try await listWindows(for: app.id)
        
        // Look for main TestApp window
        if let window = windows.first(where: { window in
            window.title?.contains("TestApp") == true || 
            window.title?.contains("AppMCP") == true ||
            window.title?.contains("Test App") == true
        }) {
            return window
        }
        
        // Fallback to first non-minimized window
        if let window = windows.first(where: { !$0.isMinimized }) {
            return window
        }
        
        // Last resort: any window
        if let window = windows.first {
            return window
        }
        
        throw TestAppDiscoveryError.testAppWindowNotFound
    }
    
    public func waitForTestApp(timeout: TimeInterval = 30.0) async throws -> App {
        let endTime = Date().addingTimeInterval(timeout)
        
        while Date() < endTime {
            do {
                return try await findTestApp()
            } catch {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        throw TestAppDiscoveryError.testAppNotFoundTimeout
    }
    
    public func waitForTestAppWindow(timeout: TimeInterval = 30.0) async throws -> Window {
        let endTime = Date().addingTimeInterval(timeout)
        
        while Date() < endTime {
            do {
                return try await findTestAppWindow()
            } catch {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        throw TestAppDiscoveryError.testAppWindowNotFoundTimeout
    }
    
    // MARK: - App State Verification
    
    public func verifyTestAppReadiness() async throws -> TestAppReadinessInfo {
        let app = try await findTestApp()
        let window = try await findTestAppWindow()
        
        // Check if TestApp API is responding
        let client = TestAppClient(baseURL: config.testAppAPIURL)
        let isAPIHealthy = try await client.healthCheck()
        
        // Get initial state
        let state = isAPIHealthy ? try await client.getState() : nil
        
        return TestAppReadinessInfo(
            app: app,
            window: window,
            isAPIHealthy: isAPIHealthy,
            initialState: state
        )
    }
    
    public func ensureTestAppInForeground() async throws -> Window {
        let window = try await findTestAppWindow()
        
        // If minimized, unminimize it
        if window.isMinimized {
            // This would be handled by VisibilityManager in real implementation
            if config.verboseLogging {
                print("⚠️ TestApp window is minimized - may need manual unminimization")
            }
        }
        
        // Bring to front (this would use actual app activation in real implementation)
        if config.verboseLogging {
            print("✓ TestApp window located: \(window.title ?? "Untitled")")
        }
        
        return window
    }
    
    // MARK: - Helper Methods (Real implementations)
    
    private func listAllApplications() async throws -> [App] {
        // Use real ScreenDriver to get actual running applications
        let screenDriver = DefaultScreenDriver()
        return try await screenDriver.listApplications()
    }
    
    private func listWindows(for appID: AppID) async throws -> [Window] {
        // Use real ScreenDriver to get actual windows
        let screenDriver = DefaultScreenDriver()
        let allWindows = try await screenDriver.listWindows()
        
        // Filter windows by app ID
        return allWindows.filter { $0.app.pid == appID.pid }
    }
}

// MARK: - Data Structures

public struct TestAppReadinessInfo: Sendable {
    public let app: App
    public let window: Window
    public let isAPIHealthy: Bool
    public let initialState: TestAppState?
    
    public var isReady: Bool {
        return isAPIHealthy && initialState != nil
    }
}

// MARK: - Error Types

public enum TestAppDiscoveryError: Error, LocalizedError {
    case testAppNotFound
    case testAppWindowNotFound
    case testAppNotFoundTimeout
    case testAppWindowNotFoundTimeout
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .testAppNotFound:
            return "TestApp not found - make sure it's running"
        case .testAppWindowNotFound:
            return "TestApp window not found"
        case .testAppNotFoundTimeout:
            return "Timeout waiting for TestApp to launch"
        case .testAppWindowNotFoundTimeout:
            return "Timeout waiting for TestApp window"
        case .permissionDenied:
            return "Permission denied - enable Accessibility permissions"
        }
    }
}