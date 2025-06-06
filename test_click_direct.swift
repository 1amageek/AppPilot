#!/usr/bin/env swift

import Foundation
import CoreGraphics

print("=== Direct CGEvent Click Test ===")
print("This will click at (482, -938) in 3 seconds...")
print("Position your mouse or TestApp window to see if it registers.")
print("Countdown: 3...")
sleep(1)
print("2...")
sleep(1)
print("1...")
sleep(1)

let clickPoint = CGPoint(x: 482, y: -938)
print("Clicking at: \(clickPoint)")

// Create event source
guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
    print("❌ Failed to create event source")
    exit(1)
}

// Create mouse down event
guard let mouseDown = CGEvent(
    mouseEventSource: eventSource,
    mouseType: .leftMouseDown,
    mouseCursorPosition: clickPoint,
    mouseButton: .left
) else {
    print("❌ Failed to create mouse down event")
    exit(1)
}

// Create mouse up event
guard let mouseUp = CGEvent(
    mouseEventSource: eventSource,
    mouseType: .leftMouseUp,
    mouseCursorPosition: clickPoint,
    mouseButton: .left
) else {
    print("❌ Failed to create mouse up event")
    exit(1)
}

print("📤 Posting mouse down event...")
mouseDown.post(tap: .cghidEventTap)

print("⏱️ Waiting 10ms...")
usleep(10_000) // 10ms

print("📤 Posting mouse up event...")
mouseUp.post(tap: .cghidEventTap)

print("✅ Click events posted successfully")
print("Check if TestApp registered the click...")

// Wait a bit to see results
sleep(2)
print("Done.")