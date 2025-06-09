import Foundation
import CoreGraphics

// MARK: - Core Identifiers (v3.0 - Handle-based)

/// A handle representing an application that can be automated
/// 
/// `AppHandle` provides a stable identifier for applications that persists across
/// automation operations. Use this handle to reference applications when working
/// with windows and UI elements.
/// 
/// ```swift
/// let app = try await pilot.findApplication(name: "Safari")
/// let windows = try await pilot.listWindows(app: app)
/// ```
public struct AppHandle: Hashable, Sendable, Codable {
    /// The unique identifier for this application
    public let id: String
    
    /// Creates a new application handle
    /// - Parameter id: The unique identifier for the application
    public init(id: String) {
        self.id = id
    }
}

/// A handle representing a window that can be automated
/// 
/// `WindowHandle` provides a stable identifier for windows that persists across
/// automation operations. Use this handle to reference windows when working
/// with UI elements.
/// 
/// ```swift
/// let window = try await pilot.findWindow(app: app, title: "Untitled")
/// let buttons = try await pilot.findElements(in: window, role: .button)
/// ```
public struct WindowHandle: Hashable, Sendable, Codable {
    /// The unique identifier for this window
    public let id: String
    
    /// Creates a new window handle
    /// - Parameter id: The unique identifier for the window
    public init(id: String) {
        self.id = id
    }
}

// MARK: - Legacy Support (Internal Use)

internal struct AppID: Hashable, Sendable {
    internal let pid: pid_t
    
    internal init(pid: pid_t) {
        self.pid = pid
    }
}

internal struct WindowID: Hashable, Sendable {
    internal let id: CGWindowID
    
    internal init(id: CGWindowID) {
        self.id = id
    }
}

// MARK: - Geometry

/// A point in screen coordinates
/// 
/// `Point` represents a location on the screen using macOS screen coordinates.
/// The origin (0,0) is at the bottom-left of the primary display.
/// 
/// ```swift
/// let point = Point(x: 100, y: 200)
/// try await pilot.click(window: window, at: point)
/// ```
public struct Point: Sendable, Equatable, Codable {
    /// The x-coordinate in screen coordinates
    public let x: CGFloat
    /// The y-coordinate in screen coordinates
    public let y: CGFloat
    
    /// Creates a point with CGFloat coordinates
    /// - Parameters:
    ///   - x: The x-coordinate
    ///   - y: The y-coordinate
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    /// Creates a point with Double coordinates
    /// - Parameters:
    ///   - x: The x-coordinate
    ///   - y: The y-coordinate
    public init(x: Double, y: Double) {
        self.x = CGFloat(x)
        self.y = CGFloat(y)
    }
}

// MARK: - Input Types

/// Mouse button types for click operations
/// 
/// Represents the different mouse buttons that can be used for clicking operations.
/// 
/// ```swift
/// try await pilot.click(window: window, at: point, button: .right)
/// ```
public enum MouseButton: Sendable {
    /// The left mouse button (primary click)
    case left
    /// The right mouse button (secondary click, context menu)
    case right
    /// The center mouse button (middle click, scroll wheel)
    case center
    
    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }
    
    var downType: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .center: return .otherMouseDown
        }
    }
    
    var upType: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .center: return .otherMouseUp
        }
    }
    
    var dragType: CGEventType {
        switch self {
        case .left: return .leftMouseDragged
        case .right: return .rightMouseDragged
        case .center: return .otherMouseDragged
        }
    }
}

// MARK: - UI Element System (v3.0)

/// A UI element discovered through the Accessibility API
/// 
/// `UIElement` represents a user interface element (button, text field, etc.) that can be
/// automated. Elements are discovered using the Accessibility API and contain information
/// about their role, position, and properties.
/// 
/// ```swift
/// let button = try await pilot.findButton(in: window, title: "Submit")
/// try await pilot.click(element: button)
/// ```
public struct UIElement: Sendable, Codable {
    /// Unique identifier for this element
    public let id: String
    /// The accessibility role of this element (button, text field, etc.)
    public let role: ElementRole
    /// The title or label text of this element
    public let title: String?
    /// The current value of this element (text content, checkbox state, etc.)
    public let value: String?
    /// The accessibility identifier assigned to this element
    public let identifier: String?
    /// The screen bounds of this element
    public let bounds: CGRect
    /// Whether this element is currently enabled for interaction
    public let isEnabled: Bool
    
    /// The center point of this element in screen coordinates
    /// 
    /// This computed property automatically calculates the center point from the element's bounds,
    /// which is useful for click operations.
    public var centerPoint: Point {
        Point(x: bounds.midX, y: bounds.midY)
    }
    
    public init(
        id: String,
        role: ElementRole,
        title: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        bounds: CGRect,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.value = value
        self.identifier = identifier
        self.bounds = bounds
        self.isEnabled = isEnabled
    }
}

/// UI element roles from the Accessibility API
/// 
/// `ElementRole` represents the different types of UI elements that can be discovered
/// and automated. These correspond to standard accessibility roles.
/// 
/// ```swift
/// // Find all buttons in a window
/// let buttons = try await pilot.findElements(in: window, role: .button)
/// 
/// // Find text input fields
/// let textFields = try await pilot.findElements(in: window, role: .textField)
/// ```
public enum ElementRole: String, Sendable, CaseIterable, Codable {
    /// A clickable button element
    case button = "AXButton"
    /// A text input field
    case textField = "AXTextField"
    /// A search input field
    case searchField = "AXSearchField"
    /// A menu item
    case menuItem = "AXMenuItem"
    /// A menu bar container
    case menuBar = "AXMenuBar"
    /// A menu bar item
    case menuBarItem = "AXMenuBarItem"
    /// A checkbox element
    case checkBox = "AXCheckBox"
    /// A radio button element
    case radioButton = "AXRadioButton"
    /// A clickable link
    case link = "AXLink"
    /// A tab in a tab control
    case tab = "AXTab"
    /// A window element
    case window = "AXWindow"
    /// Static text that cannot be edited
    case staticText = "AXStaticText"
    /// A grouping container element
    case group = "AXGroup"
    /// A scrollable area
    case scrollArea = "AXScrollArea"
    /// An image element
    case image = "AXImage"
    /// A list container
    case list = "AXList"
    /// A table element
    case table = "AXTable"
    /// A table cell
    case cell = "AXCell"
    /// A popup button/dropdown
    case popUpButton = "AXPopUpButton"
    /// A slider control
    case slider = "AXSlider"
    /// An unknown or unsupported element type
    case unknown = "AXUnknown"
    
    /// Whether this element type can typically be clicked
    /// 
    /// Returns `true` for interactive elements like buttons, links, and form controls.
    public var isClickable: Bool {
        switch self {
        case .button, .menuItem, .menuBarItem, .checkBox, .radioButton, .link, .tab, .popUpButton:
            return true
        default:
            return false
        }
    }
    
    /// Whether this element type accepts text input
    /// 
    /// Returns `true` for text fields and search fields.
    public var isTextInput: Bool {
        switch self {
        case .textField, .searchField:
            return true
        default:
            return false
        }
    }
}

// MARK: - Wait Specifications (v3.0)

/// Specifications for wait operations
/// 
/// `WaitSpec` defines different types of conditions that AppPilot can wait for.
/// These are used with the `wait(_:)` method to pause execution until specific
/// conditions are met.
/// 
/// ```swift
/// // Wait for a specific time
/// try await pilot.wait(.time(seconds: 2.0))
/// 
/// // Wait for an element to appear
/// try await pilot.wait(.elementAppear(window: window, role: .button, title: "Submit"))
/// ```
public enum WaitSpec: Sendable {
    /// Wait for a specific duration
    case time(seconds: TimeInterval)
    /// Wait for a UI element to appear
    case elementAppear(window: WindowHandle, role: ElementRole, title: String)
    /// Wait for a UI element to disappear
    case elementDisappear(window: WindowHandle, role: ElementRole, title: String)
    /// Wait for any UI change in a window
    case uiChange(window: WindowHandle, timeout: TimeInterval)
}

// MARK: - UI Tree Structure

/// Hierarchical representation of UI elements
/// 
/// `UIElementTree` represents the accessibility tree structure of a window,
/// allowing for programmatic analysis of UI hierarchy and relationships.
public struct UIElementTree: Sendable, Codable {
    /// The UI element at this node
    public let element: UIElement
    /// Child elements in the tree
    public let children: [UIElementTree]
    /// Depth level in the tree (0 = root)
    public let depth: Int
    
    public init(element: UIElement, children: [UIElementTree] = [], depth: Int = 0) {
        self.element = element
        self.children = children
        self.depth = depth
    }
    
    /// Convert tree to readable string format
    /// 
    /// Returns a formatted string representation of the UI tree with indentation
    /// showing the hierarchy and all element properties.
    /// 
    /// ```swift
    /// let tree = try await pilot.getUITree(for: window)
    /// print(tree.toString())
    /// ```
    public func toString() -> String {
        var result = ""
        appendToString(&result, indentLevel: 0)
        return result
    }
    
    /// Convert tree to compact summary format
    /// 
    /// Returns a condensed view showing only interactive elements and their key properties.
    public func toSummary() -> String {
        var result = "UI Tree Summary:\n"
        appendSummaryToString(&result, indentLevel: 0)
        return result
    }
    
    private func appendToString(_ result: inout String, indentLevel: Int) {
        let indent = String(repeating: "  ", count: indentLevel)
        let title = element.title ?? "nil"
        let value = element.value ?? "nil"
        let identifier = element.identifier ?? "nil"
        let bounds = "(\(Int(element.bounds.minX)), \(Int(element.bounds.minY)), \(Int(element.bounds.width))x\(Int(element.bounds.height)))"
        
        result += "\(indent)[\(element.role.rawValue)] title='\(title)' value='\(value)' id='\(identifier)' bounds=\(bounds) enabled=\(element.isEnabled)\n"
        
        for child in children {
            child.appendToString(&result, indentLevel: indentLevel + 1)
        }
    }
    
    private func appendSummaryToString(_ result: inout String, indentLevel: Int) {
        let indent = String(repeating: "  ", count: indentLevel)
        
        // Only show interactive or meaningful elements
        let isImportant = element.role.isClickable || 
                         element.role.isTextInput || 
                         !element.title.isNilOrEmpty ||
                         !element.value.isNilOrEmpty ||
                         element.role == .window ||
                         element.role == .group
        
        if isImportant {
            let title = element.title?.truncated(to: 30) ?? ""
            let value = element.value?.truncated(to: 20) ?? ""
            let roleDisplay = element.role.displayName
            
            var parts: [String] = [roleDisplay]
            if !title.isEmpty { parts.append("'\(title)'") }
            if !value.isEmpty { parts.append("value: '\(value)'") }
            if !element.isEnabled { parts.append("(disabled)") }
            
            result += "\(indent)\(parts.joined(separator: " "))\n"
        }
        
        for child in children {
            child.appendSummaryToString(&result, indentLevel: indentLevel + (isImportant ? 1 : 0))
        }
    }
    
    /// Find all elements matching a condition in the tree
    public func findElements(where condition: (UIElement) -> Bool) -> [UIElement] {
        var results: [UIElement] = []
        
        if condition(element) {
            results.append(element)
        }
        
        for child in children {
            results.append(contentsOf: child.findElements(where: condition))
        }
        
        return results
    }
    
    /// Get all clickable elements in the tree
    public var clickableElements: [UIElement] {
        return findElements { $0.role.isClickable && $0.isEnabled }
    }
    
    /// Get all text input elements in the tree
    public var textInputElements: [UIElement] {
        return findElements { $0.role.isTextInput && $0.isEnabled }
    }
}

// MARK: - Extensions

extension String? {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}

extension String {
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + "..."
    }
}

extension ElementRole {
    var displayName: String {
        switch self {
        case .button: return "Button"
        case .textField: return "TextField" 
        case .searchField: return "SearchField"
        case .menuItem: return "MenuItem"
        case .menuBar: return "MenuBar"
        case .menuBarItem: return "MenuBarItem"
        case .checkBox: return "CheckBox"
        case .radioButton: return "RadioButton"
        case .link: return "Link"
        case .tab: return "Tab"
        case .window: return "Window"
        case .staticText: return "Text"
        case .group: return "Group"
        case .scrollArea: return "ScrollArea"
        case .image: return "Image"
        case .list: return "List"
        case .table: return "Table"
        case .cell: return "Cell"
        case .popUpButton: return "PopUpButton"
        case .slider: return "Slider"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Result Types (v3.0)

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
    public let element: UIElement?
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
    public init(success: Bool, timestamp: Date = Date(), element: UIElement? = nil, coordinates: Point? = nil, data: ActionResultData? = nil) {
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

// MARK: - Application Info (v3.0)

/// Information about a running application
/// 
/// `AppInfo` contains metadata about applications that can be automated,
/// including their name, bundle identifier, and current state.
/// 
/// ```swift
/// let apps = try await pilot.listApplications()
/// for app in apps {
///     print("App: \(app.name) (\(app.bundleIdentifier ?? "unknown"))")
/// }
/// ```
public struct AppInfo: Sendable, Codable {
    /// Handle for referencing this application
    public let id: AppHandle
    /// Display name of the application
    public let name: String
    /// Bundle identifier (e.g., "com.apple.safari")
    public let bundleIdentifier: String?
    /// Whether this application is currently the frontmost/active app
    public let isActive: Bool
    
    /// Creates application information
    /// 
    /// - Parameters:
    ///   - id: Handle for this application
    ///   - name: Display name
    ///   - bundleIdentifier: Bundle identifier, if available
    ///   - isActive: Whether the app is currently active
    public init(id: AppHandle, name: String, bundleIdentifier: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
    }
}

// MARK: - Window Info (v3.0)

/// Information about an application window
/// 
/// `WindowInfo` contains metadata about windows that can be automated,
/// including their title, position, and visibility state.
/// 
/// ```swift
/// let windows = try await pilot.listWindows(app: app)
/// for window in windows where window.isVisible {
///     print("Window: \(window.title ?? "Untitled") at \(window.bounds)")
/// }
/// ```
public struct WindowInfo: Sendable, Codable {
    /// Handle for referencing this window
    public let id: WindowHandle
    /// Title of the window, if any
    public let title: String?
    /// Screen bounds of the window in screen coordinates
    public let bounds: CGRect
    /// Whether the window is currently visible
    public let isVisible: Bool
    /// Whether this is the main window of the application
    public let isMain: Bool
    /// Name of the application that owns this window
    public let appName: String
    /// ScreenCaptureKit window ID for direct window capture
    public let windowID: UInt32?
    
    /// Creates window information
    /// 
    /// - Parameters:
    ///   - id: Handle for this window
    ///   - title: Window title, if any
    ///   - bounds: Screen bounds
    ///   - isVisible: Whether the window is visible
    ///   - isMain: Whether this is the main window
    ///   - appName: Name of the owning application
    ///   - windowID: ScreenCaptureKit window ID for direct capture
    public init(id: WindowHandle, title: String?, bounds: CGRect, isVisible: Bool, isMain: Bool, appName: String, windowID: UInt32? = nil) {
        self.id = id
        self.title = title
        self.bounds = bounds
        self.isVisible = isVisible
        self.isMain = isMain
        self.appName = appName
        self.windowID = windowID
    }
}

// MARK: - Input Source Types

public enum InputSource: String, Sendable, CaseIterable, Codable {
    case english = "com.apple.keylayout.ABC"
    case japanese = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"
    case japaneseHiragana = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
    case chinesePinyin = "com.apple.inputmethod.SCIM.ITABC"
    case chineseTraditional = "com.apple.inputmethod.TCIM.Cangjie"
    case koreanIM = "com.apple.inputmethod.Korean.2SetKorean"
    case automatic = "automatic"  // Don't change current input source
    
    public var displayName: String {
        switch self {
        case .english: return "English (ABC)"
        case .japanese: return "Japanese (Romaji)"
        case .japaneseHiragana: return "Japanese (Hiragana)"
        case .chinesePinyin: return "Chinese (Pinyin)"
        case .chineseTraditional: return "Chinese (Traditional)"
        case .koreanIM: return "Korean (2-Set)"
        case .automatic: return "Automatic"
        }
    }
    
    public var isJapanese: Bool {
        return self == .japanese || self == .japaneseHiragana
    }
    
    public var isChinese: Bool {
        return self == .chinesePinyin || self == .chineseTraditional
    }
    
    public var isKorean: Bool {
        return self == .koreanIM
    }
}

public struct InputSourceInfo: Sendable {
    public let identifier: String
    public let displayName: String
    public let isActive: Bool
    
    public init(identifier: String, displayName: String, isActive: Bool) {
        self.identifier = identifier
        self.displayName = displayName
        self.isActive = isActive
    }
}

// MARK: - AX Event Types

public struct AXEvent: Sendable {
    public enum EventType: Sendable {
        case created
        case moved
        case resized
        case titleChanged
        case focusChanged
        case valueChanged
        case elementAppeared
        case elementDisappeared
        case overflow
    }
    
    public let type: EventType
    public let windowHandle: WindowHandle
    public let element: UIElement?
    public let timestamp: Date
    public let description: String?
    
    public init(type: EventType, windowHandle: WindowHandle, element: UIElement? = nil, timestamp: Date = Date(), description: String? = nil) {
        self.type = type
        self.windowHandle = windowHandle
        self.element = element
        self.timestamp = timestamp
        self.description = description
    }
}

public struct AXMask: OptionSet, Sendable {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let created = AXMask(rawValue: 1 << 0)
    public static let moved = AXMask(rawValue: 1 << 1)
    public static let resized = AXMask(rawValue: 1 << 2)
    public static let titleChanged = AXMask(rawValue: 1 << 3)
    public static let focusChanged = AXMask(rawValue: 1 << 4)
    public static let valueChanged = AXMask(rawValue: 1 << 5)
    
    public static let all: AXMask = [.created, .moved, .resized, .titleChanged, .focusChanged, .valueChanged]
}


public typealias PNGData = Data

// MARK: - Composition Input Types (IME Support)

/// Represents the style/method of composition input
public struct InputMethodStyle: RawRepresentable, Sendable, Hashable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    // Japanese input styles
    public static let japaneseRomaji = InputMethodStyle(rawValue: "ja-romaji")
    public static let japaneseKana = InputMethodStyle(rawValue: "ja-kana")
    public static let japaneseNicola = InputMethodStyle(rawValue: "ja-nicola")
    
    // Chinese input styles
    public static let chinesePinyin = InputMethodStyle(rawValue: "zh-pinyin")
    public static let chineseZhuyin = InputMethodStyle(rawValue: "zh-zhuyin")
    public static let chineseCangjie = InputMethodStyle(rawValue: "zh-cangjie")
    public static let chineseWubi = InputMethodStyle(rawValue: "zh-wubi")
    
    // Korean input styles
    public static let koreanStandard = InputMethodStyle(rawValue: "ko-standard")
    
    // Vietnamese input styles
    public static let vietnameseTelex = InputMethodStyle(rawValue: "vi-telex")
    
    // Arabic input styles
    public static let arabicStandard = InputMethodStyle(rawValue: "ar-standard")
}

/// Represents a composition input method with language and style
public struct CompositionType: RawRepresentable, Sendable, Hashable, Codable {
    public let rawValue: String
    public let style: InputMethodStyle?
    
    public init(rawValue: String, style: InputMethodStyle? = nil) {
        self.rawValue = rawValue
        self.style = style
    }
    
    // RawRepresentable protocol conformance
    public init?(rawValue: String) {
        self.rawValue = rawValue
        self.style = nil
    }
    
    // Convenience constructors
    public static func japanese(_ style: InputMethodStyle) -> CompositionType {
        return CompositionType(rawValue: "japanese", style: style)
    }
    
    public static func chinese(_ style: InputMethodStyle) -> CompositionType {
        return CompositionType(rawValue: "chinese", style: style)
    }
    
    public static func korean(_ style: InputMethodStyle) -> CompositionType {
        return CompositionType(rawValue: "korean", style: style)
    }
    
    // Predefined common combinations
    public static let japaneseRomaji = CompositionType.japanese(.japaneseRomaji)
    public static let japaneseKana = CompositionType.japanese(.japaneseKana)
    public static let chinesePinyin = CompositionType.chinese(.chinesePinyin)
    public static let korean = CompositionType.korean(.koreanStandard)
}

/// The current state of composition input
public enum CompositionInputState: Sendable, Codable {
    /// Text is being composed but not yet converted
    case composing(text: String, suggestions: [String])
    /// User is selecting from conversion candidates
    case candidateSelection(original: String, candidates: [String], selectedIndex: Int)
    /// Input has been committed/finalized
    case committed(text: String)
}

/// Available actions for composition input
public enum CompositionInputAction: Sendable, Codable {
    case selectCandidate(index: Int)
    case nextCandidate
    case previousCandidate
    case commit
    case cancel
    case continueComposing
    case convertToAlternative  // e.g., hiragana → katakana
}

/// Result data for composition input operations
public struct CompositionInputResult: Sendable, Codable {
    /// Current composition state
    public let state: CompositionInputState
    /// The original input text (e.g., romaji)
    public let inputText: String
    /// Currently displayed text
    public let currentText: String
    /// Whether user decision is needed
    public let needsUserDecision: Bool
    /// Available actions for current state
    public let availableActions: [CompositionInputAction]
    /// The composition type used
    public let compositionType: CompositionType
    
    public init(
        state: CompositionInputState,
        inputText: String,
        currentText: String,
        needsUserDecision: Bool = false,
        availableActions: [CompositionInputAction] = [],
        compositionType: CompositionType
    ) {
        self.state = state
        self.inputText = inputText
        self.currentText = currentText
        self.needsUserDecision = needsUserDecision
        self.availableActions = availableActions
        self.compositionType = compositionType
    }
    
    /// Convenience property: available candidates for selection
    public var candidates: [String]? {
        switch state {
        case .candidateSelection(_, let candidates, _):
            return candidates
        case .composing(_, let suggestions):
            return suggestions.isEmpty ? nil : suggestions
        default:
            return nil
        }
    }
    
    /// Convenience property: currently selected candidate index
    public var selectedCandidateIndex: Int? {
        if case .candidateSelection(_, _, let index) = state {
            return index
        }
        return nil
    }
    
    /// Convenience property: whether composition is completed
    public var isCompleted: Bool {
        if case .committed = state {
            return true
        }
        return false
    }
}