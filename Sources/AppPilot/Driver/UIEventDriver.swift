import Foundation
import CoreGraphics

public protocol UIEventDriver: Sendable {
    func click(at point: CGPoint, button: MouseButton, count: Int) async throws
    func type(text: String) async throws
    func keyPress(key: String, modifiers: CGEventFlags) async throws
    func gesture(_ gesture: Gesture, durationMs: Int) async throws
}

public actor DefaultUIEventDriver: UIEventDriver {
    public init() {}
    
    public func click(at point: CGPoint, button: MouseButton, count: Int) async throws {
        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw PilotError.OS_FAILURE(api: "CGEventSource", status: -1)
        }
        
        // Map MouseButton to CGMouseButton
        let cgButton: CGMouseButton
        let eventType: CGEventType
        let eventTypeUp: CGEventType
        
        switch button {
        case .left:
            cgButton = .left
            eventType = .leftMouseDown
            eventTypeUp = .leftMouseUp
        case .right:
            cgButton = .right
            eventType = .rightMouseDown
            eventTypeUp = .rightMouseUp
        case .center:
            cgButton = .center
            eventType = .otherMouseDown
            eventTypeUp = .otherMouseUp
        }
        
        // Perform click(s)
        for _ in 0..<count {
            // Mouse down event
            guard let mouseDown = CGEvent(
                mouseEventSource: eventSource,
                mouseType: eventType,
                mouseCursorPosition: point,
                mouseButton: cgButton
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.mouseDown", status: -1)
            }
            
            // Mouse up event
            guard let mouseUp = CGEvent(
                mouseEventSource: eventSource,
                mouseType: eventTypeUp,
                mouseCursorPosition: point,
                mouseButton: cgButton
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.mouseUp", status: -1)
            }
            
            // Set click count for double/triple clicks
            if count > 1 {
                mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(count))
                mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            }
            
            // Post events
            mouseDown.post(tap: .cghidEventTap)
            mouseUp.post(tap: .cghidEventTap)
            
            // Small delay between clicks for multi-click
            if count > 1 {
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }
    
    public func type(text: String) async throws {
        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw PilotError.OS_FAILURE(api: "CGEventSource", status: -1)
        }
        
        // Create keyboard event
        guard let keyboardEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) else {
            throw PilotError.OS_FAILURE(api: "CGEvent.keyboard", status: -1)
        }
        
        // Convert string to UniChar array
        let utf16 = Array(text.utf16)
        
        // Process text in chunks (CGEvent has a limit on string length)
        let chunkSize = 20
        for i in stride(from: 0, to: utf16.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, utf16.count)
            let chunk = Array(utf16[i..<endIndex])
            
            chunk.withUnsafeBufferPointer { buffer in
                keyboardEvent.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: buffer.baseAddress)
            }
            
            keyboardEvent.post(tap: .cghidEventTap)
            
            // Small delay between chunks
            if endIndex < utf16.count {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    public func keyPress(key: String, modifiers: CGEventFlags) async throws {
        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw PilotError.OS_FAILURE(api: "CGEventSource", status: -1)
        }
        
        // Map common key strings to virtual key codes
        let keyCode = virtualKeyCode(for: key)
        
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else {
            throw PilotError.OS_FAILURE(api: "CGEvent.keyDown", status: -1)
        }
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            throw PilotError.OS_FAILURE(api: "CGEvent.keyUp", status: -1)
        }
        
        // Set modifiers
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        
        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    public func gesture(_ gesture: Gesture, durationMs: Int) async throws {
        // Create event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw PilotError.OS_FAILURE(api: "CGEventSource", status: -1)
        }
        
        switch gesture {
        case .scroll(let dx, let dy):
            // Create scroll event
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(-dy), // Inverted for natural scrolling
                wheel2: Int32(-dx),
                wheel3: 0
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.scroll", status: -1)
            }
            
            scrollEvent.post(tap: .cghidEventTap)
            
        case .drag(let from, let to):
            // Mouse down at start position
            guard let mouseDown = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .leftMouseDown,
                mouseCursorPosition: CGPoint(x: from.x, y: from.y),
                mouseButton: .left
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.dragStart", status: -1)
            }
            
            mouseDown.post(tap: .cghidEventTap)
            
            // Calculate intermediate points for smooth dragging
            let steps = max(10, durationMs / 10)
            let deltaX = (to.x - from.x) / Double(steps)
            let deltaY = (to.y - from.y) / Double(steps)
            
            for i in 1...steps {
                let currentX = from.x + deltaX * Double(i)
                let currentY = from.y + deltaY * Double(i)
                
                guard let dragEvent = CGEvent(
                    mouseEventSource: eventSource,
                    mouseType: .leftMouseDragged,
                    mouseCursorPosition: CGPoint(x: currentX, y: currentY),
                    mouseButton: .left
                ) else {
                    throw PilotError.OS_FAILURE(api: "CGEvent.drag", status: -1)
                }
                
                dragEvent.post(tap: .cghidEventTap)
                try await Task.sleep(nanoseconds: UInt64(durationMs / steps) * 1_000_000)
            }
            
            // Mouse up at end position
            guard let mouseUp = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .leftMouseUp,
                mouseCursorPosition: CGPoint(x: to.x, y: to.y),
                mouseButton: .left
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.dragEnd", status: -1)
            }
            
            mouseUp.post(tap: .cghidEventTap)
            
        case .swipe(let direction, let distance):
            // Get current mouse position
            let currentLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            
            // Calculate end position based on direction
            let endPoint: CGPoint
            switch direction {
            case .up:
                endPoint = CGPoint(x: currentLocation.x, y: currentLocation.y - distance)
            case .down:
                endPoint = CGPoint(x: currentLocation.x, y: currentLocation.y + distance)
            case .left:
                endPoint = CGPoint(x: currentLocation.x - distance, y: currentLocation.y)
            case .right:
                endPoint = CGPoint(x: currentLocation.x + distance, y: currentLocation.y)
            }
            
            // Perform swipe as a quick drag
            try await self.gesture(.drag(
                from: Point(x: currentLocation.x, y: currentLocation.y),
                to: Point(x: endPoint.x, y: endPoint.y)
            ), durationMs: min(durationMs, 200))
            
        case .pinch(let scale, let center):
            // Pinch gesture using scroll wheel simulation
            // Since true trackpad pinch events require private APIs,
            // we simulate zoom using scroll wheel with modifier keys
            
            // Simulate zoom with Cmd+scroll (common zoom shortcut)
            let scrollDelta = scale > 1.0 ? 10 : -10 // Positive for zoom in, negative for zoom out
            
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .pixel,
                wheelCount: 1,
                wheel1: Int32(scrollDelta),
                wheel2: 0,
                wheel3: 0
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.pinch", status: -1)
            }
            
            // Add Command modifier to trigger zoom
            scrollEvent.flags = .maskCommand
            scrollEvent.location = CGPoint(x: center.x, y: center.y)
            scrollEvent.post(tap: .cghidEventTap)
            
        case .rotate(let degrees, let center):
            // Rotation gesture simulation
            // Since true rotation events require trackpad hardware,
            // we can simulate rotation with Shift+Command+scroll (if supported by app)
            // or throw an informative error for unsupported gesture
            
            if abs(degrees) < 1.0 {
                // Very small rotation, skip
                return
            }
            
            // Some apps support rotation with modifier keys + scroll
            let scrollDelta = degrees > 0 ? 5 : -5
            
            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .pixel,
                wheelCount: 1,
                wheel1: Int32(scrollDelta),
                wheel2: 0,
                wheel3: 0
            ) else {
                throw PilotError.OS_FAILURE(api: "CGEvent.rotate", status: -1)
            }
            
            // Use Shift+Command as rotation modifier (app-dependent)
            scrollEvent.flags = [.maskCommand, .maskShift]
            scrollEvent.location = CGPoint(x: center.x, y: center.y)
            scrollEvent.post(tap: .cghidEventTap)
            
            // Note: True rotation gesture support is limited without trackpad hardware events
        }
    }
    
    // Helper function to map key strings to virtual key codes
    private func virtualKeyCode(for key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'": return 0x27
        case "k": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".": return 0x2F
        case "`": return 0x32
        case " ", "space": return 0x31
        case "return", "enter": return 0x24
        case "tab": return 0x30
        case "delete", "backspace": return 0x33
        case "escape", "esc": return 0x35
        case "command", "cmd": return 0x37
        case "shift": return 0x38
        case "capslock": return 0x39
        case "option", "alt": return 0x3A
        case "control", "ctrl": return 0x3B
        case "rightshift": return 0x3C
        case "rightoption": return 0x3D
        case "rightcontrol": return 0x3E
        case "function", "fn": return 0x3F
        case "f17": return 0x40
        case "volumeup": return 0x48
        case "volumedown": return 0x49
        case "mute": return 0x4A
        case "f18": return 0x4F
        case "f19": return 0x50
        case "f20": return 0x5A
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f3": return 0x63
        case "f8": return 0x64
        case "f9": return 0x65
        case "f11": return 0x67
        case "f13": return 0x69
        case "f16": return 0x6A
        case "f14": return 0x6B
        case "f10": return 0x6D
        case "f12": return 0x6F
        case "f15": return 0x71
        case "help": return 0x72
        case "home": return 0x73
        case "pageup": return 0x74
        case "forwarddelete": return 0x75
        case "f4": return 0x76
        case "end": return 0x77
        case "f2": return 0x78
        case "pagedown": return 0x79
        case "f1": return 0x7A
        case "leftarrow", "left": return 0x7B
        case "rightarrow", "right": return 0x7C
        case "downarrow", "down": return 0x7D
        case "uparrow", "up": return 0x7E
        default: return 0x00 // Default to 'a'
        }
    }
}