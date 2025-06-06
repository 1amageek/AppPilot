import Foundation
import ApplicationServices
@testable import AppPilot

public actor MockAccessibilityDriver: AccessibilityDriver {
    public var observeEventsCalls: [(WindowID, AXMask)] = []
    public var hasPermission: Bool = true
    
    public init() {}
    
    public func observeEvents(for window: WindowID, mask: AXMask) async -> AsyncStream<AXEvent> {
        observeEventsCalls.append((window, mask))
        
        return AsyncStream<AXEvent> { continuation in
            Task {
                continuation.yield(AXEvent(
                    type: .created,
                    windowID: window,
                    description: "Mock AX event for testing"
                ))
                continuation.finish()
            }
        }
    }
    
    public func checkPermission() async -> Bool {
        return hasPermission
    }
    
    public func reset() {
        observeEventsCalls.removeAll()
    }
}