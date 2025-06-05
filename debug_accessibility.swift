#!/usr/bin/env swift

import Foundation
import ApplicationServices

// Simple test to check if accessibility permissions work
print("Testing accessibility permissions...")

let isTrusted = AXIsProcessTrusted()
print("AXIsProcessTrusted: \(isTrusted)")

if !isTrusted {
    print("❌ Accessibility permissions not granted")
    print("Please enable Accessibility permissions in System Preferences > Security & Privacy > Accessibility")
    exit(1)
}

print("✅ Accessibility permissions are granted")

// Test basic window listing
print("\nTesting window listing...")
let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
print("Found \(windowList.count) windows")

for (index, windowInfo) in windowList.enumerated() {
    if index >= 5 { break } // Show only first 5
    
    if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
       let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
       let title = windowInfo[kCGWindowName as String] as? String,
       !title.isEmpty {
        print("  Window \(index + 1): ID=\(windowID), PID=\(ownerPID), Title='\(title)'")
    }
}

print("\n✅ Basic accessibility test completed")