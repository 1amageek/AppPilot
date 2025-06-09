#!/usr/bin/env swift

import Foundation
import AppKit

// Debug script to test clicking on TestApp

print("🔍 TestApp Click Debug")
print(String(repeating: "=", count: 60))

// First, find TestApp window with AppleScript
let findWindowScript = """
tell application "System Events"
    tell process "TestApp"
        if (count of windows) > 0 then
            set win to window 1
            set winBounds to position of win & size of win
            return winBounds
        else
            return {}
        end if
    end tell
end tell
"""

print("\n📍 Finding TestApp window bounds...")
if let script = NSAppleScript(source: findWindowScript) {
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if let error = error {
        print("❌ Error: \(error)")
    } else {
        print("✅ Window info: \(result.stringValue ?? "Unknown")")
    }
}

// Try to click using AppleScript
let clickScript = """
tell application "System Events"
    tell process "TestApp"
        if (count of windows) > 0 then
            set win to window 1
            -- Try to click in the center of the window
            tell win
                click at {position of win} + {(size of win) / 2}
            end tell
            return "Clicked TestApp window"
        else
            return "No TestApp window found"
        end if
    end tell
end tell
"""

print("\n🖱️ Attempting to click TestApp window...")
if let script = NSAppleScript(source: clickScript) {
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if let error = error {
        print("❌ Click error: \(error)")
    } else {
        print("✅ Click result: \(result.stringValue ?? "Unknown")")
    }
}

// Check TestApp API for click results
print("\n🌐 Checking TestApp API...")
if let url = URL(string: "http://localhost:8765/api/targets") {
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("❌ API Error: \(error)")
        } else if let data = data {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("✅ Click targets:")
                    for target in json {
                        if let label = target["label"],
                           let clicked = target["clicked"] as? Bool {
                            print("   \(label): \(clicked ? "✅ Clicked" : "⭕ Not clicked")")
                        }
                    }
                }
            } catch {
                print("❌ JSON Error: \(error)")
            }
        }
        exit(0)
    }
    task.resume()
    RunLoop.main.run()
}