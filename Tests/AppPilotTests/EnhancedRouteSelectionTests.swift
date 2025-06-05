import Testing
import Foundation
@testable import AppPilot

@Suite("Enhanced Route Selection Tests")
struct EnhancedRouteSelectionTests {
    private let config = TestConfiguration(verboseLogging: true)
    
    // MARK: - Route Selection with Call Tracking
    
    @Test("RT-Enhanced-01: Detailed route fallback verification",
          .tags(.integration, .routing, .fallback))
    func testDetailedRouteFallback() async throws {
        let mockAppleEventDriver = MockAppleEventDriver()
        let mockAccessibilityDriver = MockAccessibilityDriver()
        let mockUIEventDriver = MockUIEventDriver()
        
        // Configure failure modes to force fallback
        await mockAppleEventDriver.setSupportedCommands([.click]) // Support click but we'll make it fail
        await mockAccessibilityDriver.setCanPerform(true)
        
        // Set up AppleEvent to fail with timeout
        await mockAccessibilityDriver.setFailureMode(.timeout(after: 0.1))
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: mockUIEventDriver,
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let testWindow = Window(
            id: WindowID(id: 100),
            title: "Test Window",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        // Clear call histories
        await mockAccessibilityDriver.clearHistory()
        await mockUIEventDriver.clearHistory()
        
        // Perform click operation
        let result = try await pilot.click(
            window: testWindow.id,
            at: Point(x: 200, y: 300),
            policy: .STAY_HIDDEN
        )
        
        // Verify that we attempted AX first (which should timeout)
        let axCallHistory = await mockAccessibilityDriver.getCallHistory()
        #expect(axCallHistory.count > 0, "Should have attempted AX operation")
        
        // Verify that we fell back to UI events
        let uiCallHistory = await mockUIEventDriver.getCallHistory()
        #expect(uiCallHistory.count > 0, "Should have fallen back to UI events")
        
        let clickEvents = await mockUIEventDriver.getClickEvents()
        #expect(clickEvents.count == 1, "Should have exactly one click event")
        
        let clickEvent = clickEvents[0]
        #expect(abs(clickEvent.point.x - 300) < 1.0, "Click X coordinate should be converted to screen coordinates")
        #expect(abs(clickEvent.point.y - 400) < 1.0, "Click Y coordinate should be converted to screen coordinates")
        
        #expect(result.route == .UI_EVENT, "Should have fallen back to UI_EVENT route")
        #expect(result.success, "Click should succeed via UI_EVENT fallback")
    }
    
    
    @Test("RT-Enhanced-03: Performance impact measurement",
          .tags(.performance, .routing))
    func testRouteSelectionPerformanceImpact() async throws {
        let mockAppleEventDriver = MockAppleEventDriver()
        let mockUIEventDriver = MockUIEventDriver()
        
        await mockAppleEventDriver.setSupportedCommands([.click])
        await mockUIEventDriver.setFailureMode(.simulateDelay(duration: 0.01)) // 10ms delay for UI events
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: MockAccessibilityDriver(),
            uiEventDriver: mockUIEventDriver,
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let testWindow = Window(
            id: WindowID(id: 100),
            title: "Performance Test",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        // Measure AppleEvent performance
        let appleEventStartTime = Date()
        let appleEventResult = try await pilot.click(
            window: testWindow.id,
            at: Point(x: 100, y: 100),
            policy: .STAY_HIDDEN,
            route: .APPLE_EVENT // Force AppleEvent route
        )
        let appleEventDuration = Date().timeIntervalSince(appleEventStartTime)
        
        await mockUIEventDriver.clearHistory()
        
        // Measure UI Event performance (with simulated delay)
        let uiEventStartTime = Date()
        let uiEventResult = try await pilot.click(
            window: testWindow.id,
            at: Point(x: 100, y: 100),
            policy: .STAY_HIDDEN,
            route: .UI_EVENT // Force UI Event route
        )
        let uiEventDuration = Date().timeIntervalSince(uiEventStartTime)
        
        #expect(appleEventResult.route == .APPLE_EVENT, "Should use AppleEvent route when forced")
        #expect(uiEventResult.route == .UI_EVENT, "Should use UI Event route when forced")
        
        // UI Event should be slower due to simulated delay
        #expect(uiEventDuration > appleEventDuration, "UI Event should be slower than AppleEvent")
        #expect(uiEventDuration >= 0.01, "UI Event should include simulated delay")
        
        // Get detailed timing stats from mock driver
        let timingStats = await mockUIEventDriver.getTimingStats()
        #expect(timingStats.count == 1, "Should have one UI event timing record")
        #expect(timingStats.average >= 0.01, "Average timing should include delay")
        
        print("AppleEvent duration: \\(String(format: \"%.3f\", appleEventDuration * 1000))ms")
        print("UI Event duration: \\(String(format: \"%.3f\", uiEventDuration * 1000))ms")
        print("UI Event timing stats: avg=\\(String(format: \"%.3f\", timingStats.average * 1000))ms, count=\\(timingStats.count)")
    }
    
    @Test("RT-Enhanced-04: Route selection with multiple failures",
          .tags(.integration, .routing, .errorHandling))
    func testMultipleRouteFailures() async throws {
        let mockAppleEventDriver = MockAppleEventDriver()
        let mockAccessibilityDriver = MockAccessibilityDriver()
        let mockUIEventDriver = MockUIEventDriver()
        
        // Configure all routes to fail initially, except UI Event
        await mockAppleEventDriver.setSupportedCommands([]) // No AppleEvent support
        await mockAccessibilityDriver.setCanPerform(false) // No AX support
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: mockUIEventDriver,
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let testWindow = Window(
            id: WindowID(id: 100),
            title: "Fallback Test",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        // Clear all call histories
        await mockAccessibilityDriver.clearHistory()
        await mockUIEventDriver.clearHistory()
        
        // Attempt click - should fall through to UI Event
        let result = try await pilot.click(
            window: testWindow.id,
            at: Point(x: 50, y: 75),
            policy: .STAY_HIDDEN
        )
        
        // Verify the route selection process
        let axCalls = await mockAccessibilityDriver.getCallCount(for: "canPerform")
        let uiCalls = await mockUIEventDriver.getCallCount(for: "click")
        
        #expect(axCalls > 0, "Should have checked AX capability")
        #expect(uiCalls == 1, "Should have made exactly one UI click call")
        
        #expect(result.route == .UI_EVENT, "Should have used UI_EVENT as final fallback")
        #expect(result.success, "Click should succeed via UI_EVENT")
        
        // Verify click coordinates were properly converted
        let clickEvents = await mockUIEventDriver.getClickEvents()
        #expect(clickEvents.count == 1, "Should have one click event")
        
        let clickEvent = clickEvents[0]
        #expect(abs(clickEvent.point.x - 150) < 1.0, "Screen X should be window.x + point.x")
        #expect(abs(clickEvent.point.y - 175) < 1.0, "Screen Y should be window.y + point.y")
    }
    
    @Test("RT-Enhanced-05: Concurrent route selection",
          .tags(.integration, .routing, .concurrency))
    func testConcurrentRouteSelection() async throws {
        let mockAppleEventDriver = MockAppleEventDriver()
        let mockAccessibilityDriver = MockAccessibilityDriver()
        let mockUIEventDriver = MockUIEventDriver()
        
        await mockAppleEventDriver.setSupportedCommands([.click])
        await mockAccessibilityDriver.setCanPerform(true)
        
        let pilot = AppPilot(
            appleEventDriver: mockAppleEventDriver,
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: mockUIEventDriver,
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let testWindow = Window(
            id: WindowID(id: 100),
            title: "Concurrent Test",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        // Clear call histories
        await mockAppleEventDriver.clearHistory()
        await mockAccessibilityDriver.clearHistory()
        await mockUIEventDriver.clearHistory()
        
        // Perform multiple concurrent operations
        let clickTasks = (0..<5).map { i in
            Task {
                return try await pilot.click(
                    window: testWindow.id,
                    at: Point(x: Double(i * 10), y: Double(i * 10)),
                    policy: .STAY_HIDDEN
                )
            }
        }
        
        let results = try await withThrowingTaskGroup(of: ActionResult.self) { group in
            for task in clickTasks {
                group.addTask { try await task.value }
            }
            
            var allResults: [ActionResult] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        #expect(results.count == 5, "Should have 5 results")
        #expect(results.allSatisfy { $0.success }, "All operations should succeed")
        
        // All should use the same route (AppleEvent, since it's available and highest priority)
        #expect(results.allSatisfy { $0.route == .APPLE_EVENT }, "All should use APPLE_EVENT route")
        
        // Verify call counts
        let appleEventCalls = await mockAppleEventDriver.getCallHistory()
        #expect(appleEventCalls.count == 5, "Should have 5 AppleEvent calls")
        
        // Verify that operations were properly isolated
        // Note: Call history doesn't include timestamps, but we can verify concurrent execution succeeded
        #expect(appleEventCalls.allSatisfy { $0.contains("send(") }, "All calls should be send operations")
    }
    
}
