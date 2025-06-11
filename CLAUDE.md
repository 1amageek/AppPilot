# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Build the package
swift build

# Run tests (Swift Testing framework)
swift test

# Run a specific test
swift test --filter "testMethodName"

# Run tests with specific tags
swift test --filter ".unit"
swift test --filter ".integration"
swift test --filter "CompositionInput"  # Multi-language IME tests

# Clean build artifacts
swift package clean

# Update dependencies (none required for testing)
swift package update

# Generate Xcode project (if needed)
swift package generate-xcodeproj
```

## Testing Framework Configuration

**⚠️ CRITICAL: This project uses Swift Testing framework (native in Swift 6), NOT XCTest.**

- **Framework**: Swift Testing (built into Swift 6.1+)
- **Dependencies**: None required in Package.swift
- **Syntax**: Use `@Test`, `@Suite`, `#expect()` instead of XCTest equivalents
- **Migration**: All tests have been migrated from XCTest to Swift Testing

## Coding Standards

### 🚫 ABSOLUTE PROHIBITION: NO HARDCODING

**Hardcoding is strictly forbidden in all code, especially tests. Never use:**

- ❌ Direct coordinate specification: `Point(x: 518.0, y: -760.0)`
- ❌ Direct size specification: `element.centerPoint.x > 400`
- ❌ Direct boundary specification: `element.centerPoint.y > -780`
- ❌ Magic numbers for positioning: `bounds.width > 200`

**✅ Correct approaches:**

- ✅ UI element discovery: `findElements()`, `identifier`, `role`, `title`
- ✅ Relative positioning: Use element relationships for positioning
- ✅ Dynamic boundaries: Calculate from actual window/element sizes
- ✅ Semantic targeting: Find elements by their purpose, not location

**Examples:**

```swift
// ❌ WRONG: Hardcoded coordinates
let controlsArea = Point(x: 518.0, y: -760.0)
let elements = allElements.filter { 
    element.centerPoint.x > 400 && element.centerPoint.x < 650 
}

// ✅ CORRECT: Element discovery
let toggleElement = try await pilot.findElements(
    in: window,
    identifier: "use_custom_input_toggle"
).first

// ✅ CORRECT: Relative positioning
let leftPanelElements = allElements.filter { element in
    element.centerPoint.x < window.bounds.midX
}
```

**Rationale:**
- Hardcoded coordinates break when UI layouts change
- Tests become fragile and unmaintainable
- Real automation should adapt to UI changes
- Element-based automation is more reliable and readable

### 🚫 ABSOLUTE PROHIBITION: NO INAPPROPRIATE FALLBACKS

**Fallbacks that mask actual failures are strictly forbidden. Never implement:**

- ❌ **Placeholder generation when real functionality fails**: Creating fake images, mock data, or dummy objects when actual operations fail
- ❌ **Silent failure masking**: Returning default values (like `CGRect.zero`, `Point(x: 400, y: 400)`) when real values cannot be obtained
- ❌ **Automatic degradation without error reporting**: Switching to degraded functionality without properly indicating the failure
- ❌ **Error swallowing**: Catching exceptions and returning fallback values instead of propagating the error

**✅ Correct approaches:**

- ✅ **Proper error propagation**: Throw appropriate `PilotError` cases when operations fail
- ✅ **Explicit failure indication**: Return `nil` or throw exceptions when functionality is unavailable
- ✅ **Fail-fast behavior**: Stop execution immediately when required conditions are not met
- ✅ **Meaningful error messages**: Provide specific error information to help diagnose problems

**Examples:**

```swift
// ❌ WRONG: Masking screen capture failure with placeholder
do {
    return try await screenDriver.captureScreen()
} catch {
    // Create placeholder image...
    return placeholderImage
}

// ✅ CORRECT: Proper error propagation
return try await screenDriver.captureScreen()

// ❌ WRONG: Using default coordinates when window bounds unavailable
let scrollPoint = windowInfo?.bounds.center ?? Point(x: 400, y: 400)

// ✅ CORRECT: Failing when required information is unavailable
guard let windowInfo = windowInfo else {
    throw PilotError.windowNotFound(window)
}
let scrollPoint = Point(x: windowInfo.bounds.midX, y: windowInfo.bounds.midY)

// ❌ WRONG: Returning cached value when live value fails
guard let axElement = elementRefs[element.id] else {
    return element.value  // Stale cached value
}

// ✅ CORRECT: Throwing error when element is no longer accessible
guard let axElement = elementRefs[element.id] else {
    throw PilotError.elementNotAccessible(element.id)
}
```

**Rationale:**
- Inappropriate fallbacks hide bugs and make debugging extremely difficult
- Silent failures violate the principle of least surprise
- Fake data can lead to false positives in testing
- Proper error handling enables users to make informed decisions about failure recovery
- Real failures should be exposed so they can be properly addressed

**Appropriate vs. Inappropriate Fallbacks:**

✅ **Appropriate fallbacks** (functional alternatives):
- Element-based automation → coordinate-based automation (when element detection fails)
- Primary network endpoint → backup endpoint (when primary is down)
- Preferred file format → alternative format (when preferred is not supported)

❌ **Inappropriate fallbacks** (failure masking):
- Real screen capture → placeholder image generation
- Live element bounds → cached/zero bounds
- Actual input source switching → silent no-op
- Real IME candidates → mock candidates

## Project Architecture

This is a Swift Package Manager (SPM) library project named "AppPilot" targeting macOS 15+. The project uses Swift 6.1 and follows the standard SPM structure:

- **Package.swift**: Defines the package configuration, dependencies, and targets
- **Sources/AppPilot/**: Contains the main library implementation
- **Tests/AppPilotTests/**: Contains unit tests using Swift Testing framework (not XCTest)

The project uses the new Swift Testing framework with `@Test` macro annotations instead of the traditional XCTest framework.

## AppPilot 1.0 - UI Element-Based Automation SDK

### Overview

AppPilot 1.0 is a macOS automation SDK that combines **UI element detection** with **reliable automation**. It automatically discovers UI elements using Accessibility APIs and performs smart, element-based operations instead of blind coordinate clicking.

### Core Design Philosophy

1. **UI Element-Based Automation**: Find and interact with actual UI elements (buttons, text fields, etc.)
2. **Smart Element Discovery**: Automatic detection using Accessibility API with role, title, and identifier matching
3. **Fallback Coordination**: Coordinate-based automation as backup when elements can't be found
4. **Real-World Practicality**: Designed for actual application automation, not just demos

### Supported Operations

```swift
// UI Element Discovery
findElements(in:role:title:)     // Find UI elements by role, title, identifier
findButton(in:title:)            // Find specific button
findTextField(in:placeholder:)   // Find text input field
findElement(in:role:title:)      // Find single element

// Element-Based Actions
click(element:)                  // Click discovered UI element
type(text:into:)                 // Type into discovered text field
getValue(from:)                  // Get value from UI element
elementExists(_:)                // Check if element exists

// Application Management
findApplication(bundleId:)       // Find app by bundle ID
findApplication(name:)           // Find app by name
findWindow(app:title:)           // Find window by title
findWindow(app:index:)           // Find window by index

// Wait Operations
waitForElement(in:role:title:)   // Wait for element to appear
wait(_:)                         // Wait for time or conditions

// Fallback Coordinate Operations (when element detection fails)
click(window:at:)                // Click at coordinates
type(text:)                      // Type text to focused app
```

### Architecture

```
┌─────────────── AppPilot (Actor) ───────────────┐
│  • UI Element discovery and automation          │
│  • Smart element-based actions                 │
│  • Automatic coordinate conversion             │
│  • Application and window management           │
└─────────────────────────────────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐
│ Element  │ │ CGEvent  │ │ Accessibility│
│ Finder   │ │ Driver   │ │ Driver       │
│          │ │          │ │              │
│ AX Tree  │ │ Mouse &  │ │ Element      │
│ Parser   │ │ Keyboard │ │ Detection    │
└──────────┘ └──────────┘ └──────────────┘
```

### Core Types

```swift
// Application and Window Management
public struct AppHandle: Hashable, Sendable { 
    let id: String 
}

public struct WindowHandle: Hashable, Sendable { 
    let id: String 
}

public struct AppInfo: Sendable {
    let id: AppHandle
    let name: String
    let bundleIdentifier: String?
    let isActive: Bool
}

public struct WindowInfo: Sendable {
    let id: WindowHandle
    let title: String?
    let bounds: CGRect
    let isVisible: Bool
    let isMain: Bool
}

// UI Element System
public struct UIElement: Sendable {
    let id: String
    let role: ElementRole
    let title: String?
    let value: String?
    let identifier: String?
    let bounds: CGRect
    let isEnabled: Bool
    
    var centerPoint: Point {
        Point(x: bounds.midX, y: bounds.midY)
    }
}

public enum ElementRole: String, Sendable {
    case button = "AXButton"
    case textField = "AXTextField"
    case searchField = "AXSearchField"
    case menuItem = "AXMenuItem"
    case checkBox = "AXCheckBox"
    case radioButton = "AXRadioButton"
    case link = "AXLink"
    case tab = "AXTab"
    case staticText = "AXStaticText"
}

// Basic Types
public struct Point: Sendable {
    let x: CGFloat
    let y: CGFloat
}

public enum MouseButton: Sendable {
    case left, right, center
}

public struct ActionResult: Sendable {
    let success: Bool
    let timestamp: Date
    let element: UIElement?
    let coordinates: Point?
}
```

### Main API

```swift
public actor AppPilot {
    
    // MARK: - Application Management
    
    /// Get all running applications
    public func listApplications() async throws -> [AppInfo]
    
    /// Find application by bundle ID
    public func findApplication(bundleId: String) async throws -> AppHandle
    
    /// Find application by name
    public func findApplication(name: String) async throws -> AppHandle
    
    /// Get windows for an application
    public func listWindows(app: AppHandle) async throws -> [WindowInfo]
    
    /// Find window by title
    public func findWindow(app: AppHandle, title: String) async throws -> WindowHandle
    
    /// Find window by index
    public func findWindow(app: AppHandle, index: Int) async throws -> WindowHandle
    
    // MARK: - UI Element Discovery
    
    /// Find UI elements by criteria
    public func findElements(
        in window: WindowHandle,
        role: ElementRole? = nil,
        title: String? = nil,
        identifier: String? = nil
    ) async throws -> [UIElement]
    
    /// Find specific UI element
    public func findElement(
        in window: WindowHandle,
        role: ElementRole,
        title: String
    ) async throws -> UIElement
    
    /// Find button by title
    public func findButton(
        in window: WindowHandle,
        title: String
    ) async throws -> UIElement
    
    /// Find text field
    public func findTextField(
        in window: WindowHandle,
        placeholder: String? = nil
    ) async throws -> UIElement
    
    // MARK: - Element-Based Actions
    
    /// Click UI element (automatically calculates center point)
    public func click(element: UIElement) async throws -> ActionResult
    
    /// Type text into UI element
    public func type(text: String, into element: UIElement) async throws -> ActionResult
    
    /// Get value from UI element
    public func getValue(from element: UIElement) async throws -> String?
    
    /// Check if element exists and is valid
    public func elementExists(_ element: UIElement) async throws -> Bool
    
    // MARK: - Wait Operations
    
    /// Wait for element to appear
    public func waitForElement(
        in window: WindowHandle,
        role: ElementRole,
        title: String,
        timeout: TimeInterval = 10.0
    ) async throws -> UIElement
    
    /// Wait for condition
    public func wait(_ spec: WaitSpec) async throws
    
    // MARK: - Fallback Coordinate Operations
    
    /// Click at coordinates (fallback when element detection fails)
    public func click(
        window: WindowHandle,
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1
    ) async throws -> ActionResult
    
    /// Type text to currently focused application (fallback)
    public func type(text: String) async throws -> ActionResult
    
    /// Capture screenshot of window
    public func capture(window: WindowHandle) async throws -> CGImage
    
    /// Capture complete UI snapshot (screenshot + element hierarchy)
    public func snapshot(
        window: WindowHandle,
        metadata: SnapshotMetadata? = nil
    ) async throws -> UISnapshot
}

public enum WaitSpec {
    case time(seconds: TimeInterval)
    case elementAppear(window: WindowHandle, role: ElementRole, title: String)
    case elementDisappear(window: WindowHandle, role: ElementRole, title: String)
}
```

### Implementation Strategy

#### 1. UI Element Discovery System
- **AX Tree Traversal**: Recursively walk accessibility tree to find elements
- **Smart Filtering**: Match elements by role, title, identifier, and other attributes
- **Caching**: Cache element trees for performance with TTL expiration
- **Auto-refresh**: Refresh element cache when UI changes detected

#### 2. Element-Based Automation
```swift
func click(element: UIElement) async throws -> ActionResult {
    // 1. Verify element still exists and is enabled
    guard try await elementExists(element) && element.isEnabled else {
        throw PilotError.elementNotAccessible(element.id)
    }
    
    // 2. Calculate center point automatically
    let centerPoint = element.centerPoint
    
    // 3. Convert to screen coordinates
    let screenPoint = try await convertToScreenCoordinates(centerPoint, element: element)
    
    // 4. Perform CGEvent click
    try performCGEventClick(at: screenPoint)
    
    return ActionResult(success: true, element: element, coordinates: centerPoint)
}
```

#### 3. Element Discovery Implementation
```swift
func findElements(
    in window: WindowHandle,
    role: ElementRole? = nil,
    title: String? = nil,
    identifier: String? = nil
) async throws -> [UIElement] {
    
    // Get cached or fresh AX tree
    let axTree = try await getAccessibilityTree(for: window)
    
    // Parse tree and filter elements
    let allElements = parseElementsFromTree(axTree)
    
    return allElements.filter { element in
        // Match role if specified
        if let role = role, element.role != role { return false }
        
        // Match title if specified (case-insensitive, partial match)
        if let title = title, 
           let elementTitle = element.title,
           !elementTitle.localizedCaseInsensitiveContains(title) { 
            return false 
        }
        
        // Match identifier if specified
        if let identifier = identifier, element.identifier != identifier { return false }
        
        return true
    }
}
```

#### 4. Smart Coordinate Conversion
```swift
func convertToScreenCoordinates(_ point: Point, element: UIElement) async throws -> CGPoint {
    // Elements already contain screen-relative bounds from AX API
    // No additional conversion needed for element-based operations
    return CGPoint(x: point.x, y: point.y)
}
```

### Error Handling

```swift
public enum PilotError: Error, Sendable {
    case permissionDenied(String)
    case applicationNotFound(String)
    case windowNotFound(WindowHandle)
    case elementNotFound(role: ElementRole, title: String?)
    case elementNotAccessible(String)
    case multipleElementsFound(role: ElementRole, title: String?, count: Int)
    case eventCreationFailed
    case coordinateOutOfBounds(Point)
    case timeout(TimeInterval)
    case osFailure(api: String, code: Int32)
    case accessibilityTreeUnavailable(WindowHandle)
}
```

### Required Permissions

```xml
<!-- Info.plist / Entitlements -->
<key>NSAppleEventsUsageDescription</key>
<string>AppPilot needs AppleEvents access for window management</string>

<!-- System Preferences → Security & Privacy → Accessibility -->
<!-- Your app must be granted Accessibility permission -->
```

### Usage Examples

#### Example 1: Weather App City Search (Element-Based)
```swift
let pilot = AppPilot()

// Find Weather app
let weatherApp = try await pilot.findApplication(bundleId: "com.apple.weather")
let mainWindow = try await pilot.findWindow(app: weatherApp, index: 0)

// Find and click search field automatically
let searchField = try await pilot.findTextField(in: mainWindow)
try await pilot.click(element: searchField)

// Type city name
try await pilot.type(text: "Tokyo", into: searchField)

// Wait for search results to appear
let tokyoResult = try await pilot.waitForElement(
    in: mainWindow,
    role: .button,
    title: "Tokyo",
    timeout: 5.0
)

// Click the result
try await pilot.click(element: tokyoResult)
```

#### Example 2: TestApp Automation (Element-Based)
```swift
let pilot = AppPilot()

// Find TestApp
let testApp = try await pilot.findApplication(name: "TestApp")
let window = try await pilot.findWindow(app: testApp, title: "Mouse Click")

// Find all clickable buttons automatically
let buttons = try await pilot.findElements(in: window, role: .button)

// Click each button and verify via API
for button in buttons where button.isEnabled {
    print("Clicking button: \(button.title ?? button.id)")
    try await pilot.click(element: button)
    
    // API verification
    let apiResponse = try await testAppAPI.getClickTargets()
    let clickedCount = apiResponse.filter { $0.clicked }.count
    print("Buttons clicked so far: \(clickedCount)")
    
    try await pilot.wait(.time(seconds: 0.5))
}
```

#### Example 3: Fallback to Coordinates (When Element Detection Fails)
```swift
let pilot = AppPilot()

let app = try await pilot.findApplication(name: "SomeApp")
let window = try await pilot.findWindow(app: app, index: 0)

// Try element-based approach first
do {
    let submitButton = try await pilot.findButton(in: window, title: "Submit")
    try await pilot.click(element: submitButton)
} catch PilotError.elementNotFound {
    print("Button not found, falling back to coordinates")
    // Fallback to coordinate-based clicking
    try await pilot.click(window: window, at: Point(x: 200, y: 300))
}
```

#### Example 4: Smart Element Waiting
```swift
let pilot = AppPilot()

let app = try await pilot.findApplication(bundleId: "com.example.app")
let window = try await pilot.findWindow(app: app, title: "Main")

// Click button that triggers async operation
let loadButton = try await pilot.findButton(in: window, title: "Load Data")
try await pilot.click(element: loadButton)

// Wait for result element to appear
let resultElement = try await pilot.waitForElement(
    in: window,
    role: .staticText,
    title: "Loading complete",
    timeout: 10.0
)

// Extract result
let resultText = try await pilot.getValue(from: resultElement)
print("Result: \(resultText ?? "No value")")
```

### Design Decisions & Trade-offs

#### ✅ Benefits
- **Smart Element Detection**: No more blind coordinate guessing
- **Universal Compatibility**: Works with ALL macOS apps (SwiftUI, AppKit, Electron, Web)
- **Robust Automation**: Elements found by role, title, and identifier - not fragile coordinates
- **Easy Testing**: Find buttons by title instead of hardcoded coordinates
- **Graceful Fallback**: Coordinate-based automation when element detection fails
- **Real User Simulation**: CGEvent integration maintains user-like behavior
- **Future-Proof**: UI changes less likely to break automation due to element-based targeting

#### ❌ Limitations Accepted
- **Accessibility Dependency**: Requires apps to implement accessibility properly
- **Performance Overhead**: Element discovery requires AX tree traversal
- **Cursor Movement**: All operations move the cursor visibly
- **Foreground Only**: Windows must be visible and unminimized
- **Element Changes**: UI updates may invalidate cached elements

#### 🚫 Removed Features (from v2.0)
- Pure coordinate-only automation (now fallback only)
- Simple click-and-pray approach
- Manual coordinate calculation requirements

#### 🎯 Key Improvements (from v2.0)
- **Element-First Approach**: Discover actual UI elements instead of guessing
- **Smart Targeting**: Find buttons, text fields, etc. by semantic properties
- **Automatic Coordinate Calculation**: No need to manually calculate button centers
- **Better Error Messages**: "Button 'Submit' not found" vs "Click failed at (x,y)"
- **Maintainable Tests**: Tests reference UI elements by name, not coordinates

### Implementation Status

✅ **Design Complete**: Element-based automation architecture defined
🔧 **Implementation Needed**: 
- Add AccessibilityDriver with AX tree traversal
- Implement ElementFinder with role/title/identifier matching
- Create UIElement discovery and caching system
- Add element-based click/type operations with automatic coordinate calculation
- Implement waitForElement functionality
- Update integration tests to use element discovery instead of blind coordinates

### Testing Strategy

AppPilot uses TestApp for comprehensive automated testing following the **「見る」「理解する」「アクション」** (See, Understand, Action) pattern.

#### Required TestApp Test Cases

**🖱️ Mouse Click Tests**
- Basic click functionality (left, right, center, single/double/triple)
- 5-target accuracy test (TL, TR, C, BL, BR)
- External click detection via mouse event monitoring
- UI tree coordinate discovery vs hardcoded coordinates
- Click tolerance ranges (25px, 50px, 75px, 100px)

**⌨️ Keyboard Tests**
- Text input accuracy: alphanumeric, special chars, Unicode (Japanese), control chars
- Expected vs actual text comparison with error position detection
- TestApp API integration for keyboard test result tracking

**⏰ Wait Operation Tests**
- Time-based waits (0.1s - 10s) with 85%+ accuracy requirement
- UI change detection waits with timeout handling
- Performance and timing precision validation

**🔗 TestApp API Integration Tests**
- Server health checks (`/api/health`)
- State management (`/api/state`, `/api/reset`)
- Target tracking (`/api/targets`)
- Session management (`/api/session/start`, `/api/session/end`)
- JSON serialization and data integrity

**🎯 AppPilot SDK Comprehensive Tests**
- Application discovery (`listApplications()`)
- Window enumeration (`listWindows()`)
- Element discovery (`findElements()` with role/title/identifier)
- Element-based actions (`click(element:)`, `type(text:into:)`)
- Screenshot capture (`capture(window:)`)
- UI snapshot capture (`snapshot(window:metadata:)`) - combines screenshot + element hierarchy
- Gesture operations (`gesture(from:to:duration:)`)
- Wait operations (`wait(.time)`, `wait(.uiChange)`)

**📊 Error Handling Tests**
- `PilotError.windowNotFound`, `elementNotFound`, `permissionDenied`
- Network connectivity failures for TestApp API
- Invalid element references and stale element detection

**🔄 Session and State Management Tests**
- Test session isolation and cleanup
- State persistence across operations
- Memory usage and performance under load

#### Example Test Implementation

```swift
@Test("Complete TestApp integration test - Mouse clicks")
func testMouseClicksWithTestApp() async throws {
    let pilot = AppPilot()
    
    // Setup test session with TestApp
    let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
    defer { Task { await testSession.cleanup() } }
    
    // Stage 1: 見る (See/Observe) - UI Discovery
    let allElements = try await pilot.findElements(in: testSession.window.id)
    let clickTargets = allElements.filter { $0.role == .button }
    
    #expect(clickTargets.count >= 5, "Should find at least 5 click targets")
    
    // Stage 2: 理解する (Understand) - Element Analysis
    let targetsByTitle = Dictionary(grouping: clickTargets) { $0.title ?? "unknown" }
    #expect(targetsByTitle["TL"] != nil, "Should find top-left target")
    #expect(targetsByTitle["C"] != nil, "Should find center target")
    
    // Stage 3: アクション (Action) - Click Operations
    await testSession.resetState()
    
    for target in clickTargets {
        let beforeState = await testSession.getClickTargets()
        let beforeCount = beforeState.filter { $0.clicked }.count
        
        // Click using element-based approach
        let result = try await pilot.click(element: target)
        #expect(result.success, "Click should succeed for target: \(target.title ?? target.id)")
        
        try await pilot.wait(.time(seconds: 0.5))
        
        let afterState = await testSession.getClickTargets()
        let afterCount = afterState.filter { $0.clicked }.count
        
        #expect(afterCount > beforeCount, "TestApp should detect click on \(target.title ?? target.id)")
    }
}

@Test("TestApp API integration test")
func testTestAppAPIIntegration() async throws {
    let api = CorrectFlowTestAppAPI()
    
    // Test server health
    let healthResponse = try await URLSession.shared.data(from: URL(string: "http://localhost:8765/api/health")!)
    #expect(healthResponse.0.count > 0, "Health endpoint should respond")
    
    // Test state reset
    try await api.resetState()
    
    // Test target retrieval
    let targets = try await api.getClickTargets()
    #expect(targets.allSatisfy { !$0.clicked }, "All targets should be unclicked after reset")
}

@Test("Element discovery vs coordinate accuracy")
func testElementVsCoordinateAccuracy() async throws {
    let pilot = AppPilot()
    let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
    
    // Find elements dynamically
    let buttons = try await pilot.findElements(in: testSession.window.id, role: .button)
    guard let centerButton = buttons.first(where: { $0.title == "C" }) else {
        throw PilotError.elementNotFound(role: .button, title: "C")
    }
    
    // Test element-based click
    await testSession.resetState()
    let elementResult = try await pilot.click(element: centerButton)
    try await pilot.wait(.time(seconds: 0.5))
    let elementState = await testSession.getClickTargets()
    let elementSuccess = elementState.filter { $0.clicked }.count > 0
    
    // Test coordinate-based click (fallback)
    await testSession.resetState()
    let coordResult = try await pilot.click(window: testSession.window.id, at: centerButton.centerPoint)
    try await pilot.wait(.time(seconds: 0.5))
    let coordState = await testSession.getClickTargets()
    let coordSuccess = coordState.filter { $0.clicked }.count > 0
    
    #expect(elementSuccess, "Element-based click should succeed")
    #expect(coordSuccess, "Coordinate-based click should also succeed")
    #expect(elementResult.success == coordResult.success, "Both methods should have same success rate")
}
```

#### Test Execution Strategy

```bash
# Run all TestApp integration tests
swift test --filter ".integration"

# Run specific test categories
swift test --filter ".mouseClick"
swift test --filter ".keyboard" 
swift test --filter ".correctFlow"

# Run comprehensive TestApp verification
swift test --filter "CorrectTestFlowTests"

# Performance testing
swift test --filter ".performance"
```

All tests must use TestApp as the target application and validate results through both AppPilot operations and TestApp's REST API for complete verification.

### Real-World Example: TestApp Integration

The new element-based approach transforms TestApp integration from this:

```swift
// v2.0: Blind coordinate clicking
try await pilot.click(window: window, at: Point(x: 534, y: 228)) // Hope this hits something!
```

To this:

```swift
// 1.0: Smart element discovery
let buttons = try await pilot.findElements(in: window, role: .button)
for button in buttons {
    try await pilot.click(element: button) // Always hits the right target
}
```

This new design prioritizes **practical automation** with **intelligent element discovery** over blind coordinate operations.