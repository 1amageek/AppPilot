import Foundation

// MARK: - Wait Specifications

/// Specifications for wait operations
/// 
/// `WaitSpec` defines different types of conditions that AppPilot can wait for.
/// These are used with the `wait(_:)` method to pause execution until specific
/// conditions are met.
/// 
/// ```swift
/// // Wait for a specific time
/// try await pilot.wait(.time(seconds: 2.0))
/// ```
public enum WaitSpec: Sendable {
    /// Wait for a specific duration
    case time(seconds: TimeInterval)
    /// Wait for any UI change in a window
    case uiChange(window: WindowHandle, timeout: TimeInterval)
}