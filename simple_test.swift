#!/usr/bin/env swift

import Foundation
@testable import AppPilot

print("=== Simple AppPilot Test ===")

Task {
    do {
        print("1. Creating AppPilot instance...")
        let pilot = AppPilot()
        print("✅ AppPilot created")
        
        print("2. Testing listApplications...")
        let apps = try await pilot.listApplications()
        print("✅ Found \(apps.count) applications")
        
        for (index, app) in apps.prefix(3).enumerated() {
            print("   App \(index + 1): \(app.name) (PID: \(app.id.pid))")
        }
        
        print("3. Testing listWindows...")
        if let firstApp = apps.first {
            do {
                let windows = try await pilot.listWindows(in: firstApp.id)
                print("✅ Found \(windows.count) windows for \(firstApp.name)")
                
                for (index, window) in windows.prefix(2).enumerated() {
                    print("   Window \(index + 1): '\(window.title ?? "Untitled")' (ID: \(window.id.id))")
                }
            } catch {
                print("⚠️ Window listing failed: \(error)")
            }
        }
        
        print("\n✅ Simple test completed successfully!")
        
    } catch {
        print("❌ Test failed: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()