#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ApplicationServices
@testable import AppPilot

print("=== Click Coordinate Debug ===\n")

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
        let window = readinessInfo.window
        
        print("Target: \(target.label) at window-relative (\(target.position.x), \(target.position.y))")
        print("Window frame (CGWindow): \(window.frame)")
        print("")
        
        // Calculate different coordinate interpretations
        print("Coordinate Calculations:")
        
        // 1. Direct addition (current implementation)
        let directX = window.frame.origin.x + target.position.x
        let directY = window.frame.origin.y + target.position.y
        print("1. Direct addition: (\(directX), \(directY))")
        
        // 2. Considering CGWindow uses top-left origin
        if let screen = NSScreen.main {
            let screenHeight = screen.frame.height
            
            // Convert window Y from top-left to bottom-left
            let windowBottomY = screenHeight - window.frame.origin.y - window.frame.height
            let clickBottomY = windowBottomY + (window.frame.height - target.position.y)
            print("2. Bottom-left conversion: (\(directX), \(clickBottomY))")
            
            // For CGEvent (which uses flipped coordinates)
            let cgEventY = screenHeight - clickBottomY
            print("3. CGEvent coordinates: (\(directX), \(cgEventY))")
        }
        
        // 4. Check which display the window is on
        print("\nDisplay Analysis:")
        for (index, screen) in NSScreen.screens.enumerated() {
            let screenFrame = screen.frame
            
            // Check if window overlaps this screen
            let windowScreenX = window.frame.origin.x
            let windowScreenY = screen.frame.height - window.frame.origin.y - window.frame.height
            
            let windowRect = CGRect(
                x: windowScreenX,
                y: windowScreenY,
                width: window.frame.width,
                height: window.frame.height
            )
            
            if screenFrame.intersects(windowRect) {
                print("Window is on Screen \(index): \(screenFrame)")
            }
        }
        
        _ = try await client.endSession()
        print("\nDebug completed")
        
    } catch {
        print("Error: \(error)")
        exit(1)
    }
    
    exit(0)
}

RunLoop.main.run()