#!/usr/bin/env swift

import Foundation
import CoreGraphics

print("=== Direct Coordinate Test ===")

// TestApp window details from previous tests
let windowX: CGFloat = 432
let windowY: CGFloat = -988  // CGWindow coordinate (top-left origin)
let windowWidth: CGFloat = 1208
let windowHeight: CGFloat = 652

// Target position within window (from TestApp API)
let targetX: CGFloat = 50
let targetY: CGFloat = 50

print("Window: (\(windowX), \(windowY)) size: (\(windowWidth), \(windowHeight))")
print("Target relative: (\(targetX), \(targetY))")

// Calculate screen coordinates using different approaches
print("\nCoordinate Calculations:")

// 1. Direct addition (current AppPilot approach)
let directX = windowX + targetX  // 432 + 50 = 482
let directY = windowY + targetY  // -988 + 50 = -938
print("1. Direct addition: (\(directX), \(directY))")

// 2. Consider that window might be in a different coordinate space
// If the window is on the second display, we need to adjust
let displays = [
    (name: "Primary", frame: CGRect(x: 0, y: 0, width: 1470, height: 956)),
    (name: "Secondary", frame: CGRect(x: -280, y: -1080, width: 1920, height: 1080))
]

for display in displays {
    let windowRect = CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    
    if display.frame.intersects(windowRect) {
        print("Window intersects \(display.name) display: \(display.frame)")
        
        // Calculate position relative to this display
        let relativeX = windowX - display.frame.origin.x
        let relativeY = windowY - display.frame.origin.y
        
        // Target position on this display
        let displayTargetX = relativeX + targetX
        let displayTargetY = relativeY + targetY
        
        print("  Window relative to display: (\(relativeX), \(relativeY))")
        print("  Target on display: (\(displayTargetX), \(displayTargetY))")
        
        // Convert to global coordinates for different systems
        let globalX = display.frame.origin.x + displayTargetX
        let globalY = display.frame.origin.y + displayTargetY
        
        print("  Global coordinates: (\(globalX), \(globalY))")
    }
}

// 3. Try different Y coordinate approaches
print("\nAlternative Y calculations:")
print("  Window Y + target Y: \(-988 + 50) = \(-938)")
print("  Absolute Y: \(abs(windowY) + targetY) = \(abs(windowY) + targetY)")
print("  Secondary display bottom: \(-1080 + windowHeight + targetY) = \(-1080 + windowHeight + targetY)")

// 4. Direct click test at calculated coordinates
let testCoordinate = CGPoint(x: 482, y: -938)

print("\n=== Testing Click at (\(testCoordinate.x), \(testCoordinate.y)) ===")

// Create and post click event
if let eventSource = CGEventSource(stateID: .hidSystemState) {
    print("Moving cursor...")
    let _ = CGWarpMouseCursorPosition(testCoordinate)
    
    usleep(100000) // 100ms
    
    if let mouseDown = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseDown,
        mouseCursorPosition: testCoordinate,
        mouseButton: .left
    ),
    let mouseUp = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseUp,
        mouseCursorPosition: testCoordinate,
        mouseButton: .left
    ) {
        print("Posting click events...")
        mouseDown.post(tap: .cghidEventTap)
        usleep(16000) // 16ms
        mouseUp.post(tap: .cghidEventTap)
        print("Click posted at (\(testCoordinate.x), \(testCoordinate.y))")
    }
}

print("\nCheck TestApp to see if the click was registered.")
print("If not, the coordinate system calculation needs adjustment.")