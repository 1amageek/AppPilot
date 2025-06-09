#!/usr/bin/env swift

import Foundation
import AppKit

// Simple debug script to check TestApp windows

// Check via AppleScript
let script = """
tell application "System Events"
    set appList to {}
    repeat with proc in application processes
        if name of proc contains "TestApp" then
            set windowCount to count of windows of proc
            set appInfo to name of proc & " - Windows: " & windowCount
            if windowCount > 0 then
                set windowTitles to {}
                repeat with w in windows of proc
                    set end of windowTitles to name of w
                end repeat
                set appInfo to appInfo & " [" & (windowTitles as string) & "]"
            end if
            set end of appList to appInfo
        end if
    end repeat
    return appList
end tell
"""

print("🔍 Checking TestApp Windows via AppleScript")
print(String(repeating: "=", count: 60))

if let appleScript = NSAppleScript(source: script) {
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)
    if let error = error {
        print("❌ AppleScript error: \(error)")
    } else if let results = result.coerce(toDescriptorType: typeAEList) {
        for i in 1...results.numberOfItems {
            if let item = results.atIndex(i)?.stringValue {
                print("  \(item)")
            }
        }
    }
}

// Check running applications
print("\n📱 NSWorkspace Check:")
let runningApps = NSWorkspace.shared.runningApplications
for app in runningApps {
    if let name = app.localizedName, name.contains("TestApp") {
        print("  - \(name)")
        print("    Bundle ID: \(app.bundleIdentifier ?? "None")")
        print("    Process ID: \(app.processIdentifier)")
        print("    Is Active: \(app.isActive)")
        print("    Is Hidden: \(app.isHidden)")
        print("    Is Terminated: \(app.isTerminated)")
        print("    Activation Policy: \(app.activationPolicy.rawValue)")
    }
}

// Check API
print("\n🌐 TestApp API Check:")
if let url = URL(string: "http://localhost:8765/api/health") {
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("  ❌ API Error: \(error)")
        } else if let httpResponse = response as? HTTPURLResponse {
            print("  ✅ API Status: \(httpResponse.statusCode)")
        }
        exit(0)
    }
    task.resume()
    RunLoop.main.run()
}