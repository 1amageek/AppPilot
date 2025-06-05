import Foundation
import ApplicationServices
@testable import AppPilot

public actor MockAccessibilityDriver: AccessibilityDriver {
    private var canPerformResponse = false
    private var mockTree = AXNode(role: "window", title: "Mock Window", value: nil, frame: nil, children: [])
    private var callHistory: [MockCallRecord] = []
    private var failureMode: MockFailureMode = .none
    private var pathRegistry: [String: AXPath] = [:]
    
    public init() {}
    
    // MARK: - Configuration Methods
    
    public func setCanPerform(_ value: Bool) {
        canPerformResponse = value
    }
    
    public func setMockTree(_ tree: AXNode) {
        mockTree = tree
    }
    
    public func setFailureMode(_ mode: MockFailureMode) {
        failureMode = mode
    }
    
    public func registerPath(_ cssSelector: String, path: AXPath) {
        pathRegistry[cssSelector] = path
    }
    
    // MARK: - Call History and Verification
    
    public func getCallHistory() -> [MockCallRecord] {
        return callHistory
    }
    
    public func getPerformedActions() -> [(action: AXAction, path: AXPath, window: WindowID)] {
        return callHistory.compactMap { record in
            if case .performAction(let action, let path, let window) = record.call {
                return (action, path, window)
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
    
    // MARK: - CSS-like Path Resolution
    
    public func resolvePath(_ cssSelector: String) throws -> AXPath {
        if let registeredPath = pathRegistry[cssSelector] {
            return registeredPath
        }
        
        // Simple CSS-like selector parsing
        let components = cssSelector.components(separatedBy: " ")
        var path = AXPath(components: [])
        
        for component in components {
            if component.hasPrefix("button[") && component.hasSuffix("]") {
                let attribute = String(component.dropFirst(7).dropLast(1))
                if attribute.hasPrefix("title=") {
                    let title = String(attribute.dropFirst(7).dropFirst(1).dropLast(1))
                    path = try findButtonWithTitle(title, in: mockTree)
                }
            } else if component == "textfield" {
                path = try findFirstTextfield(in: mockTree)
            }
        }
        
        return path
    }
    
    private func findButtonWithTitle(_ title: String, in node: AXNode) throws -> AXPath {
        // Simple mock implementation - in real version would traverse tree
        return AXPath(components: ["0", "1"]) // Mock path
    }
    
    private func findFirstTextfield(in node: AXNode) throws -> AXPath {
        return AXPath(components: ["0", "2"]) // Mock path
    }
    
    // MARK: - AccessibilityDriver Implementation
    
    public func getTree(for window: WindowID, depth: Int) async throws -> AXNode {
        let record = MockCallRecord(
            timestamp: Date(),
            call: .getTree(window: window, depth: depth)
        )
        callHistory.append(record)
        
        try await applyFailureMode()
        return mockTree
    }
    
    public func performAction(_ action: AXAction, at path: AXPath, in window: WindowID) async throws {
        let record = MockCallRecord(
            timestamp: Date(),
            call: .performAction(action: action, path: path, window: window)
        )
        callHistory.append(record)
        
        try await applyFailureMode()
    }
    
    public func canPerform(_ command: Command, in window: WindowID) async -> Bool {
        let record = MockCallRecord(
            timestamp: Date(),
            call: .canPerform(command: command, window: window)
        )
        callHistory.append(record)
        
        return canPerformResponse
    }
    
    public func setValue(_ value: String, at path: AXPath, in window: WindowID) async throws {
        let record = MockCallRecord(
            timestamp: Date(),
            call: .setValue(value: value, path: path, window: window)
        )
        callHistory.append(record)
        
        try await applyFailureMode()
    }
    
    public func observeEvents(for window: WindowID, mask: AXMask) async -> AsyncStream<AXEvent> {
        let record = MockCallRecord(
            timestamp: Date(),
            call: .observeEvents(window: window, mask: mask)
        )
        callHistory.append(record)
        
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    // MARK: - Failure Mode Implementation
    
    private func applyFailureMode() async throws {
        switch failureMode {
        case .none:
            break
        case .timeout(let duration):
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            throw PilotError.TIMEOUT(ms: Int(duration * 1000))
        case .osFailure(let api, let status):
            throw PilotError.OS_FAILURE(api: api, status: Int32(status))
        case .accessDenied:
            throw PilotError.PERMISSION_DENIED(.accessibility)
        }
    }
}

// MARK: - Supporting Types

public struct MockCallRecord: Sendable {
    public let timestamp: Date
    public let call: MockCall
}

public enum MockCall: Sendable {
    case getTree(window: WindowID, depth: Int)
    case performAction(action: AXAction, path: AXPath, window: WindowID)
    case canPerform(command: Command, window: WindowID)
    case setValue(value: String, path: AXPath, window: WindowID)
    case observeEvents(window: WindowID, mask: AXMask)
    
    public var methodName: String {
        switch self {
        case .getTree: return "getTree"
        case .performAction: return "performAction"
        case .canPerform: return "canPerform"
        case .setValue: return "setValue"
        case .observeEvents: return "observeEvents"
        }
    }
}

public enum MockFailureMode: Sendable {
    case none
    case timeout(after: TimeInterval)
    case osFailure(api: String, status: Int32)
    case accessDenied
}