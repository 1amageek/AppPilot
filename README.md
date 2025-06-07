# AppPilot

**UI Element-Based macOS Automation SDK**

AppPilot is a modern Swift Package Manager library that provides intelligent UI automation for macOS applications. Instead of relying on brittle coordinate-based automation, AppPilot discovers actual UI elements using Accessibility APIs and performs smart, element-based operations.

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## 🌟 Features

- **🎯 Smart Element Discovery**: Find UI elements by role, title, and identifier
- **🖱️ Element-Based Actions**: Click buttons, fill text fields, and interact with UI components
- **🔍 Automatic Coordinate Calculation**: No need to manually calculate button centers
- **🚀 Universal Compatibility**: Works with SwiftUI, AppKit, Electron, and web applications
- **⏰ Intelligent Waiting**: Wait for elements to appear or conditions to be met
- **📷 Screen Capture**: Take screenshots of windows and UI elements
- **🔄 Graceful Fallback**: Coordinate-based automation when element detection fails
- **🛡️ Type Safety**: Built with Swift 6.1 and modern concurrency

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
    .package(url: "https://github.com/your-username/AppPilot.git", from: "1.0.0")
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

AppPilot includes a comprehensive test suite using Swift Testing framework:

```bash
# Run all tests
swift test

# Run specific test categories
swift test --filter ".unit"
swift test --filter ".integration"

# Run with specific test
swift test --filter "testElementDiscovery"

# Build the project
swift build
```

### TestApp Integration

The project includes a dedicated TestApp for comprehensive automation testing:

```swift
@Test("Element-based TestApp automation")
func testTestAppIntegration() async throws {
    let pilot = AppPilot()
    let testApp = try await pilot.findApplication(name: "TestApp")
    let window = try await pilot.findWindow(app: testApp, title: "Mouse Click")
    
    // Discover all clickable targets
    let buttons = try await pilot.findElements(in: window, role: .button)
    
    // Click each target and verify via API
    for button in buttons {
        try await pilot.click(element: button)
        // Verify through TestApp's REST API
        let state = try await testAppAPI.getClickTargets()
        #expect(state.filter { $0.clicked }.count > 0)
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

### Screen Capture

```swift
// Capture window screenshot
let image = try await pilot.capture(window: window)

// Save to file
let url = URL(fileURLWithPath: "/tmp/screenshot.png")
try image.savePNG(to: url)
```

## 📋 Examples

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

### Safari Web Automation

```swift
let pilot = AppPilot()

// Find Safari
let safari = try await pilot.findApplication(bundleId: "com.apple.Safari")
let window = try await pilot.findWindow(app: safari, index: 0)

// Navigate to website
let addressBar = try await pilot.findTextField(in: window, identifier: "address_bar")
try await pilot.click(element: addressBar)
try await pilot.type(text: "https://example.com", into: addressBar)

// Press Enter
try await pilot.type(text: "\r")

// Wait for page to load and find elements
try await pilot.wait(.time(seconds: 3.0))
let links = try await pilot.findElements(in: window, role: .link)
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

## 🔄 Migration from v2.0

### Key Changes

- **Element-First Approach**: UI elements are now discovered before actions
- **Smart Targeting**: Find elements by semantic properties, not coordinates
- **Automatic Coordinate Calculation**: No manual coordinate math required
- **Better Error Messages**: Descriptive errors about missing elements

### Migration Example

```swift
// v2.0: Coordinate-based
try await pilot.click(window: window, at: Point(x: 534, y: 228))

// v3.0: Element-based
let button = try await pilot.findButton(in: window, title: "Submit")
try await pilot.click(element: button)
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

**AppPilot v3.0** - Intelligent UI automation for the modern Mac
