#!/usr/bin/env swift

import Foundation
import CoreGraphics
import AppKit

print("=== SwiftUI Gesture Trigger Analysis ===")

// Test different CGEvent approaches to trigger SwiftUI gestures

func testCGEventApproach(name: String, createEvent: () -> CGEvent?) {
    print("\n--- Testing: \(name) ---")
    
    guard let event = createEvent() else {
        print("❌ Failed to create event")
        return
    }
    
    print("✅ Event created successfully")
    print("  Event type: \(event.type.rawValue)")
    print("  Location: \(event.location)")
    print("  Flags: \(event.flags.rawValue)")
    
    // Post event
    event.post(tap: .cghidEventTap)
    print("📤 Event posted")
}

let targetPoint = CGPoint(x: 482, y: -938)

// 1. Basic mouse down/up
testCGEventApproach(name: "Basic Mouse Down/Up") {
    guard let eventSource = CGEventSource(stateID: .hidSystemState),
          let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ) else { return nil }
    
    // Post mouse down immediately followed by mouse up
    let mouseUp = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseUp,
        mouseCursorPosition: targetPoint,
        mouseButton: .left
    )
    
    mouseDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.01) // 10ms delay
    mouseUp?.post(tap: .cghidEventTap)
    
    return mouseDown
}

// 2. With explicit click count
testCGEventApproach(name: "With Click Count") {
    guard let eventSource = CGEventSource(stateID: .hidSystemState),
          let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ),
          let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ) else { return nil }
    
    // Set click count
    mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
    mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
    
    mouseDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.01)
    mouseUp.post(tap: .cghidEventTap)
    
    return mouseDown
}

// 3. Using different event tap location
testCGEventApproach(name: "Using CGSessionEventTap") {
    guard let eventSource = CGEventSource(stateID: .hidSystemState),
          let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ),
          let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ) else { return nil }
    
    mouseDown.post(tap: .cgSessionEventTap)
    Thread.sleep(forTimeInterval: 0.01)
    mouseUp.post(tap: .cgSessionEventTap)
    
    return mouseDown
}

// 4. Move cursor first, then click
testCGEventApproach(name: "Move Cursor Then Click") {
    guard let eventSource = CGEventSource(stateID: .hidSystemState) else { return nil }
    
    // First move cursor to position
    if let mouseMove = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .mouseMoved,
        mouseCursorPosition: targetPoint,
        mouseButton: .left
    ) {
        mouseMove.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05) // 50ms to let cursor move
    }
    
    // Then perform click
    guard let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ),
          let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
          ) else { return nil }
    
    mouseDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.01)
    mouseUp.post(tap: .cghidEventTap)
    
    return mouseDown
}

print("\n=== Test Complete ===")
print("Check TestApp to see if any clicks were registered.")
print("The most likely solution is approach #4 (Move Cursor Then Click)")