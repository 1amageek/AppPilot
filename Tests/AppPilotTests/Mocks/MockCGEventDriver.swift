import Foundation
import CoreGraphics
@testable import AppPilot

public actor MockCGEventDriver: CGEventDriver {
    private var callHistory: [CGEventCallRecord] = []
    private var failureMode: CGEventFailureMode = .none
    private var simulateDelay: TimeInterval = 0.001 // 1ms default
    
    public init() {}
    
    // MARK: - Configuration Methods
    
    public func setFailureMode(_ mode: CGEventFailureMode) {
        failureMode = mode
    }
    
    public func setSimulateDelay(_ delay: TimeInterval) {
        simulateDelay = delay
    }
    
    // MARK: - Call History and Verification
    
    public func getCallHistory() -> [CGEventCallRecord] {
        return callHistory
    }
    
    public func getMouseDownEvents() -> [(button: MouseButton, point: CGPoint, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .mouseDown(let button, let point) = record.call {
                return (button, point, record.timestamp)
            }
            return nil
        }
    }
    
    public func getMouseUpEvents() -> [(button: MouseButton, point: CGPoint, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .mouseUp(let button, let point) = record.call {
                return (button, point, record.timestamp)
            }
            return nil
        }
    }
    
    public func getMoveCursorEvents() -> [(point: CGPoint, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .moveCursor(let point) = record.call {
                return (point, record.timestamp)
            }
            return nil
        }
    }
    
    public func getScrollEvents() -> [(deltaX: Double, deltaY: Double, point: CGPoint, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .scroll(let deltaX, let deltaY, let point) = record.call {
                return (deltaX, deltaY, point, record.timestamp)
            }
            return nil
        }
    }
    
    public func getKeyDownEvents() -> [(code: CGKeyCode, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .keyDown(let code) = record.call {
                return (code, record.timestamp)
            }
            return nil
        }
    }
    
    public func getKeyUpEvents() -> [(code: CGKeyCode, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .keyUp(let code) = record.call {
                return (code, record.timestamp)
            }
            return nil
        }
    }
    
    public func getTypeEvents() -> [(text: String, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .type(let text) = record.call {
                return (text, record.timestamp)
            }
            return nil
        }
    }
    
    public func clearHistory() {
        callHistory.removeAll()
    }
    
    public func getCallCount(for method: String) -> Int {
        return callHistory.filter { $0.call.methodName == method }.count
    }
    
    // MARK: - Performance Analysis
    
    public func getTimingStats() -> CGEventTimingStats {
        let timings = callHistory.map { $0.duration }
        
        guard !timings.isEmpty else {
            return CGEventTimingStats(average: 0, min: 0, max: 0, count: 0)
        }
        
        let average = timings.reduce(0, +) / Double(timings.count)
        let min = timings.min() ?? 0
        let max = timings.max() ?? 0
        
        return CGEventTimingStats(
            average: average,
            min: min,
            max: max,
            count: timings.count
        )
    }
    
    // MARK: - CGEventDriver Core Implementation
    
    public func moveCursor(to p: Point) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let cgPoint = CGPoint(x: p.x, y: p.y)
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .moveCursor(to: cgPoint)
        )
        callHistory.append(record)
        
        print("🎯 MockCGEventDriver: Move cursor to (\(p.x), \(p.y))")
    }
    
    public func mouseDown(button: MouseButton, at p: Point) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let cgPoint = CGPoint(x: p.x, y: p.y)
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .mouseDown(button: button, at: cgPoint)
        )
        callHistory.append(record)
        
        print("🖱️⬇️ MockCGEventDriver: Mouse down (\(button)) at (\(p.x), \(p.y))")
    }
    
    public func mouseUp(button: MouseButton, at p: Point) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let cgPoint = CGPoint(x: p.x, y: p.y)
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .mouseUp(button: button, at: cgPoint)
        )
        callHistory.append(record)
        
        print("🖱️⬆️ MockCGEventDriver: Mouse up (\(button)) at (\(p.x), \(p.y))")
    }
    
    public func scroll(deltaX: Double, deltaY: Double, at p: Point) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let cgPoint = CGPoint(x: p.x, y: p.y)
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .scroll(deltaX: deltaX, deltaY: deltaY, at: cgPoint)
        )
        callHistory.append(record)
        
        print("📜 MockCGEventDriver: Scroll (deltaX: \(deltaX), deltaY: \(deltaY)) at (\(p.x), \(p.y))")
    }
    
    public func keyDown(code: CGKeyCode) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .keyDown(code: code)
        )
        callHistory.append(record)
        
        print("⌨️⬇️ MockCGEventDriver: Key down (code: \(code))")
    }
    
    public func keyUp(code: CGKeyCode) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .keyUp(code: code)
        )
        callHistory.append(record)
        
        print("⌨️⬆️ MockCGEventDriver: Key up (code: \(code))")
    }
    
    public func type(_ text: String) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        
        let endTime = Date()
        let record = CGEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .type(text: text)
        )
        callHistory.append(record)
        
        print("⌨️ MockCGEventDriver: Type text '\(text)'")
    }
    
    // MARK: - Failure Mode Implementation
    
    private func applyFailureMode() async throws {
        switch failureMode {
        case .none:
            break
        case .eventCreationFailed:
            throw PilotError.eventCreationFailed
        case .accessibilityPermissionDenied:
            throw PilotError.permissionDenied("Accessibility permission required for CGEvent operations")
        case .coordinateOutOfBounds(let point):
            throw PilotError.coordinateOutOfBounds(Point(x: point.x, y: point.y))
        case .simulateDelay(let duration):
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        case .osFailure(let api, let code):
            throw PilotError.osFailure(api: api, code: code)
        }
    }
}

// MARK: - Supporting Types

public struct CGEventCallRecord: Sendable {
    public let timestamp: Date
    public let duration: TimeInterval
    public let call: CGEventCall
}

public enum CGEventCall: Sendable {
    case moveCursor(to: CGPoint)
    case mouseDown(button: MouseButton, at: CGPoint)
    case mouseUp(button: MouseButton, at: CGPoint)
    case scroll(deltaX: Double, deltaY: Double, at: CGPoint)
    case keyDown(code: CGKeyCode)
    case keyUp(code: CGKeyCode)
    case type(text: String)
    
    public var methodName: String {
        switch self {
        case .moveCursor: return "moveCursor"
        case .mouseDown: return "mouseDown"
        case .mouseUp: return "mouseUp"
        case .scroll: return "scroll"
        case .keyDown: return "keyDown"
        case .keyUp: return "keyUp"
        case .type: return "type"
        }
    }
}

public enum CGEventFailureMode: Sendable {
    case none
    case eventCreationFailed
    case accessibilityPermissionDenied
    case coordinateOutOfBounds(CGPoint)
    case simulateDelay(duration: TimeInterval)
    case osFailure(api: String, code: Int32)
}

public struct CGEventTimingStats: Sendable {
    public let average: TimeInterval
    public let min: TimeInterval
    public let max: TimeInterval
    public let count: Int
}