#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

print("=== macOS Coordinate System Verification ===\n")

// 1. Get primary screen info
if let primaryScreen = NSScreen.main {
    print("Primary Screen:")
    print("  Frame: \(primaryScreen.frame)")
    print("  Visible Frame: \(primaryScreen.visibleFrame)")
    print("  Bottom-left origin coordinate system\n")
}

// 2. Get all screens
print("All Screens:")
for (index, screen) in NSScreen.screens.enumerated() {
    print("  Screen \(index): \(screen.frame)")
}
print("")

// 3. Get window list and check coordinates
if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    print("Sample Windows (first 5):")
    
    for (index, windowInfo) in windowList.prefix(5).enumerated() {
        if let name = windowInfo[kCGWindowName as String] as? String,
           let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
           let x = boundsDict["X"] as? CGFloat,
           let y = boundsDict["Y"] as? CGFloat,
           let width = boundsDict["Width"] as? CGFloat,
           let height = boundsDict["Height"] as? CGFloat {
            
            print("  \(index + 1). \(name.prefix(30))...")
            print("     CGWindow bounds: (\(x), \(y), \(width), \(height))")
            print("     Note: Y coordinate from TOP of screen")
        }
    }
}

print("\n=== Coordinate System Summary ===")
print("1. NSScreen uses bottom-left origin (0,0 at bottom-left)")
print("2. CGWindowListCopyWindowInfo uses top-left origin (0,0 at top-left)")
print("3. AX APIs typically use top-left origin like CGWindow")
print("4. Core Graphics event coordinates use bottom-left origin")