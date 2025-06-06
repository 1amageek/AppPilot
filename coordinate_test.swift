#!/usr/bin/env swift

import Foundation
@testable import AppPilot

print("=== Coordinate Test ===")

Task {
    do {
        let client = TestAppClient()
        let discovery = TestAppDiscovery(config: TestConfiguration())
        
        // Basic setup
        guard try await client.healthCheck() else {
            print("API not healthy")
            exit(1)
        }
        
        try await client.resetState()
        _ = try await client.startSession()
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        guard readinessInfo.isReady else {
            print("TestApp not ready")
            exit(1)
        }
        
        let targets = try await client.getClickTargets()
        guard !targets.isEmpty else {
            print("No targets")
            exit(1)
        }
        
        let target = targets[0]
        print("Target: \(target.label) at (\(target.position.x), \(target.position.y))")
        print("Window: \(readinessInfo.window.frame)")
        
        let pilot = AppPilot()
        
        // Test direct click without coordinate conversion complexity
        let result = try await pilot.click(
            window: readinessInfo.window.id,
            at: Point(x: 100, y: 100), // Simple fixed coordinates
            policy: .UNMINIMIZE(),
            route: .UI_EVENT
        )
        
        print("Click result: \(result.success), route: \(result.route)")
        
        // Check if any target was clicked
        try await Task.sleep(nanoseconds: 500_000_000)
        let finalTargets = try await client.getClickTargets()
        let clickedTargets = finalTargets.filter { $0.isClicked }
        print("Clicked targets: \(clickedTargets.count)")
        
        for clickedTarget in clickedTargets {
            print("✅ \(clickedTarget.label) was clicked")
        }
        
        _ = try await client.endSession()
        print("Test completed")
        
    } catch {
        print("Error: \(error)")
        exit(1)
    }
    
    exit(0)
}

RunLoop.main.run()