//  CGEventDriver.swift
//  Lightweight CGEvent wrapper (minimal core + high‑level extensions)
//
//  NOTE: Depends on existing definitions of:
//  • struct Point   (x: Double, y: Double)
//  • enum   MouseButton { case left, right, other(Int)  /* provides cgButton, downType, upType, dragType */ }
//  • enum   PilotError  (at least `.eventCreationFailed`)
//
//  These are assumed to live elsewhere in the project and are unchanged.

import Foundation
import CoreGraphics
import ApplicationServices
import Carbon

// MARK: - Supporting Types ▸───────────────────────────────────────────────

public enum SwipeDirection: Sendable {
    case up, down, left, right
    case upLeft, upRight, downLeft, downRight
    
    public var vector: (x: Double, y: Double) {
        switch self {
        case .up:        return (0, -1)
        case .down:      return (0,  1)
        case .left:      return (-1, 0)
        case .right:     return (1,  0)
        case .upLeft:    return (-0.707, -0.707)
        case .upRight:   return ( 0.707, -0.707)
        case .downLeft:  return (-0.707,  0.707)
        case .downRight: return ( 0.707,  0.707)
        }
    }
}

public enum VirtualKey: CGKeyCode, Sendable {
    // Letters
    case a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9
    case b = 11, q = 12, w = 13, e = 14, r = 15, y = 16, t = 17, o = 31, u = 32
    case i = 34, p = 35, l = 37, j = 38, k = 40, semicolon = 41, n = 45, m = 46
    
    // Numbers
    case one = 18, two = 19, three = 20, four = 21, six = 22, five = 23
    case equal = 24, nine = 25, seven = 26, minus = 27, eight = 28, zero = 29
    
    // Additional characters
    case leftBracket = 33, rightBracket = 30, backslash = 42, quote = 39
    case comma = 43, period = 47, slash = 44, grave = 50
    
    // Function keys
    case f1 = 122, f2 = 120, f3 = 99, f4 = 118, f5 = 96, f6 = 97, f7 = 98
    case f8 = 100, f9 = 101, f10 = 109, f11 = 103, f12 = 111
    
    // Special keys
    case space = 49, returnKey = 36, tab = 48, delete = 51, escape = 53
    case leftArrow = 123, rightArrow = 124, downArrow = 125, upArrow = 126
    case pageUp = 116, pageDown = 121, home = 115, end = 119
    
    // Modifiers (for reference)
    case command = 55, shift = 56, capsLock = 57, option = 58, control = 59
    
    /// Character to VirtualKey mapping for type operations
    public static let characterMapping: [Character: VirtualKey] = [
        // Letters (lowercase)
        "a": .a, "b": .b, "c": .c, "d": .d, "e": .e, "f": .f, "g": .g, "h": .h,
        "i": .i, "j": .j, "k": .k, "l": .l, "m": .m, "n": .n, "o": .o, "p": .p,
        "q": .q, "r": .r, "s": .s, "t": .t, "u": .u, "v": .v, "w": .w, "x": .x,
        "y": .y, "z": .z,
        
        // Numbers (unshifted)
        "0": .zero, "1": .one, "2": .two, "3": .three, "4": .four, "5": .five,
        "6": .six, "7": .seven, "8": .eight, "9": .nine,
        
        // Special characters (unshifted)
        "-": .minus, "=": .equal, "[": .leftBracket, "]": .rightBracket,
        "\\": .backslash, ";": .semicolon, "'": .quote, ",": .comma,
        ".": .period, "/": .slash, "`": .grave, " ": .space,
        
        // Shifted numbers (symbols)
        "!": .one,     // Shift+1
        "@": .two,     // Shift+2  
        "#": .three,   // Shift+3
        "$": .four,    // Shift+4
        "%": .five,    // Shift+5
        "^": .six,     // Shift+6
        "&": .seven,   // Shift+7
        "*": .eight,   // Shift+8
        "(": .nine,    // Shift+9
        ")": .zero,    // Shift+0
        
        // Shifted special characters
        "_": .minus,        // Shift+-
        "+": .equal,        // Shift+=
        "{": .leftBracket,  // Shift+[
        "}": .rightBracket, // Shift+]
        "|": .backslash,    // Shift+\
        ":": .semicolon,    // Shift+;
        "\"": .quote,       // Shift+'
        "<": .comma,        // Shift+,
        ">": .period,       // Shift+.
        "?": .slash,        // Shift+/
        "~": .grave         // Shift+`
    ]
    
    /// Characters that require shift key to be pressed
    public static let shiftRequiredCharacters: Set<Character> = [
        // Uppercase letters
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        
        // Shifted number symbols
        "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
        
        // Shifted special characters
        "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?", "~"
    ]
    
    /// Get VirtualKey for a given character
    public static func keyCode(for character: Character) -> CGKeyCode? {
        let ch = Character(String(character).lowercased())
        return characterMapping[ch]?.rawValue
    }
    
    /// Check if character requires shift key
    public static func requiresShift(for character: Character) -> Bool {
        return shiftRequiredCharacters.contains(character)
    }
}

public enum ModifierKey: Sendable {
    case command, shift, option, control, function
    
    public var cgEventFlag: CGEventFlags {
        switch self {
        case .command:  return .maskCommand
        case .shift:    return .maskShift
        case .option:   return .maskAlternate
        case .control:  return .maskControl
        case .function: return .maskSecondaryFn
        }
    }
    
    public var keyCode: CGKeyCode {
        switch self {
        case .command:  return 55
        case .shift:    return 56
        case .option:   return 58
        case .control:  return 59
        case .function: return 63
        }
    }
}

// MARK: - Core Protocol （必要最小限） ▸──────────────────────────────────

public protocol CGEventDriver: Sendable {
    // 🖱 Cursor & Mouse
    func moveCursor(to p: Point) async throws
    func mouseDown(button: MouseButton, at p: Point) async throws
    func mouseUp(button: MouseButton,   at p: Point) async throws
    func scroll(deltaX: Double, deltaY: Double, at p: Point) async throws
    
    // ⌨️  Keyboard (low‑level)
    func keyDown(code: CGKeyCode) async throws
    func keyUp(code: CGKeyCode)   async throws
    
    // Convenience high‑level typing
    func type(_ text: String) async throws
    
    // 🌐 Input Source Management
    func getCurrentInputSource() async throws -> InputSourceInfo
    func getAvailableInputSources() async throws -> [InputSourceInfo]
    func switchInputSource(to source: InputSource) async throws
    func type(_ text: String, inputSource: InputSource) async throws
    
    // Compatibility methods
    func click(at point: Point, button: MouseButton, count: Int) async throws
    func type(text: String) async throws
}

// MARK: - High‑Level Default Implementations ▸────────────────────────────

public extension CGEventDriver {
    // MARK: Click / DoubleClick
    @inline(__always) func click(at p: Point, button: MouseButton = .left) async throws {
        try await mouseDown(button: button, at: p)
        try await mouseUp(button: button,   at: p)
    }
    
    func click(at point: Point, button: MouseButton = .left, count: Int = 1) async throws {
        for _ in 0..<count {
            try await click(at: point, button: button)
            if count > 1 {
                try await Task.sleep(nanoseconds: 150_000_000) // 150ms between clicks
            }
        }
    }
    
    func type(text: String) async throws {
        try await type(text)
    }
    
    // MARK: Input Source Management
    func getCurrentInputSource() async throws -> InputSourceInfo {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        
        guard let identifier = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID),
              let name = TISGetInputSourceProperty(currentSource, kTISPropertyLocalizedName) else {
            throw PilotError.osFailure(api: "TISGetInputSourceProperty", code: -1)
        }
        
        // Convert CFTypeRef to CFString and then to String
        let identifierString = String(Unmanaged<CFString>.fromOpaque(identifier).takeUnretainedValue())
        let nameString = String(Unmanaged<CFString>.fromOpaque(name).takeUnretainedValue())
        
        return InputSourceInfo(
            identifier: identifierString,
            displayName: nameString,
            isActive: true
        )
    }
    
    func getAvailableInputSources() async throws -> [InputSourceInfo] {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            throw PilotError.osFailure(api: "TISCreateInputSourceList", code: -1)
        }
        
        let sourceCount = CFArrayGetCount(sources)
        var inputSources: [InputSourceInfo] = []
        
        for i in 0..<sourceCount {
            let source = CFArrayGetValueAtIndex(sources, i)
            let tisSource = unsafeBitCast(source, to: TISInputSource.self)
            
            guard let identifier = TISGetInputSourceProperty(tisSource, kTISPropertyInputSourceID),
                  let name = TISGetInputSourceProperty(tisSource, kTISPropertyLocalizedName) else {
                continue
            }
            
            let identifierString = String(Unmanaged<CFString>.fromOpaque(identifier).takeUnretainedValue())
            let nameString = String(Unmanaged<CFString>.fromOpaque(name).takeUnretainedValue())
            
            // Check if this is a keyboard input source
            if let category = TISGetInputSourceProperty(tisSource, kTISPropertyInputSourceCategory) {
                let categoryString = String(Unmanaged<CFString>.fromOpaque(category).takeUnretainedValue())
                if categoryString == kTISCategoryKeyboardInputSource as String {
                    inputSources.append(InputSourceInfo(
                        identifier: identifierString,
                        displayName: nameString,
                        isActive: false
                    ))
                }
            }
        }
        
        return inputSources
    }
    
    func switchInputSource(to source: InputSource) async throws {
        guard source != .automatic else { return }
        
        let sources = try await getAvailableInputSources()
        guard sources.contains(where: { $0.identifier == source.rawValue }) else {
            throw PilotError.osFailure(api: "switchInputSource", code: -1)
        }
        
        // Find the TISInputSource object
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else {
            throw PilotError.osFailure(api: "TISCreateInputSourceList", code: -1)
        }
        
        let sourceCount = CFArrayGetCount(sourceList)
        for i in 0..<sourceCount {
            let sourceRef = CFArrayGetValueAtIndex(sourceList, i)
            let tisSource = unsafeBitCast(sourceRef, to: TISInputSource.self)
            
            if let identifier = TISGetInputSourceProperty(tisSource, kTISPropertyInputSourceID) {
                let identifierString = String(Unmanaged<CFString>.fromOpaque(identifier).takeUnretainedValue())
                if identifierString == source.rawValue {
                    let result = TISSelectInputSource(tisSource)
                    if result != noErr {
                        throw PilotError.osFailure(api: "TISSelectInputSource", code: result)
                    }
                    return
                }
            }
        }
        
        throw PilotError.osFailure(api: "switchInputSource", code: -2)
    }
    
    func type(_ text: String, inputSource: InputSource) async throws {
        // Switch input source if needed
        if inputSource != .automatic {
            try await switchInputSource(to: inputSource)
            // Wait a bit for the input source to switch
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        // Type the text
        try await type(text)
    }
    
    @inline(__always) func doubleClick(at p: Point, button: MouseButton = .left, interval: UInt64 = 150) async throws {
        try await click(at: p, button: button)
        try await Task.sleep(nanoseconds: interval * 1_000_000)
        try await click(at: p, button: button)
    }
    
    // MARK: Drag (single finger)
    func drag(from start: Point, to end: Point, duration: TimeInterval = 0.3, button: MouseButton = .left) async throws {
        let steps = max(10, Int(duration * 60))
        let stepTime = duration / Double(steps)
        
        try await mouseDown(button: button, at: start)
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            try await moveCursor(to: Point(x: x, y: y))
            try await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
        }
        try await mouseUp(button: button, at: end)
    }
    
    // MARK: Swipe (fast drag without button)
    func swipe(from start: Point, direction: SwipeDirection, distance: Double = 400, duration: TimeInterval = 0.2) async throws {
        let end = Point(x: start.x + direction.vector.x * distance,
                        y: start.y + direction.vector.y * distance)
        let steps = max(5, Int(duration * 30))
        let stepTime = duration / Double(steps)
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            try await moveCursor(to: Point(x: x, y: y))
            try await Task.sleep(nanoseconds: UInt64(stepTime * 1_000_000_000))
        }
    }
    
    // MARK: MultiTap (1 ~ 2 fingers)
    @inline(__always) func multiTap(at p: Point, taps: Int = 1, fingers: Int = 1, interval: UInt64 = 50) async throws {
        let btn: MouseButton = (fingers == 1) ? .left : .right
        for _ in 0..<taps {
            try await click(at: p, button: btn)
            if taps > 1 { try await Task.sleep(nanoseconds: interval * 1_000_000) }
        }
    }
    
    // MARK: Modifier‐aware key press
    func keyPress(_ key: VirtualKey, modifiers: [ModifierKey] = [], hold: TimeInterval = 0.05) async throws {
        for m in modifiers { try await keyDown(code: m.keyCode) }
        try await keyDown(code: key.rawValue)
        try await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
        try await keyUp(code: key.rawValue)
        for m in modifiers.reversed() { try await keyUp(code: m.keyCode) }
    }
    
    // MARK: Key combination (simultaneous)
    func keyCombination(_ keys: [VirtualKey], modifiers: [ModifierKey] = []) async throws {
        for m in modifiers { try await keyDown(code: m.keyCode) }
        for k in keys { try await keyDown(code: k.rawValue) }
        try await Task.sleep(nanoseconds: 30_000_000)
        for k in keys.reversed() { try await keyUp(code: k.rawValue) }
        for m in modifiers.reversed() { try await keyUp(code: m.keyCode) }
    }
}

// MARK: - Concrete Driver  ▸───────────────────────────────────────────────

public actor RealCGEventDriver: CGEventDriver {
    
    public init() {}
    
    // Cursor Move
    public func moveCursor(to p: Point) async throws {
        guard let e = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: p.x, y: p.y), mouseButton: .left) else {
            throw PilotError.eventCreationFailed
        }
        e.post(tap: .cghidEventTap)
    }
    
    // Mouse Down / Up
    public func mouseDown(button: MouseButton, at p: Point) async throws {
        try postMouse(type: button.downType, button: button, at: p)
    }
    
    public func mouseUp(button: MouseButton, at p: Point) async throws {
        try postMouse(type: button.upType, button: button, at: p)
    }
    
    // Scroll (pixel‑based, smooth)
    public func scroll(deltaX: Double, deltaY: Double, at p: Point) async throws {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0) else {
            throw PilotError.eventCreationFailed
        }
        event.location = CGPoint(x: p.x, y: p.y)
        event.post(tap: .cghidEventTap)
    }
    
    // Key Down / Up
    public func keyDown(code: CGKeyCode) async throws {
        try postKey(code: code, down: true)
    }
    
    public func keyUp(code: CGKeyCode) async throws {
        try postKey(code: code, down: false)
    }
    
    // High‑level type (comprehensive character support with proper shift handling)
    public func type(_ text: String) async throws {
        for c in text {
            if let key = VirtualKey.keyCode(for: c) {
                let needsShift = VirtualKey.requiresShift(for: c)
                if needsShift { try await keyDown(code: ModifierKey.shift.keyCode) }
                try await keyDown(code: key); try await keyUp(code: key)
                if needsShift { try await keyUp(code: ModifierKey.shift.keyCode) }
            }
            try await Task.sleep(nanoseconds: 40_000_000)
        }
    }
    
    // MARK: - Helpers
    private func postMouse(type: CGEventType, button: MouseButton, at p: Point) throws {
        guard let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: CGPoint(x: p.x, y: p.y), mouseButton: button.cgButton) else {
            throw PilotError.eventCreationFailed
        }
        e.post(tap: .cghidEventTap)
    }
    
    private func postKey(code: CGKeyCode, down: Bool) throws {
        guard let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else {
            throw PilotError.eventCreationFailed
        }
        e.post(tap: .cghidEventTap)
    }
    
}
