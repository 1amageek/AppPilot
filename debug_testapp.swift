#!/usr/bin/env swift

import Foundation
import AppKit
@testable import AppPilot

// Debug script to investigate TestApp window detection issue

@main
struct DebugTestApp {
    static func main() async {
        print("🔍 Debugging TestApp Window Detection")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        do {
            // List all applications
            print("\n📱 All Applications:")
            let apps = try await pilot.listApplications()
            for app in apps {
                print("  - \(app.name) (\(app.bundleIdentifier ?? "No bundle ID"))")
                if app.name.contains("TestApp") || app.bundleIdentifier?.contains("TestApp") == true {
                    print("    ✅ Found TestApp!")
                    
                    // Try to get windows
                    do {
                        let windows = try await pilot.listWindows(app: app.id)
                        print("    🪟 Windows: \(windows.count)")
                        for (index, window) in windows.enumerated() {
                            print("       Window \(index): '\(window.title ?? "No title")' bounds: \(window.bounds)")
                        }
                    } catch {
                        print("    ❌ Error getting windows: \(error)")
                    }
                }
            }
            
            // Try using AppleScript to get TestApp windows
            print("\n📜 AppleScript Check:")
            let script = """
            tell application "System Events"
                tell process "TestApp"
                    set windowCount to count of windows
                    return "TestApp has " & windowCount & " windows"
                end tell
            end tell
            """
            
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                let result = appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("  ❌ AppleScript error: \(error)")
                } else {
                    print("  ✅ \(result.stringValue ?? "No result")")
                }
            }
            
            // Check if TestApp is responding to API
            print("\n🌐 TestApp API Check:")
            let url = URL(string: "http://localhost:8765/api/health")!
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                print("  ✅ API Status: \(httpResponse.statusCode)")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("  📊 API Response: \(json)")
                }
            }
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
}