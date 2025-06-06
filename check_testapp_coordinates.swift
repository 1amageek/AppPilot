#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

print("=== TestApp Window Coordinate Analysis ===\n")

// Find TestApp windows
if let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    
    let testAppWindows = windowList.filter { windowInfo in
        if let name = windowInfo[kCGWindowOwnerName as String] as? String {
            return name.contains("TestApp")
        }
        return false
    }
    
    print("Found \(testAppWindows.count) TestApp window(s):\n")
    
    for (index, windowInfo) in testAppWindows.enumerated() {
        print("Window \(index + 1):")
        
        if let title = windowInfo[kCGWindowName as String] as? String {
            print("  Title: \(title)")
        }
        
        if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
           let x = boundsDict["X"] as? CGFloat,
           let y = boundsDict["Y"] as? CGFloat,
           let width = boundsDict["Width"] as? CGFloat,
           let height = boundsDict["Height"] as? CGFloat {
            
            print("  CGWindow bounds: (\(x), \(y), \(width), \(height))")
            print("  Position: (\(x), \(y)) - top-left origin")
            
            // Convert to NSScreen coordinates (bottom-left origin)
            if let primaryScreen = NSScreen.main {
                let screenHeight = primaryScreen.frame.height
                let nsScreenY = screenHeight - y - height  // Convert to bottom-left origin
                print("  NSScreen position: (\(x), \(nsScreenY)) - bottom-left origin")
                print("  Screen height: \(screenHeight)")
            }
        }
        
        if let layer = windowInfo[kCGWindowLayer as String] as? Int {
            print("  Window layer: \(layer)")
        }
        
        if let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat {
            print("  Alpha: \(alpha)")
        }
        
        if let isOnscreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool {
            print("  On screen: \(isOnscreen)")
        }
        
        print("")
    }
    
    if testAppWindows.isEmpty {
        print("No TestApp windows found. Make sure TestApp is running.")
    }
}

print("\n=== Coordinate Conversion Summary ===")
print("1. CGWindow Y=-988 means window is 988 pixels from TOP of screen")
print("2. If screen height is 956, then -988 means window extends below visible area")
print("3. This suggests window might be on a different Space or display")
print("4. Click events need proper coordinate transformation")