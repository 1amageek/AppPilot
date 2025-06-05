import Testing
import CoreGraphics
@testable import AppPilot

@Test func testAppPilotInitialization() async throws {
        let pilot = AppPilot()
        
        // Test that we can create an instance (pilot is non-optional)
        let _ = pilot // Just verify it compiles
}


@Test func testMockDrivers() async throws {
    let mockAppleEventDriver = MockAppleEventDriver()
    let mockAccessibilityDriver = MockAccessibilityDriver()
    let mockUIEventDriver = MockUIEventDriver()
    let mockScreenDriver = MockScreenDriver()
    let mockMissionControlDriver = MockMissionControlDriver()
    
    let pilot = AppPilot(
        appleEventDriver: mockAppleEventDriver,
        accessibilityDriver: mockAccessibilityDriver,
        uiEventDriver: mockUIEventDriver,
        screenDriver: mockScreenDriver,
        missionControlDriver: mockMissionControlDriver
    )
    
    // Set up mock data
    let app = App(id: AppID(pid: 123), name: "TestApp", bundleIdentifier: "com.test.app")
    let window = Window(
        id: WindowID(id: 456),
        title: "Test Window",
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        isMinimized: false,
        app: app.id
    )
    
    await mockScreenDriver.setMockApps([app])
    await mockScreenDriver.setMockWindows([window])
    
    // Test listApplications
    let apps = try await pilot.listApplications()
    #expect(apps.count == 1)
    #expect(apps[0].name == "TestApp")
    
    // Test listWindows
    let windows = try await pilot.listWindows(in: app.id)
    #expect(windows.count == 1)
    #expect(windows[0].title == "Test Window")
}

@Test func testErrorTypes() async throws {
    let permissionError = PilotError.PERMISSION_DENIED(.accessibility)
    #expect(permissionError.errorDescription == "Permission denied: Accessibility permission required")
    
    let notFoundError = PilotError.NOT_FOUND(.window, "Window 123")
    #expect(notFoundError.errorDescription == "Window not found: Window 123")
    
    let timeoutError = PilotError.TIMEOUT(ms: 5000)
    #expect(timeoutError.errorDescription == "Operation timed out after 5000ms")
}
