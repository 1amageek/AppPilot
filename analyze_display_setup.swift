#!/usr/bin/env swift

import Foundation
import AppKit
import CoreGraphics

print("=== Display Configuration Analysis ===\n")

// 1. Get all screens with detailed info
print("Screen Configuration:")
for (index, screen) in NSScreen.screens.enumerated() {
    print("  Screen \(index):")
    print("    Frame (NSScreen): \(screen.frame)")
    print("    Visible Frame: \(screen.visibleFrame)")
    
    if screen == NSScreen.main {
        print("    → PRIMARY SCREEN")
    }
    print("")
}

// 2. Check CGDisplayBounds for comparison
print("CGDisplay Configuration:")
let maxDisplays: UInt32 = 16
var displayIDs = Array<CGDirectDisplayID>(repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0

let result = CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)
if result == .success {
    for i in 0..<Int(displayCount) {
        let displayID = displayIDs[i]
        let bounds = CGDisplayBounds(displayID)
        print("  Display \(displayID): \(bounds)")
        
        if CGDisplayIsMain(displayID) != 0 {
            print("    → PRIMARY DISPLAY")
        }
    }
}

print("\n=== TestApp Window Analysis ===")

// 3. Find TestApp window with specific analysis
if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    
    let testAppWindows = windowList.filter { windowInfo in
        if let name = windowInfo[kCGWindowOwnerName as String] as? String,
           let title = windowInfo[kCGWindowName as String] as? String {
            return name.contains("TestApp") && title == "Mouse Click"
        }
        return false
    }
    
    for (index, windowInfo) in testAppWindows.enumerated() {
        print("TestApp Window \(index + 1):")
        
        if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
           let x = boundsDict["X"] as? CGFloat,
           let y = boundsDict["Y"] as? CGFloat,
           let width = boundsDict["Width"] as? CGFloat,
           let height = boundsDict["Height"] as? CGFloat {
            
            print("  CGWindow bounds: (\(x), \(y), \(width), \(height))")
            
            // Check which screen this window should be on
            let windowRect = CGRect(x: x, y: y, width: width, height: height)
            
            print("  Screen Analysis:")
            for (screenIndex, screen) in NSScreen.screens.enumerated() {
                let screenFrame = screen.frame
                
                // Check if window overlaps this screen
                if screenFrame.intersects(windowRect) {
                    print("    ✅ Intersects Screen \(screenIndex): \(screenFrame)")
                    
                    // Calculate relative position on this screen
                    let relativeX = x - screenFrame.origin.x
                    let relativeY = y - screenFrame.origin.y
                    print("    Relative position on Screen \(screenIndex): (\(relativeX), \(relativeY))")
                } else {
                    print("    ❌ No intersection with Screen \(screenIndex): \(screenFrame)")
                }
            }
            
            // Show correct coordinate conversion
            print("  Coordinate Conversion:")
            let targetX = x + 50  // Target at (50,50) relative to window
            let targetY = y + 50
            print("    Target in global coordinates: (\(targetX), \(targetY))")
            
            // For CGEvent, we need to handle multiple display scenarios
            // The key insight: CGEvent coordinates are relative to the global coordinate space
            // where (0,0) is the bottom-left of the PRIMARY screen
            
            let primaryScreen = NSScreen.main!
            let primaryHeight = primaryScreen.frame.height
            
            // If the window is on a secondary display, we need to account for that
            // CGEvent still uses the global coordinate space
            let cgEventX = targetX
            let cgEventY = primaryHeight - targetY  // This is wrong for secondary displays!
            
            print("    Naive CGEvent coordinates: (\(cgEventX), \(cgEventY))")
            
            // Correct approach: Find the actual screen and convert properly
            for screen in NSScreen.screens {
                if screen.frame.intersects(windowRect) {
                    // This is the target screen
                    let screenBottom = screen.frame.origin.y
                    let screenHeight = screen.frame.height
                    
                    // Convert to screen's bottom-left origin
                    let screenRelativeY = targetY - screenBottom
                    let correctedY = screenBottom + screenHeight - screenRelativeY
                    
                    print("    Corrected CGEvent for Screen: (\(targetX), \(correctedY))")
                    break
                }
            }
        }
    }
}