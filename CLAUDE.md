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

## Project Architecture

This is a Swift Package Manager (SPM) library project named "AppPilot" targeting macOS 15+. The project uses Swift 6.1 and follows the standard SPM structure:

- **Package.swift**: Defines the package configuration, dependencies, and targets
- **Sources/AppPilot/**: Contains the main library implementation
- **Tests/AppPilotTests/**: Contains unit tests using Swift Testing framework (not XCTest)

The project uses the new Swift Testing framework with `@Test` macro annotations instead of the traditional XCTest framework.

## AppPilot v2.0 - CGEvent-Only Automation SDK

### Overview

AppPilot v2.0 is a macOS automation SDK focused on **reliability and simplicity**. It uses CGEvent (UI simulation) exclusively for universal compatibility across all macOS applications.

### Core Design Philosophy

1. **Simplicity Over Complexity**: Single automation method (CGEvent) instead of multiple fallback strategies
2. **Screen-Coordinate Based**: Direct automation using global screen coordinates
3. **Universal Compatibility**: Works with every macOS app type without exceptions
4. **Foreground Operation**: All operations require windows to be visible and unminimized

### Supported Operations

```swift
// Core automation operations
click(window:at:)                // Click at coordinates on screen
type(text:)                      // Type text to focused application
gesture(from:to:)                // Perform drag/swipe gestures
wait(spec:)                      // Wait for time or UI changes

// Query operations  
listApplications()               // Get running applications
listWindows(app:)               // Get windows for application
capture(window:)                // Screenshot window
```

### Architecture

```
┌─────────────── AppPilot (Actor) ───────────────┐
│  • Screen coordinate automation only            │
│  • CGEvent-driven UI simulation                 │
│  • Window coordinate conversion                 │
│  • Real-time AX event monitoring               │
└─────────────────────────────────────────────────┘
               │
      ┌────────┴────────┐
      ▼                 ▼
┌──────────┐    ┌──────────────┐
│ CGEvent  │    │ Coordinate   │
│ Driver   │    │ Converter    │
│          │    │              │
│ Mouse &  │    │ Window → Screen │
│ Keyboard │    │ Conversion   │
└──────────┘    └──────────────┘
```

### Core Types

```swift
public struct AppID: Hashable, Sendable { 
    let pid: pid_t 
}

public struct WindowID: Hashable, Sendable { 
    let id: CGWindowID 
}

public struct Point: Sendable {
    let x: CGFloat
    let y: CGFloat
}

// Visibility enum removed - not applicable for CGEvent automation

public enum MouseButton: Sendable {
    case left, right, center
}

public struct ActionResult: Sendable {
    let success: Bool
    let timestamp: Date
    let coordinates: Point?
}
```

### Main API

```swift
public actor AppPilot {
    
    // MARK: - Query Operations
    
    /// Get all running applications
    public func listApplications() async throws -> [AppInfo]
    
    /// Get windows for an application
    public func listWindows(app: AppID) async throws -> [WindowInfo]
    
    /// Capture screenshot of window
    public func capture(window: WindowID) async throws -> CGImage
    
    /// Subscribe to UI changes in window
    public func subscribeAX(window: WindowID) -> AsyncStream<AXEvent>
    
    // MARK: - Automation Operations
    
    /// Click at coordinates (window-relative coordinates converted to screen)
    public func click(
        window: WindowID,
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1
    ) async throws -> ActionResult
    
    /// Type text to currently focused application
    public func type(
        text: String
    ) async throws -> ActionResult
    
    /// Perform gesture from point to point
    public func gesture(
        from startPoint: Point,
        to endPoint: Point,
        duration: TimeInterval = 1.0
    ) async throws -> ActionResult
    
    /// Wait for condition
    public func wait(_ spec: WaitSpec) async throws
}

public enum WaitSpec {
    case time(seconds: TimeInterval)
    case uiChange(window: WindowID, timeout: TimeInterval)
}
```

### Implementation Strategy

#### 1. Coordinate System
- **Input**: Window-relative coordinates (origin: top-left)
- **Conversion**: Automatic conversion to screen coordinates
- **Output**: CGEvent with global screen coordinates

#### 2. Coordinate Conversion
```swift
func convertWindowToScreenCoordinates(
    point: Point,
    window: WindowID
) async throws -> CGPoint {
    // Get window bounds from system
    guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.id) as? [[String: Any]],
          let windowInfo = windowList.first,
          let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
          let windowX = boundsDict["X"] as? CGFloat,
          let windowY = boundsDict["Y"] as? CGFloat else {
        throw PilotError.windowNotFound(window)
    }
    
    // Convert window-relative to screen coordinates
    let screenX = windowX + point.x
    let screenY = windowY + point.y
    
    return CGPoint(x: screenX, y: screenY)
}
```

#### 3. CGEvent Implementation
```swift
func performClick(at point: Point, button: MouseButton) throws {
    let cgPoint = CGPoint(x: point.x, y: point.y)
    
    // Create mouse down event
    guard let downEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: button.downType,
        mouseCursorPosition: cgPoint,
        mouseButton: button.cgButton
    ) else {
        throw PilotError.eventCreationFailed
    }
    
    // Create mouse up event
    guard let upEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: button.upType,
        mouseCursorPosition: cgPoint,
        mouseButton: button.cgButton
    ) else {
        throw PilotError.eventCreationFailed
    }
    
    // Post events
    downEvent.post(tap: .cghidEventTap)
    upEvent.post(tap: .cghidEventTap)
}
```

### Error Handling

```swift
public enum PilotError: Error, Sendable {
    case permissionDenied(String)
    case windowNotFound(WindowID)
    case applicationNotFound(AppID)
    case eventCreationFailed
    case coordinateOutOfBounds(Point)
    case timeout(TimeInterval)
    case osFailure(api: String, code: Int32)
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

```swift
let pilot = AppPilot()

// Find target application
let apps = try await pilot.listApplications()
let testApp = apps.first { $0.name == "TestApp" }!

// Get windows
let windows = try await pilot.listWindows(app: testApp.id)
let mainWindow = windows.first!

// Click button (window must be visible and unminimized)
let result = try await pilot.click(
    window: mainWindow.id,
    at: Point(x: 100, y: 50)
)

// Type text (application must be focused)
try await pilot.type(text: "Hello World")

// Perform drag gesture (screen coordinates)
try await pilot.gesture(
    from: Point(x: 100, y: 100),
    to: Point(x: 200, y: 200),
    duration: 0.5
)
```

### Design Decisions & Trade-offs

#### ✅ Benefits
- **Universal Compatibility**: Works with ALL macOS apps (SwiftUI, AppKit, Electron, Web)
- **Predictable Behavior**: Every operation works consistently  
- **Simple Architecture**: No complex routing or fallback logic
- **Easy Testing**: Reliable results for automated testing
- **Real User Simulation**: CGEvent most closely mimics actual user input

#### ❌ Limitations Accepted
- **Cursor Movement**: All operations move the cursor visibly
- **Foreground Only**: Windows must be visible and unminimized
- **User Interruption**: Operations are visible to the user
- **Requires Accessibility**: Must grant Accessibility permission
- **No Background Operation**: Cannot operate while user is working

#### 🚫 Removed Features (from v1.0)
- Multiple automation routes (AppleEvent, AX, etc.)
- Complex strategy tables and route selection
- Stealth mode capabilities
- Background/minimized window operation
- Visibility preference management
- App-type specific optimizations
- Multiple driver architectures

### Implementation Status

✅ **Design Complete**: New simplified architecture defined
🔧 **Implementation Needed**: 
- Rewrite CommandRouter for CGEvent-only operation
- Simplify driver layer (UIEventDriver only)
- Update all API signatures to remove route parameters
- Implement coordinate conversion utilities
- Create window state management system

### Testing Strategy

Tests focus on coordinate accuracy and reliability:

```swift
@Test("Click accuracy test")
func testClickAccuracy() async throws {
    let pilot = AppPilot()
    let result = try await pilot.click(
        window: testWindow,
        at: Point(x: 100, y: 50)
    )
    
    #expect(result.success)
    #expect(result.coordinates?.x == 100)
    #expect(result.coordinates?.y == 50)
}
```

This new design prioritizes **reliability and simplicity** over complexity and stealth capabilities.