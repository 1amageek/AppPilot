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

## SDK Overview

AppPilot is a macOS automation SDK that enables background app control without requiring visible windows or focus. It provides a robust three-layer command routing system (AppleEvent → AX-Action → UI-Event) with automatic fallback.

### Key Features
- **Background Operation**: Control apps in minimized state or different Spaces
- **Three-Layer Command Strategy**: AppleEvent, Accessibility API, and UI Events with automatic fallback
- **Space-Aware**: Works across Mission Control Spaces
- **Live AX Monitoring**: Real-time UI change notifications via AsyncStream
- **Visibility Orchestration**: Temporary window state management with precise restoration

### Design Principles
1. **Multi-Route Command**: Three-layer strategy with automatic fallback
2. **CQS & Actor**: Command methods prefixed with `command*`, queries with `list*`
3. **Visibility Orchestration**: Temporary unminimize/space movement with restoration
4. **Space-Aware**: Full Mission Control/Spaces support
5. **Live AX Stream**: `AsyncStream<AXEvent>` for real-time UI monitoring
6. **Driver DI**: Protocol-based OS dependencies for testability
7. **Minimal Permissions**: Operates with minimum required TCC permissions

### Architecture

```
                 ┌─────────────── Pilot / Facade ───────────────┐
                 │      AppPilot (actor)                         │
                 │  ├─ CommandRouter   ← Three-layer strategy    │
                 │  ├─ VisibilityMgr   (minimize/Space control)  │
                 │  ├─ SpaceController (MissionControl Driver)   │
                 │  └─ LiveAXHub       (AXObserver → AsyncStream)│
      ┌──────────┴──────────┬──────────┴──────────┬────────────┐
      ▼                     ▼                     ▼            ▼
  Domain Layer       Bridge Layer          Driver Layer    Support Layer
 Selector etc.       Type conversion   AppleEvent/AX/UIEvent   Common types
```

### Core Types

```swift
public struct AppID:    Hashable, Sendable { let pid: pid_t }
public struct WindowID: Hashable, Sendable { let id : CGWindowID }

public enum Route   { case APPLE_EVENT, AX_ACTION, UI_EVENT }
public enum Policy  {
    case STAY_HIDDEN
    case UNMINIMIZE(tempMs: Int = 150)
    case BRING_FORE_TEMP(restore: AppID)
}

public enum WaitSpec {
    case time(ms: Int)
    case ui_change(window: WindowID, timeoutMs: Int)
}
```

### Main API (AppPilot actor)

Query methods:
- `listApplications()` - Get all running applications
- `listWindows(in:)` - Get windows for an application
- `capture(window:)` - Screenshot a window
- `accessibilityTree(window:depth:)` - Get AX tree
- `subscribeAX(window:mask:)` - Subscribe to UI changes

Command methods:
- `click(window:at:button:count:policy:route:)` - Click at coordinates
- `type(text:into:policy:route:)` - Type text
- `gesture(window:_:policy:durationMs:)` - Perform gestures
- `performAX(window:path:action:)` - Direct AX actions
- `sendAppleEvent(app:spec:)` - Send AppleEvents
- `wait(_:)` - Wait for time or UI changes

### Command Routing Algorithm

```
selectRoute(cmd, window):
  if route param specified -> use it
  else if cmd.kind == gesture
       -> .UI_EVENT               // AppleEvent/AX can't do gestures
  else if AppleEventDriver.supports(cmd, app)
       -> .APPLE_EVENT
  else if AccessibilityDriver.canPerform(cmd, window)
       -> .AX_ACTION
  else -> .UI_EVENT
```

### Error Types

```swift
enum PilotError : Error {
   case PERMISSION_DENIED(PermissionKind)
   case NOT_FOUND(EntityKind, String?)
   case ROUTE_UNAVAILABLE(String)       // All 3 routes failed
   case VISIBILITY_REQUIRED(String)     // UI-Event required but visibility failed
   case USER_INTERRUPTED
   case STREAM_OVERFLOW
   case OS_FAILURE(api:String, status:Int32)
   case INVALID_ARG(String)
   case TIMEOUT(ms:Int)
}
```

### Required Entitlements

```xml
<key>com.apple.security.automation.apple-events</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
```

### Usage Example

```swift
let pilot = AppPilot()

// List all applications
let apps = try await pilot.listApplications()

// Click a button in a minimized window
let result = try await pilot.click(
    window: windowID,
    at: Point(x: 100, y: 200),
    policy: .STAY_HIDDEN  // Operates without unminimizing
)

// Subscribe to UI changes
for await event in pilot.subscribeAX(window: windowID) {
    print("UI changed: \(event)")
}
```

### Testing Strategy

**IMPORTANT: This project uses Swift Testing framework, NOT XCTest.**

#### Swift Testing Framework (Swift 6 Native)
- Use `@Test` macro instead of XCTest methods
- Use `@Suite` for organizing test groups  
- Use `#expect()` for assertions instead of `XCTAssert*`
- Native Swift 6 support - no external dependencies needed
- Swift Testing provides better async/await support and more modern testing patterns

#### Test Configuration
- **Framework**: Swift Testing (native in Swift 6.1+)
- **Package.swift**: No external dependencies required for testing
- **Test Organization**: Use `@Suite` with descriptive names and tags
- **Assertions**: Use `#expect()` with clear failure messages
- **Async Testing**: Full async/await support with proper error handling

#### Test Structure Example
```swift
import Testing
@testable import AppPilot

@Suite("Test Suite Name")
struct MyTests {
    @Test("Test description", .tags(.unit, .integration))
    func testSomething() async throws {
        let result = try await someAsyncOperation()
        #expect(result.success == true, "Operation should succeed")
    }
}
```

#### Test Types
- **Unit Tests**: 100% coverage for Domain layer, Mock drivers for event verification
- **Integration Tests**: Multi-Space app placement, E2E state machine verification
- **Audit Logs**: All operations logged to `~/.apppilot/logs/YYYY-MM-DD.log`

#### Common Issues and Solutions

**Root Cause Analysis - Compilation Issues:**

1. **Missing Swift Testing Module (_TestingInternals)**
   - **Root Cause**: External swift-testing package conflicts with native Swift 6 Testing
   - **Solution**: Remove external dependency, use native Swift 6 Testing
   - **Fix**: Clean Package.swift dependencies, rely on built-in Testing module

2. **Data Race Warnings in Concurrent Tests**
   - **Root Cause**: Shared mutable state accessed from multiple tasks without synchronization
   - **Solution**: Use actors for thread-safe shared state management
   - **Example**: Replace `var sharedArray` with actor-based synchronization

3. **Unnecessary await/async Warnings**
   - **Root Cause**: Calling non-async functions with await keyword
   - **Solution**: Remove await for synchronous function calls
   - **Check**: Verify function signatures before adding await

4. **Unused Variable Warnings**
   - **Root Cause**: Variables declared but not used in test code
   - **Solution**: Replace with `_` or `let _ = value` for intentionally unused values
   - **Best Practice**: Use descriptive variable names when values are actually needed

#### Testing Best Practices
- Use descriptive test names and failure messages
- Organize tests with appropriate tags (.unit, .integration, .performance)
- Handle async operations properly with try await
- Use actors for shared state in concurrent tests
- Keep test methods focused and independent
- Use mock drivers for isolated unit testing

## Implementation Status

✅ **Completed Components:**
- Support Layer (Types, Errors)
- Domain Layer (Commands)
- Driver Layer (Protocols with Mock implementations)
- Bridge Layer (Coordinate conversion)
- Pilot Layer (AppPilot facade, CommandRouter, VisibilityManager, SpaceController, LiveAXHub)
- Complete test suite with 5 passing tests
- Example usage code

🔧 **Requires Implementation:**
- Actual macOS API integration (currently using placeholder implementations)
- Real AppleEvent/AX/UIEvent driver implementations
- Mission Control private API integration
- Audit logging system
- Permission checking utilities

## File Structure

```
Sources/AppPilot/
├── Support/
│   ├── Types.swift          # Core types and data structures
│   └── Errors.swift         # Error definitions
├── Domain/
│   └── Command.swift        # Command definitions
├── Driver/
│   ├── AppleEventDriver.swift     # AppleEvent protocol & mocks
│   ├── AccessibilityDriver.swift  # AX API protocol & mocks
│   ├── UIEventDriver.swift        # UI Event protocol & mocks
│   ├── ScreenDriver.swift         # Screen capture protocol & mocks
│   └── MissionControlDriver.swift # Mission Control protocol & mocks
├── Bridge/
│   └── CoordinateConverter.swift  # Coordinate system conversions
└── Pilot/
    ├── AppPilot.swift         # Main facade actor
    ├── CommandRouter.swift    # Three-layer routing strategy
    ├── VisibilityManager.swift # Window visibility management
    ├── SpaceController.swift   # Mission Control integration
    └── LiveAXHub.swift        # Real-time AX event streaming
```

## Testing Specifications - App Pilot v1.0

*Comprehensive testing plan for SDK + TestApp + TestRunner integration*

### Test Objectives

| ID | Purpose |
|----|---------|
| **F-1** | Verify SDK can control macOS apps **regardless of visibility/Space/minimized state** |
| **F-2** | Prove three-layer command strategy (AppleEvent → AX-Action → UI-Event) **auto-selection and fallback** works as specified |
| **F-3** | Achieve **95%+ success rate** for click/input/wait/resolve operations against TestApp |
| **NF-1** | Ensure **no exceptions/memory leaks/visual flicker** during 1-hour stress test |
| **NF-2** | Maintain **<10ms average response time (±2ms)** for major API calls |

### Test Environment Requirements

| Component | Requirement |
|-----------|-------------|
| **macOS** | Ventura 13.6+ / Sonoma 14.2+ |
| **Hardware** | Apple Silicon (M1/M2) with 8GB+ RAM |
| **Xcode** | 15.2+ with Swift 6.1 toolchain |
| **Permissions** | Accessibility, Screen Recording, Automation granted |
| **CI/CD** | GitHub Actions macos-14 runner + self-hosted M1 |
| **Test Scenario** | Mission Control Space 3 with TestApp minimized |

### Test Levels & Frameworks

| Level | Framework | Execution |
|-------|-----------|-----------|
| **Unit** | Swift Testing (native) (`Tests/AppPilotTests`) | `swift test --filter AppPilotTests` |
| **E2E/UI** | TestRunner CLI (JUnit XML output) | `swift TestRunner/main.swift --test full -o results.xml` |
| **UITest** | Swift Testing UI (`TestAppUITests`) | `xcodebuild -scheme TestApp -destination 'platform=macOS' test` |
| **Stress** | Shell script + TestRunner loops | `./scripts/stress.sh 3600` |

### Test Cases

#### Click Target Verification (CT)

| ID | Procedure | Expected Result |
|----|-----------|----------------|
| **CT-01** | Click 5 targets in Space 3 minimized TestApp with `Policy.UNMINIMIZE()` | All targets `clicked=true`, `route=UI_EVENT` |
| **CT-02** | Same as CT-01 with AppleEvent disabled (`MockAppleEventDriver.setSupportedCommands([])`) | Success with fallback to `route=AX_ACTION` |
| **CT-03** | Same as CT-01 with AX disabled (`MockAccessibilityDriver.setCanPerform(false)`) | Success with `route=UI_EVENT` |

#### Keyboard Input Precision (KB)

| ID | Text Input | Procedure | Success Criteria |
|----|------------|-----------|------------------|
| **KB-01** | "Hello123" | Type with `policy=.STAY_HIDDEN` → verify TestApp field | `matches=true` |
| **KB-02** | "こんにちは世界" | Same procedure | `accuracy ≥ 0.98` |
| **KB-03** | Control chars | Same procedure | `accuracy ≥ 0.95`, proper newline/tab handling |

#### Wait Timing Accuracy (WT)

| ID | Condition | Procedure | Expected Precision |
|----|-----------|-----------|-------------------|
| **WT-01** | `WaitSpec.time(1500ms)` | Execute `wait()` | Actual error ≤ ±50ms |
| **WT-02** | `WaitSpec.ui_change(window, 5000ms)` + TestApp UIToggle | Detect event and return immediately | No timeout |

#### Route Selection Algorithm (RT)

| Condition | Command | Expected Route |
|-----------|---------|----------------|
| App is AppleScriptable | click | `.APPLE_EVENT` |
| Scriptable=false, AX=true | click | `.AX_ACTION` |
| Gesture drag operation | gesture | `.UI_EVENT` (fixed) |

#### Visibility & Space Restoration (VS)

**Test Procedure:**
1. Place TestApp in Space 4, minimized
2. Execute click with `Policy.BRING_FORE_TEMP(restore: Finder)`
3. Verify post-completion state:
   - Finder returned to foreground
   - TestApp window back in Space 4 and minimized

#### Stress/Regression Testing (ST)

**Requirements:**
- Execute `random-click` & `random-type` operations 10,000 times (1 hour)
- Memory: RSS growth < 15MB
- No ERROR entries in logger

### Success Metrics

| Metric | Measurement Method | Pass Criteria |
|--------|-------------------|---------------|
| **Success Rate** | JUnit XML (TestRunner) `successRate` | All scenarios ≥ 0.95 |
| **Response Time** | TestRunner `--verbose` log aggregation | 10ms ±2ms average |
| **Memory Usage** | `/usr/bin/time -l TestRunner` | Growth < 15MB |
| **Process Count** | `ps -M` subprocess monitoring | < 2 forks |

### TestApp API Server

The TestApp includes an embedded HTTP API server for integration testing:

**Base URL:** `http://localhost:8765`

**Key Endpoints:**
- `GET /api/state` - Complete test state (all data)
- `GET /api/targets` - Click target states only  
- `GET /api/keyboard-tests` - Keyboard test results
- `GET /api/wait-tests` - Wait test results
- `POST /api/session/start` - Start new test session
- `POST /api/session/end` - End current test session
- `POST /api/reset` - Reset all test states

**Example Usage:**
```bash
# Check if top-left button was clicked
curl http://localhost:8765/api/targets | jq '.[0].clicked'

# Get keyboard test accuracy
curl http://localhost:8765/api/keyboard-tests | jq '.[].accuracy'

# Start automated test session
curl -X POST http://localhost:8765/api/session/start
```

### TestRunner CLI Tool

Located at `TestRunner/main.swift`, provides automated test execution:

**Usage:**
```bash
# Run specific test suite
swift TestRunner/main.swift --test click
swift TestRunner/main.swift --test keyboard
swift TestRunner/main.swift --test wait

# Run full test suite with XML output
swift TestRunner/main.swift --test full --output results.xml

# Custom server URL with verbose output
swift TestRunner/main.swift --url http://localhost:8080 --verbose
```

**Features:**
- Health check verification
- Test session management
- JUnit XML output for CI/CD integration
- Detailed progress reporting
- Error handling and recovery

### CI/CD Pipeline Integration

```yaml
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build SDK
        run: swift build -c release
      - name: Unit Tests
        run: swift test --parallel
      - name: Build & Launch TestApp
        run: |
          xcodebuild -scheme TestApp -derivedDataPath ./dd build
          open ./dd/Build/Products/Debug/TestApp.app
          sleep 5
      - name: E2E Tests
        run: swift TestRunner/main.swift --test full -o results.xml
      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: junit-results
          path: results.xml
```

### Defect Management

**Failure Protocol:**
- Attach **SDK logs + TestRunner verbose output + macOS Console logs**
- Create GitHub Issue with failure reproduction steps
- Fix implementation → rerun affected test cases → verify pass → close issue

### Future Test Enhancements (v1.1+)

- **Accessibility Sandbox**: Automated UI mock environment
- **Multi-Display Matrix**: Internal + external 4K display testing
- **Energy Impact**: Battery consumption benchmarking
- **Performance Profiling**: Memory allocation and CPU usage analysis