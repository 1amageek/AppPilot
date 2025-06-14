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

/// Accessibility element roles based on NSAccessibility constants
/// All roles follow the project convention of removing "AX" prefixes
public enum Role: String, Codable, CaseIterable, Sendable {
    // Application and system
    case application = "Application"
    case systemWide = "SystemWide"
    
    // Windows and containers
    case window = "Window"
    case sheet = "Sheet"
    case drawer = "Drawer"
    case popover = "Popover"
    
    // Layout and grouping
    case group = "Group"
    case layoutArea = "LayoutArea"
    case layoutItem = "LayoutItem"
    case matte = "Matte"
    case growArea = "GrowArea"
    
    // Controls
    case button = "Button"
    case popUpButton = "PopUpButton"
    case menuButton = "MenuButton"
    case checkBox = "CheckBox"
    case radioButton = "RadioButton"
    case radioGroup = "RadioGroup"
    case slider = "Slider"
    case incrementor = "Incrementor"
    case comboBox = "ComboBox"
    case disclosureTriangle = "DisclosureTriangle"
    case colorWell = "ColorWell"
    case link = "Link"
    
    // Text elements
    case textField = "TextField"
    case textArea = "TextArea"
    case staticText = "StaticText"
    
    // Indicators
    case busyIndicator = "BusyIndicator"
    case progressIndicator = "ProgressIndicator"
    case levelIndicator = "LevelIndicator"
    case valueIndicator = "ValueIndicator"
    case relevanceIndicator = "RelevanceIndicator"
    
    // Collections and tables
    case list = "List"
    case table = "Table"
    case outline = "Outline"
    case grid = "Grid"
    case browser = "Browser"
    case cell = "Cell"
    case row = "Row"
    case column = "Column"
    
    // Navigation and menus
    case menu = "Menu"
    case menuBar = "MenuBar"
    case menuBarItem = "MenuBarItem"
    case menuItem = "MenuItem"
    case toolbar = "Toolbar"
    case tabGroup = "TabGroup"
    
    // Scrolling
    case scrollArea = "ScrollArea"
    case scrollBar = "ScrollBar"
    case splitter = "Splitter"
    case splitGroup = "SplitGroup"
    case handle = "Handle"
    
    // Media and graphics
    case image = "Image"
    
    // Measurement and tools
    case ruler = "Ruler"
    case rulerMarker = "RulerMarker"
    
    // Help and information
    case helpTag = "HelpTag"
    
    // Web and document
    case pageRole = "PageRole"
    case webAreaRole = "WebAreaRole"
    case headingRole = "HeadingRole"
    case listMarkerRole = "ListMarkerRole"
    case dateTimeAreaRole = "DateTimeAreaRole"
    
    // Fallback
    case unknown = "Unknown"
    
    // Project-specific normalized roles (from AXDumper)
    case text = "Text"           // Normalized from StaticText
    case scroll = "Scroll"       // Normalized from ScrollArea
    case field = "Field"         // Normalized from TextField
    case check = "Check"         // Normalized from CheckBox
    case radio = "Radio"         // Normalized from RadioButton
    case popUp = "PopUp"         // Normalized from PopUpButton
    case generic = "Generic"     // Normalized from GenericElement
    
    /// Initialize from raw string value, handling both prefixed and non-prefixed formats
    public init?(rawValue: String) {
        // Try direct match first
        if let role = Role.allCases.first(where: { $0.rawValue == rawValue }) {
            self = role
            return
        }
        
        // Try with AX prefix removed
        let cleanValue = rawValue.hasPrefix("AX") ? String(rawValue.dropFirst(2)) : rawValue
        if let role = Role.allCases.first(where: { $0.rawValue == cleanValue }) {
            self = role
            return
        }
        
        // Handle case variations and common mappings
        switch cleanValue.lowercased() {
        case "application":
            self = .application
        case "systemwide":
            self = .systemWide
        case "window":
            self = .window
        case "sheet":
            self = .sheet
        case "drawer":
            self = .drawer
        case "popover":
            self = .popover
        case "group":
            self = .group
        case "layoutarea":
            self = .layoutArea
        case "layoutitem":
            self = .layoutItem
        case "matte":
            self = .matte
        case "growarea":
            self = .growArea
        case "button":
            self = .button
        case "popupbutton":
            self = .popUpButton
        case "menubutton":
            self = .menuButton
        case "checkbox":
            self = .checkBox
        case "radiobutton":
            self = .radioButton
        case "radiogroup":
            self = .radioGroup
        case "slider":
            self = .slider
        case "incrementor":
            self = .incrementor
        case "combobox":
            self = .comboBox
        case "disclosuretriangle":
            self = .disclosureTriangle
        case "colorwell":
            self = .colorWell
        case "link":
            self = .link
        case "textfield":
            self = .textField
        case "textarea":
            self = .textArea
        case "statictext":
            self = .staticText
        case "busyindicator":
            self = .busyIndicator
        case "progressindicator":
            self = .progressIndicator
        case "levelindicator":
            self = .levelIndicator
        case "valueindicator":
            self = .valueIndicator
        case "relevanceindicator":
            self = .relevanceIndicator
        case "list":
            self = .list
        case "table":
            self = .table
        case "outline":
            self = .outline
        case "grid":
            self = .grid
        case "browser":
            self = .browser
        case "cell":
            self = .cell
        case "row":
            self = .row
        case "column":
            self = .column
        case "menu":
            self = .menu
        case "menubar":
            self = .menuBar
        case "menubaritem":
            self = .menuBarItem
        case "menuitem":
            self = .menuItem
        case "toolbar":
            self = .toolbar
        case "tabgroup":
            self = .tabGroup
        case "scrollarea":
            self = .scrollArea
        case "scrollbar":
            self = .scrollBar
        case "splitter":
            self = .splitter
        case "splitgroup":
            self = .splitGroup
        case "handle":
            self = .handle
        case "image":
            self = .image
        case "ruler":
            self = .ruler
        case "rulermarker":
            self = .rulerMarker
        case "helptag":
            self = .helpTag
        case "pagerole":
            self = .pageRole
        case "webarearole":
            self = .webAreaRole
        case "headingrole":
            self = .headingRole
        case "listmarkerrole":
            self = .listMarkerRole
        case "datetimearearole":
            self = .dateTimeAreaRole
        // Project-specific normalized mappings
        case "text":
            self = .text
        case "scroll":
            self = .scroll
        case "field":
            self = .field
        case "check":
            self = .check
        case "radio":
            self = .radio
        case "popup":
            self = .popUp
        case "generic":
            self = .generic
        // Additional common variations
        case "genericelement":
            self = .generic
        default:
            self = .unknown
        }
    }
    
    /// Get display name for UI
    public var displayName: String {
        switch self {
        case .systemWide:
            return "System Wide"
        case .layoutArea:
            return "Layout Area"
        case .layoutItem:
            return "Layout Item"
        case .growArea:
            return "Grow Area"
        case .popUpButton:
            return "Pop Up Button"
        case .menuButton:
            return "Menu Button"
        case .checkBox:
            return "Check Box"
        case .radioButton:
            return "Radio Button"
        case .radioGroup:
            return "Radio Group"
        case .comboBox:
            return "Combo Box"
        case .disclosureTriangle:
            return "Disclosure Triangle"
        case .colorWell:
            return "Color Well"
        case .textField:
            return "Text Field"
        case .textArea:
            return "Text Area"
        case .staticText:
            return "Static Text"
        case .busyIndicator:
            return "Busy Indicator"
        case .progressIndicator:
            return "Progress Indicator"
        case .levelIndicator:
            return "Level Indicator"
        case .valueIndicator:
            return "Value Indicator"
        case .relevanceIndicator:
            return "Relevance Indicator"
        case .menuBar:
            return "Menu Bar"
        case .menuBarItem:
            return "Menu Bar Item"
        case .menuItem:
            return "Menu Item"
        case .tabGroup:
            return "Tab Group"
        case .scrollArea:
            return "Scroll Area"
        case .scrollBar:
            return "Scroll Bar"
        case .splitGroup:
            return "Split Group"
        case .rulerMarker:
            return "Ruler Marker"
        case .helpTag:
            return "Help Tag"
        case .pageRole:
            return "Page Role"
        case .webAreaRole:
            return "Web Area Role"
        case .headingRole:
            return "Heading Role"
        case .listMarkerRole:
            return "List Marker Role"
        case .dateTimeAreaRole:
            return "Date Time Area Role"
        case .popUp:
            return "Pop Up"
        default:
            return rawValue
        }
    }
    
    /// Check if this role represents an interactive element
    public var isInteractive: Bool {
        switch self {
        case .button, .popUpButton, .menuButton, .checkBox, .radioButton,
             .slider, .incrementor, .comboBox, .disclosureTriangle,
             .colorWell, .link, .textField, .textArea, .menuItem,
             .check, .radio, .popUp, .field:
            return true
        default:
            return false
        }
    }
    
    /// Check if this role represents a clickable element
    public var isClickable: Bool {
        switch self {
        case .button, .menuItem, .menuBarItem, .check, .radio, 
             .link, .tabGroup, .row, .checkBox, .radioButton,
             .popUpButton, .menuButton, .disclosureTriangle:
            return true
        default:
            return false
        }
    }
    
    /// Check if this role represents a text input element
    public var isTextInput: Bool {
        switch self {
        case .field, .textField, .textArea:
            return true
        default:
            return false
        }
    }
    
    /// Check if this role represents a container element
    public var isContainer: Bool {
        switch self {
        case .group, .radioGroup, .list, .scrollArea, .splitGroup,
             .table, .outline, .browser, .tabGroup, .row, .column,
             .layoutArea, .layoutItem, .webAreaRole, .grid, .menu,
             .menuBar, .window, .sheet, .drawer, .popover, .toolbar,
             .matte, .scroll:
            return true
        default:
            return false
        }
    }
    
    /// Check if this role represents a text element
    public var isText: Bool {
        switch self {
        case .textField, .textArea, .staticText, .headingRole,
             .text, .field:
            return true
        default:
            return false
        }
    }
    
    /// Convert to the normalized role used in this project
    public var normalized: Role {
        switch self {
        case .staticText:
            return .text
        case .scrollArea:
            return .scroll
        case .textField:
            return .field
        case .checkBox:
            return .check
        case .radioButton:
            return .radio
        case .popUpButton:
            return .popUp
        // Additional normalizations based on common UI patterns
        case .textArea:
            return .field
        case .busyIndicator, .progressIndicator, .levelIndicator, .valueIndicator:
            return .generic
        case .menuButton:
            return .button
        case .incrementor:
            return .button
        case .disclosureTriangle:
            return .button
        case .tabGroup:
            return .group
        case .radioGroup:
            return .group
        case .scrollBar:
            return .scroll
        case .splitGroup:
            return .group
        case .toolbar:
            return .group
        case .menuBar:
            return .group
        case .headingRole:
            return .text
        case .listMarkerRole:
            return .text
        case .helpTag:
            return .text
        case .webAreaRole:
            return .group
        case .pageRole:
            return .group
        case .layoutArea, .layoutItem:
            return .group
        case .growArea:
            return .generic
        case .handle:
            return .generic
        case .splitter:
            return .generic
        case .ruler, .rulerMarker:
            return .generic
        case .matte:
            return .group
        default:
            return self
        }
    }
}

// MARK: - UI Element System (AXUI Integration)

/// Re-export AXElement from AXUI for AppPilot compatibility
/// 
/// `AXElement` represents a user interface element used for automation.
/// 
/// ```swift
/// let elements = try await pilot.findElements(in: window, role: .button)
/// try await pilot.click(element: elements.first!)
/// ```
public typealias AXElement = AXUI.AXElement


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
    case elementAppear(window: WindowHandle, role: Role, title: String)
    /// Wait for a UI element to disappear
    case elementDisappear(window: WindowHandle, role: Role, title: String)
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


// MARK: - AXElement Extensions for Internal Use

extension AXElement: @retroactive @unchecked Sendable {
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
    public var centerPoint: Point {
        let bounds = self.cgBounds
        return Point(x: bounds.midX, y: bounds.midY)
    }
    
    /// Whether this element is currently enabled for interaction
    public var isEnabled: Bool {
        return self.state?.enabled ?? true
    }
    
    /// Whether this element is clickable based on its role
    public var isClickableElement: Bool {
        guard let axuiRole = self.role else { return false }
        return Role(rawValue: axuiRole.rawValue)?.isClickable ?? false
    }
    
    /// Check if element is clickable (alternate name for consistency)
    public var isClickable: Bool { isClickableElement }
    
    /// Whether this element accepts text input based on its role
    public var isTextInputElement: Bool {
        guard let axuiRole = self.role else { return false }
        return Role(rawValue: axuiRole.rawValue)?.isTextInput ?? false
    }
    
    /// Check if element accepts text input (alternate name for consistency) 
    public var isTextInput: Bool { isTextInputElement }
    
    /// Whether element is selected
    public var isSelected: Bool {
        state?.selected ?? false
    }
    
    /// Whether element is focused
    public var isFocused: Bool {
        state?.focused ?? false
    }
    
    /// Convert bounds to CGRect (alias for cgBounds)
    public var boundsAsRect: CGRect { cgBounds }
    
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

// MARK: - UI Snapshot

/// A lightweight snapshot of UI element hierarchy without image data (token-efficient)
/// 
/// `ElementsSnapshot` captures only the structural state (UI element tree) of a window
/// without the screenshot, making it much more token-efficient for LLM processing.
/// This is ideal when you only need element information and not visual appearance.
/// 
/// ```swift
/// let elementsSnapshot = try await pilot.elementsSnapshot(window: window)
/// 
/// // Analyze UI elements without image overhead
/// let buttons = elementsSnapshot.elements.filter { $0.role?.rawValue == "Button" }
/// print("Found \(buttons.count) buttons")
/// 
/// // Find specific element
/// if let submitButton = elementsSnapshot.findElement(role: "Button", title: "Submit") {
///     print("Submit button at: \(submitButton.centerPoint)")
/// }
/// ```
public struct ElementsSnapshot: Sendable, Codable {
    /// The window handle this snapshot belongs to
    public let windowHandle: WindowHandle
    
    /// Window information at the time of snapshot
    public let windowInfo: WindowInfo
    
    /// UI elements discovered in the window (filtered by query if provided)
    public let elements: [AXElement]
    
    public init(
        windowHandle: WindowHandle,
        windowInfo: WindowInfo,
        elements: [AXElement]
    ) {
        self.windowHandle = windowHandle
        self.windowInfo = windowInfo
        self.elements = elements
    }
    
    /// Find element by role and title in the snapshot
    public func findElement(role: String, title: String? = nil) -> AXElement? {
        elements.first { element in
            element.role?.rawValue == role &&
            (title == nil || element.description?.localizedCaseInsensitiveContains(title!) == true)
        }
    }
    
    /// Find all elements matching criteria
    public func findElements(role: String? = nil, title: String? = nil) -> [AXElement] {
        elements.filter { element in
            (role == nil || element.role?.rawValue == role) &&
            (title == nil || element.description?.localizedCaseInsensitiveContains(title!) == true)
        }
    }
    
    /// Get elements sorted by their position (top-left to bottom-right)
    public var elementsByPosition: [AXElement] {
        elements.sorted { e1, e2 in
            let bounds1 = e1.boundsAsRect
            let bounds2 = e2.boundsAsRect
            if abs(bounds1.minY - bounds2.minY) < 5 {
                return bounds1.minX < bounds2.minX
            }
            return bounds1.minY < bounds2.minY
        }
    }
    
    /// Get clickable elements only
    public var clickableElements: [AXElement] {
        elements.filter { element in
            element.isClickable && element.isEnabled
        }
    }
    
    /// Get text input elements only
    public var textInputElements: [AXElement] {
        elements.filter { element in
            element.isTextInput && element.isEnabled
        }
    }
}

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
    
    /// UI elements discovered in the window (filtered by query if provided)
    public let elements: [AXElement]
    
    /// PNG data of the window screenshot
    public let imageData: Data
    
    public init(
        windowHandle: WindowHandle,
        windowInfo: WindowInfo,
        elements: [AXElement],
        imageData: Data
    ) {
        self.windowHandle = windowHandle
        self.windowInfo = windowInfo
        self.elements = elements
        self.imageData = imageData
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
    public func findElement(role: String, title: String? = nil) -> AXElement? {
        elements.first { element in
            element.role?.rawValue == role &&
            (title == nil || element.description?.localizedCaseInsensitiveContains(title!) == true)
        }
    }
    
    /// Find all elements matching criteria
    public func findElements(role: String? = nil, title: String? = nil) -> [AXElement] {
        elements.filter { element in
            (role == nil || element.role?.rawValue == role) &&
            (title == nil || element.description?.localizedCaseInsensitiveContains(title!) == true)
        }
    }
    
    /// Get elements sorted by their position (top-left to bottom-right)
    public var elementsByPosition: [AXElement] {
        elements.sorted { e1, e2 in
            let bounds1 = e1.boundsAsRect
            let bounds2 = e2.boundsAsRect
            if abs(bounds1.minY - bounds2.minY) < 5 {
                return bounds1.minX < bounds2.minX
            }
            return bounds1.minY < bounds2.minY
        }
    }
    
    /// Get clickable elements only
    public var clickableElements: [AXElement] {
        elements.filter { element in
            element.isClickable && element.isEnabled
        }
    }
    
    /// Get text input elements only
    public var textInputElements: [AXElement] {
        elements.filter { element in
            element.isTextInput && element.isEnabled
        }
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
    public let element: AXElement?
    public let timestamp: Date
    public let description: String?
    
    public init(type: EventType, windowHandle: WindowHandle, element: AXElement? = nil, timestamp: Date = Date(), description: String? = nil) {
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
