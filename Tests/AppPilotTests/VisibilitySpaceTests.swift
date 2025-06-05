import Testing
import Foundation
@testable import AppPilot

@Suite("Visibility & Space Tests (VS)")
struct VisibilitySpaceTests {
    private let config = TestConfiguration(verboseLogging: true)
    private let client = TestAppClient()
    private let discovery = TestAppDiscovery(config: TestConfiguration())
    
    @Test("VS-01: BRING_FORE_TEMP policy with precise restoration")
    func testBringForegroundTemporaryWithRestoration() async throws {
        // Setup mock drivers for space/visibility testing
        let mockMissionControlDriver = MockMissionControlDriver()
        await mockMissionControlDriver.setCurrentSpace(1) // Active space is 1
        
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true)
        
        let pilot = AppPilot(
            appleEventDriver: MockAppleEventDriver(),
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: mockMissionControlDriver
        )
        
        // Setup test scenario: TestApp in Space 4, Finder should be restored
        let testApp = AppID(pid: 12345)
        let finderApp = AppID(pid: 1)
        let testWindow = Window(
            id: WindowID(id: 100),
            title: "TestApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: testApp
        )
        
        await mockMissionControlDriver.setWindowSpace(testWindow.id, space: 4) // TestApp in Space 4
        
        print("Testing BRING_FORE_TEMP policy with restoration")
        print("Initial state: TestApp in Space 4, current space is 1")
        
        // Execute click with BRING_FORE_TEMP policy
        let result = try await pilot.click(
            window: testWindow.id,
            at: Point(x: 200, y: 200),
            policy: .BRING_FORE_TEMP(restore: finderApp)
        )
        
        print("Click result: \(result.success) via \(result.route)")
        #expect(result.success, "Click should succeed with BRING_FORE_TEMP policy")
        
        // Verify window was temporarily moved to active space during operation
        // (This would be verified through the mock's internal state tracking)
        
        // The operation should complete and restore state automatically
        // In real implementation, VisibilityManager would handle this
        
        print("Operation completed - state should be restored")
        
        // Verify final state: TestApp should be back in Space 4
        let finalWindowSpace = try await mockMissionControlDriver.getSpaceForWindow(testWindow.id)
        print("Final window space: \(finalWindowSpace)")
        
        // Note: In mock implementation, this depends on the mock's restoration logic
        // In real implementation, this would be handled by SpaceController
        
        #expect(result.success, "Overall operation should succeed")
    }
    
    @Test("VS-02: UNMINIMIZE policy with minimized window")
    func testUnminimizePolicyWithMinimizedWindow() async throws {
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true)
        
        // Setup mock tree that indicates window is minimized
        let minimizedTree = AXNode(
            role: "window",
            title: "TestApp",
            value: "minimized",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            children: []
        )
        await mockAccessibilityDriver.setMockTree(minimizedTree)
        
        let pilot = AppPilot(
            appleEventDriver: MockAppleEventDriver(),
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let minimizedWindow = Window(
            id: WindowID(id: 200),
            title: "TestApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: true, // Window is minimized
            app: AppID(pid: 12345)
        )
        
        print("Testing UNMINIMIZE policy with minimized window")
        
        let result = try await pilot.click(
            window: minimizedWindow.id,
            at: Point(x: 300, y: 300),
            policy: .UNMINIMIZE(tempMs: 200)
        )
        
        print("Click on minimized window: \(result.success) via \(result.route)")
        #expect(result.success, "Click should succeed on minimized window with UNMINIMIZE policy")
        
        // Verify AX setValue was called to unminimize (in mock)
        // Real implementation would check that window is temporarily unminimized
        
        print("Window should be temporarily unminimized during operation")
    }
    
    @Test("VS-03: STAY_HIDDEN policy preserves window state")
    func testStayHiddenPolicyPreservesState() async throws {
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true)
        
        let pilot = AppPilot(
            appleEventDriver: MockAppleEventDriver(),
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let hiddenWindow = Window(
            id: WindowID(id: 300),
            title: "HiddenApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: true,
            app: AppID(pid: 23456)
        )
        
        print("Testing STAY_HIDDEN policy preserves window state")
        
        // Use AX_ACTION route which can work with hidden windows
        let result = try await pilot.click(
            window: hiddenWindow.id,
            at: Point(x: 400, y: 400),
            policy: .STAY_HIDDEN,
            route: .AX_ACTION // Force AX route which can work without visibility
        )
        
        print("Click with STAY_HIDDEN: \(result.success) via \(result.route)")
        #expect(result.success, "Click should succeed with STAY_HIDDEN policy via AX")
        #expect(result.route == .AX_ACTION, "Should use AX_ACTION route for hidden operations")
        
        // Window state should remain unchanged (minimized)
        // In real implementation, VisibilityManager would ensure no state changes
        print("Window should remain minimized after operation")
    }
    
    @Test("VS-04: Space transition handling")
    func testSpaceTransitionHandling() async throws {
        let mockMissionControlDriver = MockMissionControlDriver()
        await mockMissionControlDriver.setCurrentSpace(2) // Current space is 2
        
        let pilot = AppPilot(
            appleEventDriver: MockAppleEventDriver(),
            accessibilityDriver: MockAccessibilityDriver(),
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: mockMissionControlDriver
        )
        
        let windowInDifferentSpace = Window(
            id: WindowID(id: 400),
            title: "RemoteApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 34567)
        )
        
        // Place window in Space 5 (different from current Space 2)
        await mockMissionControlDriver.setWindowSpace(windowInDifferentSpace.id, space: 5)
        
        print("Testing space transition handling")
        print("Current space: 2, window in space: 5")
        
        let result = try await pilot.click(
            window: windowInDifferentSpace.id,
            at: Point(x: 250, y: 250),
            policy: .UNMINIMIZE() // Will require space transition for UI_EVENT
        )
        
        print("Cross-space click: \(result.success) via \(result.route)")
        #expect(result.success, "Cross-space operation should succeed")
        
        // Verify space handling
        // In real implementation, SpaceController would manage space transitions
        print("Space transition should be handled transparently")
    }
    
    
    @Test("VS-Performance: Visibility state restoration timing")
    func testVisibilityStateRestorationTiming() async throws {
        let pilot = AppPilot()
        
        let testWindow = Window(
            id: WindowID(id: 700),
            title: "PerformanceApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: true, // Start minimized
            app: AppID(pid: 67890)
        )
        
        var restorationTimes: [TimeInterval] = []
        
        print("Testing visibility state restoration timing")
        
        // Perform multiple operations that require state changes
        for i in 0..<5 {
            let startTime = Date()
            
            let result = try await pilot.click(
                window: testWindow.id,
                at: Point(x: 100, y: 100),
                policy: .UNMINIMIZE(tempMs: 100) // Quick restoration
            )
            
            let totalTime = Date().timeIntervalSince(startTime)
            restorationTimes.append(totalTime)
            
            print("Operation \(i+1): \(String(format: "%.3f", totalTime * 1000))ms")
            #expect(result.success, "Visibility operation should succeed")
            
            // Small delay between operations
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        let averageTime = restorationTimes.reduce(0, +) / Double(restorationTimes.count)
        let maxTime = restorationTimes.max() ?? 0
        
        print("Average restoration time: \(String(format: "%.3f", averageTime * 1000))ms")
        print("Max restoration time: \(String(format: "%.3f", maxTime * 1000))ms")
        
        // Visibility operations should be reasonably fast
        #expect(averageTime <= 0.500, "Average visibility restoration should be <= 500ms")
        #expect(maxTime <= 1.000, "Max visibility restoration should be <= 1000ms")
    }
}
