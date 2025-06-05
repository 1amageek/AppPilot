import Testing
import Foundation
@testable import AppPilot

@Suite("Click Target Tests (CT)")
struct ClickTargetTests {
    private let config = TestConfiguration(verboseLogging: false)
    private let client = TestAppClient()
    private let discovery = TestAppDiscovery(config: TestConfiguration())
    
    @Test("CT-01: Click targets with UNMINIMIZE policy",
        .tags(.integration))
    func testClickTargetsWithUnminimizePolicy() async throws {
        // 1. Prerequisites validation
        let isHealthy = try await client.healthCheck()
        #expect(isHealthy, "TestApp API must be healthy")
        
        try await client.resetState()
        let sessionId = try await client.startSession()
        #expect(!sessionId.isEmpty, "Session ID should not be empty")
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        #expect(readinessInfo.isReady, "TestApp must be ready for testing")
        
        let testWindow = readinessInfo.window
        #expect(testWindow.id.id > 0, "Window ID must be valid")
        
        // 2. Get and validate initial targets
        let initialTargets = try await client.getClickTargets()
        #expect(!initialTargets.isEmpty, "At least one click target must be available")
        #expect(initialTargets.count >= 3, "Should have at least 3 targets for meaningful test")
        
        // Validate all targets are initially unclicked
        for target in initialTargets {
            #expect(!target.isClicked, "Target \(target.id) should start unclicked")
            #expect(target.position.x >= 0 && target.position.y >= 0, "Target position should be valid")
        }
        
        // 3. Initialize AppPilot
        let pilot = AppPilot()
        
        // 4. Execute clicks and validate results
        var results: [ClickTestResult] = []
        
        for target in initialTargets {
            let startTime = Date()
            
            // Execute click operation
            let actionResult = try await pilot.click(
                window: testWindow.id,
                at: Point(x: target.position.x, y: target.position.y),
                button: .left,
                count: 1,
                policy: .UNMINIMIZE(),
                route: nil
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Validate basic action result
            #expect(actionResult.success, "Click action should succeed for target \(target.id)")
            #expect([Route.APPLE_EVENT, Route.AX_ACTION, Route.UI_EVENT].contains(actionResult.route), 
                   "Route should be one of the valid routes")
            #expect(duration < 5.0, "Click should complete within 5 seconds")
            
            // Wait for UI update and TestApp state synchronization
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Verify target state changed
            let isClicked = try await client.validateClickTarget(id: target.id)
            #expect(isClicked, "Target \(target.id) should be marked as clicked after operation")
            
            let result = ClickTestResult(
                targetId: target.id,
                targetLabel: target.label,
                success: actionResult.success && isClicked,
                route: actionResult.route,
                duration: duration
            )
            results.append(result)
            
            // Small delay between clicks
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        // 5. Validate overall results
        let successfulResults = results.filter { $0.success }
        let successRate = Double(successfulResults.count) / Double(results.count)
        
        #expect(successRate >= config.successRateThreshold, 
               "Success rate (\(String(format: "%.1f", successRate * 100))%) must meet threshold (\(String(format: "%.1f", config.successRateThreshold * 100))%)")
        
        // 6. Validate performance
        let averageResponseTime = results.map { $0.duration }.reduce(0, +) / Double(results.count)
        #expect(averageResponseTime <= 2.0, "Average response time should be under 2 seconds")
        
        // 7. Validate route distribution
        let usedRoutes = Set(successfulResults.map { $0.route })
        #expect(!usedRoutes.isEmpty, "At least one routing strategy should be used")
        
        // 8. End session and validate final state
        let session = try await client.endSession()
        #expect(session.successRate >= config.successRateThreshold, 
               "Session success rate should meet threshold")
        #expect(session.totalTests == initialTargets.count, 
               "Session should record all test operations")
    }
    
    @Test("CT-02: Click targets with AX_ACTION route",
        .tags(.integration))
    func testClickTargetsWithAXRoute() async throws {
        // Setup
        #expect(try await client.healthCheck(), "API must be healthy")
        try await client.resetState()
        _ = try await client.startSession()
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        #expect(readinessInfo.isReady, "TestApp must be ready")
        
        let targets = try await client.getClickTargets()
        #expect(!targets.isEmpty, "Targets must be available")
        
        let pilot = AppPilot()
        let firstTarget = targets[0]
        
        // Test AX route specifically
        let result = try await pilot.click(
            window: readinessInfo.window.id,
            at: Point(x: firstTarget.position.x, y: firstTarget.position.y),
            policy: .UNMINIMIZE(),
            route: .AX_ACTION
        )
        
        #expect(result.success, "AX route click should succeed")
        #expect(result.route == .AX_ACTION, "Should use AX_ACTION route")
        
        // Verify target was clicked
        try await Task.sleep(nanoseconds: 500_000_000)
        let isClicked = try await client.validateClickTarget(id: firstTarget.id)
        #expect(isClicked, "Target should be clicked via AX route")
        
        _ = try await client.endSession()
    }
    
    @Test("CT-03: Click targets with UI_EVENT route",
        .tags(.integration))
    func testClickTargetsWithUIEventRoute() async throws {
        // Setup
        #expect(try await client.healthCheck(), "API must be healthy")
        try await client.resetState()
        _ = try await client.startSession()
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        #expect(readinessInfo.isReady, "TestApp must be ready")
        
        let targets = try await client.getClickTargets()
        #expect(targets.count >= 2, "Need at least 2 targets")
        
        let pilot = AppPilot()
        let secondTarget = targets[1]
        
        // Test UI Event route specifically
        let result = try await pilot.click(
            window: readinessInfo.window.id,
            at: Point(x: secondTarget.position.x, y: secondTarget.position.y),
            policy: .UNMINIMIZE(),
            route: .UI_EVENT
        )
        
        #expect(result.success, "UI Event route click should succeed")
        #expect(result.route == .UI_EVENT, "Should use UI_EVENT route")
        
        // Verify target was clicked
        try await Task.sleep(nanoseconds: 500_000_000)
        let isClicked = try await client.validateClickTarget(id: secondTarget.id)
        #expect(isClicked, "Target should be clicked via UI Event route")
        
        _ = try await client.endSession()
    }
    
    @Test("CT-04: Performance validation - response time under 2s",
        .tags(.performance))
    func testClickPerformance() async throws {
        // Setup
        #expect(try await client.healthCheck(), "API must be healthy")
        try await client.resetState()
        _ = try await client.startSession()
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        #expect(readinessInfo.isReady, "TestApp must be ready")
        
        let targets = try await client.getClickTargets()
        #expect(!targets.isEmpty, "Targets must be available")
        
        let pilot = AppPilot()
        let target = targets[0]
        
        // Measure click performance
        let startTime = Date()
        let result = try await pilot.click(
            window: readinessInfo.window.id,
            at: Point(x: target.position.x, y: target.position.y),
            policy: .UNMINIMIZE()
        )
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(result.success, "Click should succeed")
        #expect(duration < 2.0, "Click should complete within 2 seconds, actual: \(duration)s")
        #expect(duration > 0.001, "Click should take measurable time")
        
        _ = try await client.endSession()
    }
    
    @Test("CT-Debug: Individual target test")
    func testIndividualTarget() async throws {
        // Debug version with more information
        let isHealthy = try await client.healthCheck()
        #expect(isHealthy, "API must be healthy")
        
        try await client.resetState()
        let sessionId = try await client.startSession()
        #expect(!sessionId.isEmpty, "Session should start successfully")
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        #expect(readinessInfo.isReady, "TestApp must be ready")
        
        let targets = try await client.getClickTargets()
        #expect(!targets.isEmpty, "At least one target must be available")
        
        let firstTarget = targets[0]
        print("🎯 Target: \(firstTarget.label) at (\(firstTarget.position.x), \(firstTarget.position.y))")
        print("🪟 Window: \(readinessInfo.window.title ?? "Untitled") ID: \(readinessInfo.window.id.id)")
        print("📏 Window frame: \(readinessInfo.window.frame)")
        
        let pilot = AppPilot()
        
        // Test with different coordinates to see what works
        let testCoordinates = [
            Point(x: firstTarget.position.x, y: firstTarget.position.y), // Original
            Point(x: 100, y: 100), // Fixed position
            Point(x: firstTarget.position.x + readinessInfo.window.frame.origin.x, 
                  y: firstTarget.position.y + readinessInfo.window.frame.origin.y), // Screen coordinates
        ]
        
        for (index, testPoint) in testCoordinates.enumerated() {
            print("🧪 Testing coordinate set \(index + 1): (\(testPoint.x), \(testPoint.y))")
            
            let result = try await pilot.click(
                window: readinessInfo.window.id,
                at: testPoint,
                policy: .UNMINIMIZE(),
                route: .UI_EVENT // Force UI_EVENT to avoid coordinate conversion issues
            )
            
            print("📊 Click result: success=\(result.success), route=\(result.route)")
            
            // Check if this worked
            try await Task.sleep(nanoseconds: 300_000_000)
            let isClicked = try await client.validateClickTarget(id: firstTarget.id)
            print("✅ Target clicked: \(isClicked)")
            
            if isClicked {
                print("🎉 Success with coordinate set \(index + 1)")
                break
            }
            
            if index < testCoordinates.count - 1 {
                // Reset for next attempt
                try await client.resetState()
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        
        // Final verification
        let finalCheck = try await client.validateClickTarget(id: firstTarget.id)
        #expect(finalCheck, "Target should be clicked with at least one coordinate set")
        
        let session = try await client.endSession()
        // Don't require session success for debug test
        print("📊 Session: \(session.successfulTests) successful tests")
    }
}

// MARK: - Supporting Types

struct ClickTestResult {
    let targetId: String
    let targetLabel: String
    let success: Bool
    let route: Route
    let duration: TimeInterval
}