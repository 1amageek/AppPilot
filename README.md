# AppPilot

**UI Element-Based macOS Automation SDK**

AppPilot is a modern Swift Package Manager library that provides intelligent UI automation for macOS applications. Instead of relying on brittle coordinate-based automation, AppPilot discovers actual UI elements using Accessibility APIs and performs smart, element-based operations.

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## 🌟 Features

- **🎯 Smart Element Discovery**: Find UI elements by role, title, and identifier using Accessibility API
- **🖱️ Element-Based Actions**: Click buttons, fill text fields, and interact with UI components
- **🔍 Automatic Coordinate Calculation**: No need to manually calculate button centers
- **🚀 Universal Compatibility**: Works with SwiftUI, AppKit, Electron, and web applications
- **⏰ Intelligent Waiting**: Wait for elements to appear or conditions to be met
- **📷 Screen Capture**: Take screenshots of windows and applications using ScreenCaptureKit
- **🌐 Multi-Language IME Support**: Advanced composition input for Japanese, Chinese, Korean, and other languages with automatic candidate detection
- **🔄 Graceful Fallback**: Coordinate-based automation when element detection fails
- **🛡️ Type Safety**: Built with Swift 6.1 and modern concurrency (Actor-based design)
- **🧪 Comprehensive Testing**: Swift Testing framework with dedicated TestApp integration

## 🏗️ Architecture

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

## 🔧 Requirements

- macOS 15.0+
- Swift 6.1+
- Xcode 16.0+
- **Accessibility Permission** (System Preferences → Security & Privacy → Accessibility)

## 📦 Installation

### Swift Package Manager

Add AppPilot to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/AppPilot.git", from: "1.2.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select your target and add the package

## 🚀 Quick Start

```swift
import AppPilot

let pilot = AppPilot()

// Find an application
let app = try await pilot.findApplication(name: "Calculator")
let window = try await pilot.findWindow(app: app, index: 0)

// Discover UI elements
let buttons = try await pilot.findElements(in: window, role: .button)
let numberFive = try await pilot.findButton(in: window, title: "5")

// Perform element-based actions
try await pilot.click(element: numberFive)
try await pilot.click(element: try await pilot.findButton(in: window, title: "+"))
try await pilot.click(element: try await pilot.findButton(in: window, title: "3"))
try await pilot.click(element: try await pilot.findButton(in: window, title: "="))
```

## 📖 Core Concepts

### Element-Based Automation

AppPilot prioritizes finding actual UI elements over blind coordinate clicking:

```swift
// ❌ Old approach: Hardcoded coordinates
try await pilot.click(window: window, at: Point(x: 200, y: 300))

// ✅ New approach: Smart element discovery
let submitButton = try await pilot.findButton(in: window, title: "Submit")
try await pilot.click(element: submitButton)
```

### Smart Element Discovery

Find elements using semantic properties:

```swift
// Find by role and title
let saveButton = try await pilot.findElement(in: window, role: .button, title: "Save")

// Find by identifier
let searchField = try await pilot.findElements(in: window, identifier: "search_input")

// Find all buttons
let allButtons = try await pilot.findElements(in: window, role: .button)

// Find text fields
let textField = try await pilot.findTextField(in: window)
```

### Wait Operations

Wait for UI changes and conditions:

```swift
// Wait for element to appear
let loadingComplete = try await pilot.waitForElement(
    in: window,
    role: .staticText,
    title: "Loading complete",
    timeout: 10.0
)

// Wait for specific time
try await pilot.wait(.time(seconds: 2.0))

// Wait for element to disappear
try await pilot.wait(.elementDisappear(window: window, role: .button, title: "Loading..."))
```

## 🧪 Testing

AppPilot uses Swift Testing framework with comprehensive test coverage:

```bash
# Run all tests
swift test

# Run specific test categories
swift test --filter ".unit"           # Unit tests
swift test --filter ".integration"    # Integration tests with TestApp
swift test --filter ".mouseClick"     # Mouse click accuracy tests
swift test --filter ".keyboard"       # Keyboard input tests
swift test --filter "CompositionInput" # Multi-language IME tests

# Run specific tests
swift test --filter "testElementDiscovery"
swift test --filter "CorrectTestFlowTests"

# Build the project
swift build

# Clean build artifacts
swift package clean
```

### TestApp Integration Testing

The project includes a dedicated TestApp for comprehensive automation validation following the **「見る」「理解する」「アクション」** (See, Understand, Action) pattern:

```swift
@Test("Complete TestApp integration test")
func testTestAppIntegration() async throws {
    let pilot = AppPilot()
    
    // Stage 1: 見る (See/Observe) - Application & UI Discovery
    let testApp = try await pilot.findApplication(name: "TestApp")
    let window = try await pilot.findWindow(app: testApp, title: "Mouse Click")
    
    // Stage 2: 理解する (Understand) - Element Analysis
    let allElements = try await pilot.findElements(in: window)
    let clickTargets = allElements.filter { $0.role == .button }
    
    #expect(clickTargets.count >= 5, "Should find at least 5 click targets")
    
    // Stage 3: アクション (Action) - Element-based Automation
    let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
    await testSession.resetState()
    
    for target in clickTargets {
        let beforeState = await testSession.getClickTargets()
        let beforeCount = beforeState.filter { $0.clicked }.count
        
        // Perform element-based click
        let result = try await pilot.click(element: target)
        #expect(result.success, "Click should succeed for \(target.title ?? target.id)")
        
        try await pilot.wait(.time(seconds: 0.5))
        
        // Verify via TestApp API
        let afterState = await testSession.getClickTargets()
        let afterCount = afterState.filter { $0.clicked }.count
        
        #expect(afterCount > beforeCount, "TestApp should detect click on \(target.title ?? target.id)")
    }
}

@Test("Input source management test")
func testInputSourceManagement() async throws {
    let pilot = AppPilot()
    
    // Test current input source
    let currentSource = try await pilot.getCurrentInputSource()
    #expect(!currentSource.identifier.isEmpty)
    
    // Test available sources
    let sources = try await pilot.getAvailableInputSources()
    #expect(sources.count > 0)
    
    // Test text input with different sources
    let testApp = try await pilot.findApplication(name: "TestApp")
    let window = try await pilot.findWindow(app: testApp, title: "Keyboard")
    let textField = try await pilot.findTextField(in: window)
    
    // Type with English input
    try await pilot.type(text: "Hello", into: textField, inputSource: .english)
    
    // Type with Japanese input (if available)
    // Test Japanese composition input
    if sources.contains(where: { $0.identifier.contains("Japanese") }) {
        let result = try await pilot.input("konnichiwa", into: textField, with: .japaneseRomaji)
        #expect(result.success, "Japanese composition input should succeed")
        
        if result.needsUserDecision {
            // Test candidate selection
            let selection = try await pilot.selectCandidate(at: 0, for: textField)
            #expect(selection.success, "Candidate selection should succeed")
        }
    }
}
```

## 🛡️ Permissions

AppPilot requires specific macOS permissions to function:

### Accessibility Permission (Required)

1. Open **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
2. Click the lock to make changes
3. Add your application to the list
4. Ensure it's checked/enabled

### Application Entitlements

For sandboxed applications, add these entitlements:

```xml
<key>NSAppleEventsUsageDescription</key>
<string>AppPilot needs AppleEvents access for window management</string>

<key>com.apple.security.automation.apple-events</key>
<true/>
```

## 🎯 Supported Operations

AppPilot 1.2 provides a comprehensive set of automation operations:

### Element Discovery Operations
- `findElements(in:role:title:identifier:)` - Find UI elements with flexible criteria
- `findElement(in:role:title:)` - Find single UI element
- `findButton(in:title:)` - Find button by title
- `findTextField(in:placeholder:)` - Find text input field
- `findClickableElements(in:)` - Find all clickable elements
- `findTextInputElements(in:)` - Find all text input elements

### Element-Based Actions
- `click(element:)` - Click UI element at its center point
- `input(text:into:)` - Type text into UI element (enhanced)
- `input(_:into:with:)` - Composition input with IME support (NEW)
- `selectCandidate(at:for:)` - Select IME conversion candidate (NEW)
- `commitComposition(for:)` - Commit IME composition (NEW)
- `cancelComposition(for:)` - Cancel IME composition (NEW)
- `getValue(from:)` - Get value from UI element
- `elementExists(_:)` - Check if element is still valid

### Wait Operations  
- `wait(.time(seconds:))` - Wait for specific duration
- `wait(.elementAppear(window:role:title:))` - Wait for element to appear
- `wait(.elementDisappear(window:role:title:))` - Wait for element to disappear
- `wait(.uiChange(window:timeout:))` - Wait for UI changes
- `waitForElement(in:role:title:timeout:)` - Wait for specific element

### Input Source Management
- `getCurrentInputSource()` - Get current keyboard layout
- `getAvailableInputSources()` - List all available input sources
- `switchInputSource(to:)` - Change keyboard layout
- `type(_:inputSource:)` - Type with specific input source (fallback)

### Screen Capture
- `capture(window:)` - Capture window screenshot
- `ScreenCaptureUtility.convertToPNG(_:)` - Convert to PNG data
- `ScreenCaptureUtility.convertToJPEG(_:quality:)` - Convert to JPEG data
- `ScreenCaptureUtility.saveToFile(_:path:format:)` - Save image to file

### Fallback Coordinate Operations
- `click(window:at:button:count:)` - Click at coordinates with app focus
- `click(at:button:count:)` - Legacy coordinate click (no focus management)
- `type(text:)` - Type to focused app (fallback)
- `gesture(from:to:duration:)` - Drag gesture between points
- `drag(from:to:duration:)` - Legacy drag operation

### Application & Window Management
- `listApplications()` - Get all running applications
- `findApplication(bundleId:)` - Find app by bundle ID
- `findApplication(name:)` - Find app by name
- `listWindows(app:)` - Get windows for application
- `findWindow(app:title:)` - Find window by title
- `findWindow(app:index:)` - Find window by index

## 📚 API Reference

### Application Management

```swift
// List all applications
let apps = try await pilot.listApplications()

// Find application by bundle ID
let safari = try await pilot.findApplication(bundleId: "com.apple.Safari")

// Find application by name
let finder = try await pilot.findApplication(name: "Finder")

// Get windows for an application
let windows = try await pilot.listWindows(app: safari)

// Find specific window
let mainWindow = try await pilot.findWindow(app: safari, title: "Safari")
```

### UI Element Discovery

```swift
// Find elements with flexible criteria
let elements = try await pilot.findElements(
    in: window,
    role: .button,           // Optional: filter by role
    title: "Save",           // Optional: filter by title
    identifier: "save_btn"   // Optional: filter by identifier
)

// Specialized finders
let button = try await pilot.findButton(in: window, title: "OK")
let textField = try await pilot.findTextField(in: window, placeholder: "Enter text")
```

### Element-Based Actions

```swift
// Click discovered elements
let result = try await pilot.click(element: button)

// Type into text fields
try await pilot.type(text: "Hello World", into: textField)

// Get element values
let value = try await pilot.getValue(from: textField)

// Check element existence
let exists = try await pilot.elementExists(button)
```

### Input Source Management

```swift
// Get current input source
let currentSource = try await pilot.getCurrentInputSource()
print("Current: \(currentSource.displayName)")

// List available input sources
let sources = try await pilot.getAvailableInputSources()
for source in sources {
    print("\(source.displayName): \(source.identifier)")
}

// Switch input source and type
try await pilot.switchInputSource(to: .japanese)
try await pilot.type(text: "こんにちは", into: textField)
```

### Screen Capture

```swift
// Capture window screenshot
let image = try await pilot.capture(window: window)

// Convert to PNG data and save
if let pngData = ScreenCaptureUtility.convertToPNG(image) {
    let url = URL(fileURLWithPath: "/tmp/screenshot.png")
    try pngData.write(to: url)
}
```

## 📋 Examples

### Complete TestApp Automation

```swift
import AppPilot

let pilot = AppPilot()

// Find TestApp
let testApp = try await pilot.findApplication(name: "TestApp")
let window = try await pilot.findWindow(app: testApp, title: "Mouse Click")

// Discover all clickable targets automatically
let buttons = try await pilot.findElements(in: window, role: .button)
print("Found \(buttons.count) clickable targets")

// Click each target using element-based automation
for button in buttons where button.isEnabled {
    print("Clicking: \(button.title ?? button.id)")
    try await pilot.click(element: button)
    
    // Verify via TestApp API
    let response = try await testAppAPI.getClickTargets()
    let clickedCount = response.filter { $0.clicked }.count
    print("Targets clicked: \(clickedCount)")
    
    try await pilot.wait(.time(seconds: 0.5))
}
```

### Weather App City Search

```swift
let pilot = AppPilot()

// Find Weather app
let weatherApp = try await pilot.findApplication(bundleId: "com.apple.weather")
let window = try await pilot.findWindow(app: weatherApp, index: 0)

// Find and interact with search field
let searchField = try await pilot.findTextField(in: window)
try await pilot.click(element: searchField)
try await pilot.type(text: "Tokyo", into: searchField)

// Wait for and click search result
let tokyoResult = try await pilot.waitForElement(
    in: window,
    role: .button,
    title: "Tokyo",
    timeout: 5.0
)
try await pilot.click(element: tokyoResult)
```

### Multi-Language Text Input with IME Support

```swift
let pilot = AppPilot()

// Find text editing app
let textEdit = try await pilot.findApplication(name: "TextEdit")
let window = try await pilot.findWindow(app: textEdit, index: 0)
let textArea = try await pilot.findTextField(in: window)

// Simple English input
try await pilot.input(text: "Hello World", into: textArea)

// Japanese composition input with automatic candidate handling
let result = try await pilot.input("konnichiwa", into: textArea, with: .japaneseRomaji)

// Handle IME candidates if user decision is needed
if result.needsUserDecision {
    if let candidates = result.compositionCandidates {
        print("Available candidates: \(candidates)")
        // Example: ["こんにちは", "こんにちわ", "今日は"]
        
        // Select the first candidate (こんにちは)
        let selection = try await pilot.selectCandidate(at: 0, for: textArea)
        
        // Commit the composition
        if !selection.isCompositionCompleted {
            try await pilot.commitComposition(for: textArea)
        }
    }
}

// Chinese input with Pinyin
let chineseResult = try await pilot.input("ni hao", into: textArea, with: .chinesePinyin)
// Handles: "ni hao" → "你好" with candidate selection if needed

// Korean input
let koreanResult = try await pilot.input("annyeong", into: textArea, with: .korean)
// Handles: "annyeong" → "안녕" with automatic composition

// Direct input (bypasses IME for final text)
try await pilot.input("こんにちは", into: textArea) // Direct hiragana input
```

### Advanced IME Composition Workflow

```swift
let pilot = AppPilot()

// Setup
let app = try await pilot.findApplication(name: "TextEdit")
let window = try await pilot.findWindow(app: app, index: 0)
let textField = try await pilot.findTextField(in: window)

// Complex Japanese input workflow
let inputResult = try await pilot.input("arigatougozaimasu", into: textField, with: .japaneseRomaji)

// Check if the IME presents multiple conversion candidates
if case .candidateSelection(_, let candidates, let selectedIndex) = inputResult.compositionData?.state {
    print("Candidates available:")
    for (index, candidate) in candidates.enumerated() {
        let marker = index == selectedIndex ? "👉" : "  "
        print("\(marker) \(index): \(candidate)")
    }
    
    // Select different candidate if needed
    if selectedIndex != 0 {
        try await pilot.selectCandidate(at: 0, for: textField)
    }
    
    // Commit the final selection
    try await pilot.commitComposition(for: textField)
} else if case .committed(let finalText) = inputResult.compositionData?.state {
    print("Automatically committed: \(finalText)")
}

// Cancel composition if needed
if inputResult.needsUserDecision {
    // User decides to cancel
    try await pilot.cancelComposition(for: textField)
}
```

## 🐛 Error Handling

AppPilot provides comprehensive error handling:

```swift
public enum PilotError: Error {
    case permissionDenied(String)
    case applicationNotFound(String)
    case windowNotFound(WindowHandle)
    case elementNotFound(role: ElementRole, title: String?)
    case elementNotAccessible(String)
    case multipleElementsFound(role: ElementRole, title: String?, count: Int)
    case timeout(TimeInterval)
    case osFailure(api: String, code: Int32)
}
```

Handle errors gracefully:

```swift
do {
    let button = try await pilot.findButton(in: window, title: "Submit")
    try await pilot.click(element: button)
} catch PilotError.elementNotFound(let role, let title) {
    print("Button '\(title ?? "unknown")' not found")
    // Fallback to coordinate-based clicking
    try await pilot.click(window: window, at: Point(x: 200, y: 300))
} catch PilotError.permissionDenied(let message) {
    print("Permission required: \(message)")
}
```

## 🔄 Migration Guide

### Key Changes in 1.2

- **Element-First Approach**: UI elements are discovered before actions
- **Smart Targeting**: Find elements by semantic properties, not coordinates
- **Automatic Coordinate Calculation**: No manual coordinate math required
- **Better Error Messages**: Descriptive errors about missing elements
- **Input Source Management**: Built-in support for multi-language input
- **Enhanced Wait Operations**: Wait for specific UI element conditions
- **Improved Testing**: Swift Testing framework with TestApp integration

### Migration Examples

#### Basic Click Operations
```swift
// v2.0: Hardcoded coordinate clicking
try await pilot.click(window: window, at: Point(x: 534, y: 228))

// 1.2: Smart element discovery and clicking
let button = try await pilot.findButton(in: window, title: "Submit")
try await pilot.click(element: button)
```

#### Text Input
```swift
// v2.0: Focus app and type blindly
try await pilot.type(text: "Hello World")

// 1.2: Find text field and type into it
let textField = try await pilot.findTextField(in: window)
try await pilot.type(text: "Hello World", into: textField)
```

#### Element Discovery
```swift
// v2.0: No element discovery, manual coordinate calculation
let buttonCenter = Point(x: 200, y: 150)
try await pilot.click(window: window, at: buttonCenter)

// 1.2: Automatic element discovery and interaction
let allButtons = try await pilot.findElements(in: window, role: .button)
for button in allButtons where button.isEnabled {
    try await pilot.click(element: button)  // Automatically uses element.centerPoint
}
```

#### Wait Operations
```swift
// v2.0: Fixed time waits
try await Task.sleep(nanoseconds: 2_000_000_000)

// 1.2: Semantic wait conditions
try await pilot.waitForElement(in: window, role: .button, title: "Continue", timeout: 10.0)
try await pilot.wait(.elementDisappear(window: window, role: .dialog, title: "Loading"))
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `swift test`
6. Submit a pull request

## 📄 License

AppPilot is available under the MIT license. See LICENSE file for details.

## 🆘 Support

- **Documentation**: Check the inline documentation and examples
- **Issues**: Report bugs and feature requests on GitHub
- **Discussions**: Join the community discussions for help and tips

---

**AppPilot 1.2** - Intelligent UI automation for the modern Mac
