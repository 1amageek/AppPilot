#!/usr/bin/env swift

import Foundation
import CoreGraphics

// Test script to verify coordinate handling for TestApp on secondary monitors

print("🔍 TestApp Coordinate System Analysis")
print(String(repeating: "=", count: 60))

// First check all screens
print("\n📺 Screen Configuration:")
if let screens = CGMainDisplayID() as CGDirectDisplayID? {
    var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 10)
    var displayCount: UInt32 = 0
    
    let result = CGGetOnlineDisplayList(10, &onlineDisplays, &displayCount)
    if result == .success {
        print("Found \(displayCount) displays:")
        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplays[i]
            let bounds = CGDisplayBounds(displayID)
            let isPrimary = CGDisplayIsMain(displayID) != 0
            print("  Display \(i): \(bounds) \(isPrimary ? "[PRIMARY]" : "")")
        }
    }
}

// Check TestApp window position
print("\n🪟 TestApp Window Analysis:")
let script = """
tell application "System Events"
    set appList to {}
    repeat with proc in application processes
        if name of proc contains "TestApp" then
            if (count of windows of proc) > 0 then
                set win to window 1 of proc
                set winPos to position of win
                set winSize to size of win
                set appInfo to "Process: " & name of proc & ", Window: " & name of win
                set appInfo to appInfo & ", Position: (" & item 1 of winPos & ", " & item 2 of winPos & ")"
                set appInfo to appInfo & ", Size: (" & item 1 of winSize & ", " & item 2 of winSize & ")"
                set end of appList to appInfo
            end if
        end if
    end repeat
    return appList
end tell
"""

if let appleScript = NSAppleScript(source: script) {
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)
    if let error = error {
        print("❌ Error: \(error)")
    } else if let results = result.coerce(toDescriptorType: typeAEList) {
        for i in 1...results.numberOfItems {
            if let item = results.atIndex(i)?.stringValue {
                print("  \(item)")
            }
        }
    }
}

// Calculate which screen TestApp is on
print("\n🎯 Coordinate System Recommendations:")
print("1. TestApp appears to be on a secondary monitor with negative Y coordinates")
print("2. The window bounds show Y=-1016, indicating it's above the primary screen")
print("3. Click coordinates should be in the range:")
print("   - X: 1197 to 1497 (for the 5 targets)")
print("   - Y: -853 to -553 (for the 5 targets)")
print("4. These are valid screen coordinates for macOS multi-monitor setups")

// Test a manual click using CGEvent
print("\n🖱️ Testing CGEvent click at center target coordinates...")
let centerX: CGFloat = 1347
let centerY: CGFloat = -703

if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left) {
    mouseDown.post(tap: .cghidEventTap)
    print("✅ Posted mouse down at (\(centerX), \(centerY))")
    
    Thread.sleep(forTimeInterval: 0.1)
    
    if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: centerX, y: centerY), mouseButton: .left) {
        mouseUp.post(tap: .cghidEventTap)
        print("✅ Posted mouse up at (\(centerX), \(centerY))")
    }
}

// Check if the click was detected
print("\n🌐 Checking TestApp API for click result...")
Thread.sleep(forTimeInterval: 0.5) // Wait for API to update

if let url = URL(string: "http://localhost:8765/api/targets") {
    let semaphore = DispatchSemaphore(value: 0)
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("✅ Click targets status:")
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
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
}