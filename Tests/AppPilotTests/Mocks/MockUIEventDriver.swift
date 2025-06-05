import Foundation
import CoreGraphics
@testable import AppPilot

public actor MockUIEventDriver: UIEventDriver {
    private var callHistory: [UIEventCallRecord] = []
    private var failureMode: UIEventFailureMode = .none
    
    public init() {}
    
    // MARK: - Configuration Methods
    
    public func setFailureMode(_ mode: UIEventFailureMode) {
        failureMode = mode
    }
    
    // MARK: - Call History and Verification
    
    public func getCallHistory() -> [UIEventCallRecord] {
        return callHistory
    }
    
    public func getClickEvents() -> [(point: CGPoint, button: MouseButton, count: Int, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .click(let point, let button, let count) = record.call {
                return (point, button, count, record.timestamp)
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
    
    public func getGestureEvents() -> [(gesture: Gesture, durationMs: Int, timestamp: Date)] {
        return callHistory.compactMap { record in
            if case .gesture(let gesture, let duration) = record.call {
                return (gesture, duration, record.timestamp)
            }
            return nil
        }
    }
    
    public func getCallCount(for method: String) -> Int {
        return callHistory.filter { $0.call.methodName == method }.count
    }
    
    public func clearHistory() {
        callHistory.removeAll()
    }
    
    // MARK: - Performance Analysis
    
    public func getTimingStats() -> UIEventTimingStats {
        let timings = callHistory.map { record in
            record.duration
        }
        
        guard !timings.isEmpty else {
            return UIEventTimingStats(average: 0, min: 0, max: 0, count: 0)
        }
        
        let average = timings.reduce(0, +) / Double(timings.count)
        let min = timings.min() ?? 0
        let max = timings.max() ?? 0
        
        return UIEventTimingStats(
            average: average,
            min: min,
            max: max,
            count: timings.count
        )
    }
    
    // MARK: - UIEventDriver Implementation
    
    public func click(at point: CGPoint, button: MouseButton, count: Int) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        
        let endTime = Date()
        let record = UIEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .click(point: point, button: button, count: count)
        )
        callHistory.append(record)
    }
    
    public func type(text: String) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        
        let endTime = Date()
        let record = UIEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .type(text: text)
        )
        callHistory.append(record)
    }
    
    public func keyPress(key: String, modifiers: CGEventFlags) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        
        let endTime = Date()
        let record = UIEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .keyPress(key: key, modifiers: modifiers)
        )
        callHistory.append(record)
    }
    
    public func gesture(_ gesture: Gesture, durationMs: Int) async throws {
        let startTime = Date()
        
        try await applyFailureMode()
        
        let endTime = Date()
        let record = UIEventCallRecord(
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            call: .gesture(gesture: gesture, durationMs: durationMs)
        )
        callHistory.append(record)
    }
    
    // MARK: - Failure Mode Implementation
    
    private func applyFailureMode() async throws {
        switch failureMode {
        case .none:
            break
        case .simulateDelay(let duration):
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        case .osFailure(let api, let status):
            throw PilotError.OS_FAILURE(api: api, status: Int32(status))
        case .securityBlocked:
            throw PilotError.PERMISSION_DENIED(.appleEvents)
        }
    }
}

// MARK: - Supporting Types

public struct UIEventCallRecord: Sendable {
    public let timestamp: Date
    public let duration: TimeInterval
    public let call: UIEventCall
}

public enum UIEventCall: Sendable {
    case click(point: CGPoint, button: MouseButton, count: Int)
    case type(text: String)
    case keyPress(key: String, modifiers: CGEventFlags)
    case gesture(gesture: Gesture, durationMs: Int)
    
    public var methodName: String {
        switch self {
        case .click: return "click"
        case .type: return "type"
        case .keyPress: return "keyPress"
        case .gesture: return "gesture"
        }
    }
}

public enum UIEventFailureMode: Sendable {
    case none
    case simulateDelay(duration: TimeInterval)
    case osFailure(api: String, status: Int32)
    case securityBlocked
}

public struct UIEventTimingStats: Sendable {
    public let average: TimeInterval
    public let min: TimeInterval
    public let max: TimeInterval
    public let count: Int
}