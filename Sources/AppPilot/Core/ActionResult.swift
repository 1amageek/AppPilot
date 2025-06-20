import Foundation
import AXUI

// MARK: - Result Types

/// Action-specific data for different types of operations
/// 
/// `ActionResultData` contains specific information about different automation actions,
/// providing type-safe access to action-specific details.
public enum ActionResultData: Sendable, Codable {
    /// Click operation data
    case click
    /// Type operation data
    case type(inputText: String, actualText: String?, inputSource: InputSource?, composition: CompositionInputResult?)
    /// Direct value setting operation data
    case setValue(inputValue: String, actualValue: String?)
    /// Drag operation data
    case drag(startPoint: Point, endPoint: Point, duration: TimeInterval)
    /// Scroll operation data
    case scroll(deltaX: Double, deltaY: Double)
    /// Key press operation data
    case keyPress(keys: [String], modifiers: [String])
    /// Wait operation data
    case wait(duration: TimeInterval)
}

/// Result of an automation action
/// 
/// `ActionResult` contains information about the outcome of an automation operation,
/// including whether it succeeded and any relevant details.
/// 
/// ```swift
/// let result = try await pilot.click(element: button)
/// if result.success {
///     print("Button clicked at \(result.coordinates!)")
/// }
/// 
/// // For type operations
/// let typeResult = try await pilot.input(text: "Hello", into: textField)
/// if case .type(let inputText, let actualText, _, let composition) = typeResult.data {
///     print("Typed: \(inputText), Actual: \(actualText ?? "unknown")")
///     if let comp = composition {
///         print("Composition state: \(comp.state)")
///     }
/// }
/// ```
public struct ActionResult: Sendable, Codable {
    /// Whether the action completed successfully
    public let success: Bool
    /// When the action was performed
    public let timestamp: Date
    /// The UI element involved in the action, if any
    public let element: AXElement?
    /// The screen coordinates where the action occurred, if applicable
    public let coordinates: Point?
    /// Action-specific data
    public let data: ActionResultData?
    
    /// Creates a new action result
    /// 
    /// - Parameters:
    ///   - success: Whether the action succeeded
    ///   - timestamp: When the action occurred (defaults to now)
    ///   - element: The UI element involved, if any
    ///   - coordinates: The coordinates where the action occurred, if applicable
    ///   - data: Action-specific data, if any
    public init(success: Bool, timestamp: Date = Date(), element: AXElement? = nil, coordinates: Point? = nil, data: ActionResultData? = nil) {
        self.success = success
        self.timestamp = timestamp
        self.element = element
        self.coordinates = coordinates
        self.data = data
    }
}

// MARK: - ActionResult Extensions

public extension ActionResult {
    
    /// Type operation data, if this result represents a type action
    var typeData: (inputText: String, actualText: String?, inputSource: InputSource?, composition: CompositionInputResult?)? {
        if case .type(let input, let actual, let source, let comp) = self.data {
            return (input, actual, source, comp)
        }
        return nil
    }
    
    /// Composition input result, if this action involved composition
    var compositionData: CompositionInputResult? {
        return typeData?.composition
    }
    
    /// Whether this was a composition input operation
    var isCompositionInput: Bool {
        return compositionData != nil
    }
    
    /// Whether this was a direct (non-composition) input operation
    var isDirectInput: Bool {
        return typeData != nil && compositionData == nil
    }
    
    /// Whether user decision is needed for composition
    var needsUserDecision: Bool {
        return compositionData?.needsUserDecision ?? false
    }
    
    /// Whether composition input is completed
    var isCompositionCompleted: Bool {
        return compositionData?.isCompleted ?? true
    }
    
    /// Available candidates for composition, if any
    var compositionCandidates: [String]? {
        return compositionData?.candidates
    }
    
    /// Currently selected candidate index, if any
    var selectedCandidateIndex: Int? {
        return compositionData?.selectedCandidateIndex
    }
}