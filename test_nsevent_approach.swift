#!/usr/bin/env swift

import Foundation
import AppKit

print("=== NSEvent Approach Test ===")

// Find TestApp window first
func findTestAppWindow() -> NSWindow? {
    let app = NSApplication.shared
    
    // Get all windows
    for window in app.windows {
        if window.title.contains("Mouse Click") {
            return window
        }
    }
    
    // Try running applications
    let runningApps = NSWorkspace.shared.runningApplications
    for app in runningApps {
        if app.localizedName?.contains("TestApp") == true {
            print("Found TestApp process: \(app.processIdentifier)")
            break
        }
    }
    
    return nil
}

let targetPoint = NSPoint(x: 482, y: -938)

print("Looking for TestApp window...")

// Method 1: Direct NSEvent posting
print("\n--- Method 1: NSEvent mouseDown/Up ---")

let mouseDownEvent = NSEvent.mouseEvent(
    with: .leftMouseDown,
    location: targetPoint,
    modifierFlags: [],
    timestamp: ProcessInfo.processInfo.systemUptime,
    windowNumber: 0,
    context: nil,
    eventNumber: 0,
    clickCount: 1,
    pressure: 1.0
)

let mouseUpEvent = NSEvent.mouseEvent(
    with: .leftMouseUp,
    location: targetPoint,
    modifierFlags: [],
    timestamp: ProcessInfo.processInfo.systemUptime,
    windowNumber: 0,
    context: nil,
    eventNumber: 0,
    clickCount: 1,
    pressure: 1.0
)

if let mouseDown = mouseDownEvent {
    print("✅ Created NSEvent mouseDown")
    NSApp.postEvent(mouseDown, atStart: false)
    
    Thread.sleep(forTimeInterval: 0.01)
    
    if let mouseUp = mouseUpEvent {
        print("✅ Created NSEvent mouseUp")
        NSApp.postEvent(mouseUp, atStart: false)
    }
}

print("\n--- Method 2: CGEvent with target app ---")

// Method 2: Send CGEvent to specific application
let runningApps = NSWorkspace.shared.runningApplications
for app in runningApps {
    if app.localizedName?.contains("TestApp") == true {
        print("Found TestApp PID: \(app.processIdentifier)")
        
        // Create event source for target app
        if let eventSource = CGEventSource(stateID: .hidSystemState) {
            
            if let mouseDown = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .leftMouseDown,
                mouseCursorPosition: CGPoint(x: targetPoint.x, y: targetPoint.y),
                mouseButton: .left
            ) {
                mouseDown.post(tap: .cghidEventTap)
                print("📤 Posted CGEvent to TestApp")
                
                Thread.sleep(forTimeInterval: 0.01)
                
                if let mouseUp = CGEvent(
                    mouseEventSource: eventSource,
                    mouseType: .leftMouseUp,
                    mouseCursorPosition: CGPoint(x: targetPoint.x, y: targetPoint.y),
                    mouseButton: .left
                ) {
                    mouseUp.post(tap: .cghidEventTap)
                }
            }
        }
        break
    }
}

print("\n=== Alternative: AppleScript Approach ===")

// Method 3: AppleScript to simulate click
let appleScript = """
tell application "TestApp"
    activate
end tell

tell application "System Events"
    tell process "TestApp"
        click at {482, -938}
    end tell
end tell
"""

print("AppleScript command:")
print(appleScript)

if let script = NSAppleScript(source: appleScript) {
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    
    if let error = error {
        print("❌ AppleScript error: \(error)")
    } else {
        print("✅ AppleScript executed")
        if let output = result.stringValue {
            print("Output: \(output)")
        }
    }
}

print("\nTest complete. Check TestApp for click registration.")