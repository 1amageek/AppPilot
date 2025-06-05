import Testing
import Foundation
@testable import AppPilot

@Suite("Route Selection Tests (RT)")
struct RouteSelectionTests {
    private let config = TestConfiguration(verboseLogging: true)
    
    @Test("RT-01: AppleScriptable app should use APPLE_EVENT route")
    func testAppleScriptableAppRouteSelection() async throws {
        // Setup mock drivers for AppleScriptable scenario
        let mockAppleEventDriver = MockAppleEventDriver()
        await mockAppleEventDriver.setSupportedCommands([.click, .type]) // Enable AppleEvent support
        
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true) // AX also available
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let mockWindow = Window(
            id: WindowID(id: 100),
            title: "ScriptableApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        print("Testing route selection for AppleScriptable app")
        
        // Test click command - should prefer AppleEvent
        let clickResult = try await pilot.click(
            window: mockWindow.id,
            at: Point(x: 100, y: 100),
            policy: .STAY_HIDDEN
        )
        
        print("Click route: \(clickResult.route)")
        #expect(clickResult.route == .APPLE_EVENT, "AppleScriptable app should use APPLE_EVENT route for clicks")
        #expect(clickResult.success, "Click should succeed via AppleEvent")
        
        // Verify AppleEvent was actually sent
        let sentEvents = await mockAppleEventDriver.getSentEvents()
        #expect(!sentEvents.isEmpty, "AppleEvent should have been sent")
        
        // Test type command - should also prefer AppleEvent if supported
        let typeResult = try await pilot.type(
            text: "AppleEvent Test",
            into: mockWindow.id,
            policy: .STAY_HIDDEN
        )
        
        print("Type route: \(typeResult.route)")
        #expect(typeResult.route == .APPLE_EVENT, "AppleScriptable app should use APPLE_EVENT route for typing")
        #expect(typeResult.success, "Type should succeed via AppleEvent")
    }
    
    @Test("RT-02: Non-scriptable app with AX should use AX_ACTION route")
    func testNonScriptableAppWithAXRouteSelection() async throws {
        // Setup mock drivers for non-scriptable app with AX
        let mockAppleEventDriver = MockAppleEventDriver()
        await mockAppleEventDriver.setSupportedCommands([]) // Disable AppleEvent support
        
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true) // Enable AX
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let mockWindow = Window(
            id: WindowID(id: 200),
            title: "StandardApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 23456)
        )
        
        print("Testing route selection for non-scriptable app with AX support")
        
        // Test click command - should use AX_ACTION
        let clickResult = try await pilot.click(
            window: mockWindow.id,
            at: Point(x: 150, y: 150),
            policy: .STAY_HIDDEN
        )
        
        print("Click route: \(clickResult.route)")
        #expect(clickResult.route == .AX_ACTION, "Non-scriptable app with AX should use AX_ACTION route")
        #expect(clickResult.success, "Click should succeed via AX")
        
        // Verify AX action was performed
        let performedActions = await mockAccessibilityDriver.getPerformedActions()
        #expect(!performedActions.isEmpty, "AX action should have been performed")
        
        // Test type command - should also use AX_ACTION
        let typeResult = try await pilot.type(
            text: "AX Test",
            into: mockWindow.id,
            policy: .STAY_HIDDEN
        )
        
        print("Type route: \(typeResult.route)")
        #expect(typeResult.route == .AX_ACTION, "Non-scriptable app with AX should use AX_ACTION route for typing")
        #expect(typeResult.success, "Type should succeed via AX")
    }
    
    @Test("RT-03: Gesture commands always use UI_EVENT route")
    func testGestureAlwaysUsesUIEventRoute() async throws {
        // Setup mock drivers - all available
        let mockAppleEventDriver = MockAppleEventDriver()
        await mockAppleEventDriver.setSupportedCommands([.click, .type, .gesture]) // Even if AppleEvent "supports" gestures
        
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true)
        
        let mockUIEventDriver = MockUIEventDriver()
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: mockUIEventDriver,
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let mockWindow = Window(
            id: WindowID(id: 300),
            title: "GestureApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 34567)
        )
        
        print("Testing route selection for gesture commands")
        
        // Test various gesture types
        let gestures: [(Gesture, String)] = [
            (.scroll(dx: 0, dy: -100), "scroll"),
            (.pinch(scale: 1.5, center: Point(x: 200, y: 200)), "pinch"),
            (.rotate(degrees: 45, center: Point(x: 200, y: 200)), "rotate"),
            (.drag(from: Point(x: 100, y: 100), to: Point(x: 200, y: 200)), "drag"),
            (.swipe(direction: .up, distance: 100), "swipe")
        ]
        
        for (gesture, gestureName) in gestures {
            print("Testing \(gestureName) gesture")
            
            let gestureResult = try await pilot.gesture(
                window: mockWindow.id,
                gesture,
                policy: .UNMINIMIZE()
            )
            
            print("\(gestureName) route: \(gestureResult.route)")
            #expect(gestureResult.route == .UI_EVENT, "\(gestureName) gesture should always use UI_EVENT route")
            #expect(gestureResult.success, "\(gestureName) gesture should succeed")
        }
        
        // Verify UI events were generated
        let gestureEvents = await mockUIEventDriver.getGestureEvents()
        #expect(gestureEvents.count == gestures.count, "All gestures should generate UI events")
    }
    
    @Test("RT-04: Route fallback behavior")
    func testRouteFallbackBehavior() async throws {
        // Test the fallback chain: AppleEvent → AX_ACTION → UI_EVENT
        
        print("Testing route fallback behavior")
        
        // Setup 1: All methods fail except UI_EVENT
        let mockAppleEventDriver = MockAppleEventDriver()
        await mockAppleEventDriver.setSupportedCommands([]) // AppleEvent not supported
        
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(false) // AX not available
        
        let mockUIEventDriver = MockUIEventDriver() // UI_EVENT available as last resort
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: mockUIEventDriver,
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let mockWindow = Window(
            id: WindowID(id: 400),
            title: "FallbackApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 45678)
        )
        
        // Test click fallback to UI_EVENT
        let clickResult = try await pilot.click(
            window: mockWindow.id,
            at: Point(x: 100, y: 100),
            policy: .UNMINIMIZE() // Required for UI_EVENT
        )
        
        print("Fallback click route: \(clickResult.route)")
        #expect(clickResult.route == .UI_EVENT, "Should fallback to UI_EVENT when other routes unavailable")
        #expect(clickResult.success, "Click should succeed via UI_EVENT fallback")
        
        // Verify UI event was generated
        let clickEvents = await mockUIEventDriver.getClickEvents()
        #expect(!clickEvents.isEmpty, "UI click event should have been generated")
    }
    
    
    @Test("RT-06: Route selection performance")
    func testRouteSelectionPerformance() async throws {
        let pilot = AppPilot()
        
        let mockWindow = Window(
            id: WindowID(id: 600),
            title: "PerformanceApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 67890)
        )
        
        var routeSelectionTimes: [TimeInterval] = []
        
        print("Testing route selection performance")
        
        // Perform multiple operations to measure route selection overhead
        for i in 0..<20 {
            let startTime = Date()
            
            _ = try await pilot.click(
                window: mockWindow.id,
                at: Point(x: Double(100 + i * 10), y: 100),
                policy: .STAY_HIDDEN
            )
            
            let totalTime = Date().timeIntervalSince(startTime)
            routeSelectionTimes.append(totalTime)
            
            if config.verboseLogging && i < 5 {
                print("Operation \(i+1): \(String(format: "%.3f", totalTime * 1000))ms")
            }
        }
        
        let averageTime = routeSelectionTimes.reduce(0, +) / Double(routeSelectionTimes.count)
        let maxTime = routeSelectionTimes.max() ?? 0
        
        print("Average operation time: \(String(format: "%.3f", averageTime * 1000))ms")
        print("Max operation time: \(String(format: "%.3f", maxTime * 1000))ms")
        
        // Route selection should not add significant overhead
        #expect(averageTime <= 0.015, "Average operation time should be <= 15ms")
        #expect(maxTime <= 0.025, "Max operation time should be <= 25ms")
    }
}
