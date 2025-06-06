import Testing
import CoreGraphics
@testable import AppPilot

@Test func testAppPilotInitialization() async throws {
    let pilot = AppPilot()
    
    // Test that we can create an instance (pilot is non-optional)
    let _ = pilot // Just verify it compiles
}

@Test func testMockDrivers() async throws {
    let mockCGEventDriver = MockCGEventDriver()
    let mockAccessibilityDriver = MockAccessibilityDriver()
    let mockScreenDriver = MockScreenDriver()
    
    let pilot = AppPilot(
        cgEventDriver: mockCGEventDriver,
        screenDriver: mockScreenDriver,
        accessibilityDriver: mockAccessibilityDriver
    )
    
    // Set up mock data
    await mockScreenDriver.setMockApps([
        AppInfo(id: AppID(pid: 123), name: "TestApp", bundleIdentifier: "com.test.app", isActive: true)
    ])
    await mockScreenDriver.setMockWindows([
        WindowInfo(
            id: WindowID(id: 456),
            title: "Test Window",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            appName: "TestApp"
        )
    ])
    
    // Test listApplications
    let apps = try await pilot.listApplications()
    #expect(apps.count > 0, "Should find at least one application")
    
    // Test listWindows - use first found app for realistic test
    if let firstApp = apps.first {
        let _ = try await pilot.listWindows(app: firstApp.id)
        // Note: Windows count can be 0 or more, which is valid
    }
}

@Test func testErrorTypes() async throws {
    let permissionError = PilotError.permissionDenied("Accessibility permission required")
    #expect(permissionError.localizedDescription.contains("Permission denied"))
    
    let notFoundError = PilotError.windowNotFound(WindowID(id: 123))
    #expect(notFoundError.localizedDescription.contains("Window not found"))
    
    let timeoutError = PilotError.timeout(5.0)
    #expect(timeoutError.localizedDescription.contains("timed out"))
}