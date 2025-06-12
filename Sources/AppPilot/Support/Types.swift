import Foundation
import CoreGraphics
import AXUI

// MARK: - Core Identifiers

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

// MARK: - UI Element System (AXUI Integration)

/// Re-export AXElement from AXUI for AppPilot compatibility
/// 
/// `AXElement` represents a user interface element (button, text field, etc.) that can be
/// automated. Elements are discovered using the Accessibility API and contain information
/// about their role, position, and properties.
/// 
/// ```swift
/// let button = try await pilot.findButton(in: window, title: "Submit")
/// try await pilot.click(element: button)
/// ```
public typealias UIElement = AXElement

/// UI element roles from the Accessibility API
/// 
/// `ElementRole` represents the different types of UI elements that can be discovered
/// and automated. These correspond to AXUI's normalized accessibility roles.
/// 
/// ```swift
/// // Find all buttons in a window
/// let buttons = try await pilot.findElements(in: window, role: .button)
/// 
/// // Find text input fields
/// let textFields = try await pilot.findElements(in: window, role: .field)
/// ```
public enum ElementRole: String, Sendable, CaseIterable, Codable {
    /// A clickable button element
    case button = "Button"
    /// A text input field (includes textField, searchField, and field types)
    case field = "Field"
    /// A menu item
    case menuItem = "MenuItem"
    /// A menu bar container
    case menuBar = "MenuBar"
    /// A menu bar item
    case menuBarItem = "MenuBarItem"
    /// A checkbox element
    case checkBox = "Check"
    /// A radio button element
    case radioButton = "Radio"
    /// A clickable link
    case link = "Link"
    /// A tab in a tab control
    case tab = "Tab"
    /// A window element
    case window = "Window"
    /// Static text that cannot be edited
    case staticText = "Text"
    /// A grouping container element
    case group = "Group"
    /// A scrollable area
    case scrollArea = "Scroll"
    /// An image element
    case image = "Image"
    /// A list container
    case list = "List"
    /// A table element
    case table = "Table"
    /// A table cell
    case cell = "Cell"
    /// A popup button/dropdown
    case popUpButton = "PopUp"
    /// A slider control
    case slider = "Slider"
    /// A row in a list or outline
    case row = "Row"
    /// An unknown or unsupported element type
    case unknown = "Unknown"
    
    /// Whether this element type can typically be clicked
    /// 
    /// Returns `true` for interactive elements like buttons, links, and form controls.
    public var isClickable: Bool {
        switch self {
        case .button, .menuItem, .menuBarItem, .checkBox, .radioButton, .link, .tab, .popUpButton, .row:
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
        case .field:
            return true
        default:
            return false
        }
    }
}

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
    
    static func randomAlphanumeric(length: Int) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
}

extension ElementRole {
    var displayName: String {
        switch self {
        case .button: return "Button"
        case .field: return "Field"
        case .menuItem: return "MenuItem"
        case .menuBar: return "MenuBar"
        case .menuBarItem: return "MenuBarItem"
        case .checkBox: return "Check"
        case .radioButton: return "Radio"
        case .link: return "Link"
        case .tab: return "Tab"
        case .window: return "Window"
        case .staticText: return "Text"
        case .group: return "Group"
        case .scrollArea: return "Scroll"
        case .image: return "Image"
        case .list: return "List"
        case .table: return "Table"
        case .cell: return "Cell"
        case .popUpButton: return "PopUp"
        case .slider: return "Slider"
        case .row: return "Row"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - AXElement Extensions for AppPilot Compatibility

extension AXElement: @retroactive @unchecked Sendable {
    /// The title or label text of this element (mapped from description)
    public var title: String? {
        return self.description
    }
    
    /// The current value of this element (same as description for consistency)
    public var value: String? {
        return self.description
    }
    
    /// Convert string role to ElementRole enum
    public var elementRole: ElementRole {
        guard let role = self.role else { return .unknown }
        return ElementRole(rawValue: role) ?? .unknown
    }
    
    /// Whether this element is currently enabled for interaction
    public var isEnabled: Bool {
        return self.state?.enabled ?? true  // Default to enabled if not specified
    }
    
    /// Convenience property to check if role is clickable
    public var isClickableElement: Bool {
        guard let role = self.role else { return false }
        return role.isClickableRole
    }
    
    /// Convenience property to check if role is text input
    public var isTextInputElement: Bool {
        guard let role = self.role else { return false }
        return role.isTextInputRole
    }
    
    /// The screen bounds of this element as CGRect
    public var cgBounds: CGRect {
        guard let position = self.position, let size = self.size else {
            return CGRect.zero
        }
        return CGRect(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }
    
    /// The center point of this element in screen coordinates
    /// 
    /// This computed property automatically calculates the center point from the element's bounds,
    /// which is useful for click operations.
    public var centerPoint: Point {
        let bounds = self.cgBounds
        return Point(x: bounds.midX, y: bounds.midY)
    }
}

/// Convert AppPilot Point to AXUI Point
extension Point {
    public var axuiPoint: AXUI.Point {
        return AXUI.Point(x: Double(self.x), y: Double(self.y))
    }
    
    public init(axuiPoint: AXUI.Point) {
        self.init(x: CGFloat(axuiPoint.x), y: CGFloat(axuiPoint.y))
    }
}

/// String-based role checking extensions
extension String {
    /// Whether this role represents a clickable element
    public var isClickableRole: Bool {
        switch self {
        case "Button", "MenuItem", "MenuBarItem", "Check", "Radio", 
             "Link", "Tab", "PopUp", "Row":
            return true
        default:
            return false
        }
    }
    
    /// Whether this role represents a text input element
    public var isTextInputRole: Bool {
        switch self {
        case "Field", "SearchField":
            return true
        default:
            return false
        }
    }
}

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

// MARK: - UI Snapshot

/// A complete snapshot of UI state including window image and element hierarchy
/// 
/// `UISnapshot` captures both the visual state (screenshot) and structural state
/// (UI element tree) of a window at a specific point in time. This is useful for
/// debugging, testing, and analyzing UI state.
/// 
/// ```swift
/// let snapshot = try await pilot.snapshot(window: window)
/// 
/// // Access the screenshot
/// let image = snapshot.image
/// 
/// // Analyze UI elements
/// let buttons = snapshot.elements.filter { $0.role == .button }
/// print("Found \(buttons.count) buttons")
/// 
/// // Find specific element
/// if let submitButton = snapshot.findElement(role: .button, title: "Submit") {
///     print("Submit button at: \(submitButton.bounds)")
/// }
/// ```
public struct UISnapshot: Sendable, Codable {
    /// The window handle this snapshot belongs to
    public let windowHandle: WindowHandle
    
    /// Window information at the time of snapshot
    public let windowInfo: WindowInfo
    
    /// All UI elements discovered in the window
    public let elements: [UIElement]
    
    /// PNG data of the window screenshot
    public let imageData: Data
    
    /// When this snapshot was captured
    public let timestamp: Date
    
    /// Optional metadata about the snapshot
    public let metadata: SnapshotMetadata?
    
    public init(
        windowHandle: WindowHandle,
        windowInfo: WindowInfo,
        elements: [UIElement],
        imageData: Data,
        timestamp: Date = Date(),
        metadata: SnapshotMetadata? = nil
    ) {
        self.windowHandle = windowHandle
        self.windowInfo = windowInfo
        self.elements = elements
        self.imageData = imageData
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    /// Reconstructs the CGImage from stored PNG data
    public var image: CGImage? {
        guard let dataProvider = CGDataProvider(data: imageData as CFData),
              let cgImage = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return cgImage
    }
    
    /// Find element by role and title in the snapshot
    public func findElement(role: ElementRole, title: String? = nil) -> UIElement? {
        elements.first { element in
            element.elementRole == role &&
            (title == nil || element.title?.localizedCaseInsensitiveContains(title!) == true)
        }
    }
    
    /// Find all elements matching criteria
    public func findElements(role: ElementRole? = nil, title: String? = nil) -> [UIElement] {
        elements.filter { element in
            (role == nil || element.elementRole == role) &&
            (title == nil || element.title?.localizedCaseInsensitiveContains(title!) == true)
        }
    }
    
    /// Get elements sorted by their position (top-left to bottom-right)
    public var elementsByPosition: [UIElement] {
        elements.sorted { e1, e2 in
            let bounds1 = e1.cgBounds
            let bounds2 = e2.cgBounds
            if abs(bounds1.minY - bounds2.minY) < 5 {
                return bounds1.minX < bounds2.minX
            }
            return bounds1.minY < bounds2.minY
        }
    }
    
    /// Get clickable elements only
    public var clickableElements: [UIElement] {
        elements.filter { element in
            guard let role = element.role else { return false }
            return role.isClickableRole && element.isEnabled
        }
    }
    
    /// Get text input elements only
    public var textInputElements: [UIElement] {
        elements.filter { element in
            guard let role = element.role else { return false }
            return role.isTextInputRole && element.isEnabled
        }
    }
}

/// Metadata about a UI snapshot
public struct SnapshotMetadata: Sendable, Codable {
    /// Optional description of what this snapshot captures
    public let description: String?
    
    /// Tags for categorizing snapshots
    public let tags: [String]
    
    /// Any additional custom data
    public let customData: [String: String]
    
    public init(
        description: String? = nil,
        tags: [String] = [],
        customData: [String: String] = [:]
    ) {
        self.description = description
        self.tags = tags
        self.customData = customData
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

// MARK: - Application Info

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

// MARK: - Window Info

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