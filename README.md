# 🚁 AppPilot

> **Elite macOS Automation SDK**  
> Control any macOS application from the shadows — no windows, no focus, no limits.

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15+-blue.svg)](https://developer.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## ✨ What Makes AppPilot Special

AppPilot isn't just another automation framework — it's a **stealth operations SDK** that gives you unprecedented control over macOS applications, even when they're minimized, hidden, or running in different Mission Control Spaces.

### 🎯 Core Superpowers

- **🥷 Background Operations**: Control apps without bringing them to the foreground
- **🎛️ Three-Layer Command Strategy**: AppleEvent → Accessibility → UI Events with smart fallback
- **🌌 Space-Aware**: Works seamlessly across Mission Control Spaces
- **⚡ Live UI Monitoring**: Real-time UI change notifications via AsyncStream
- **🎭 Visibility Orchestration**: Temporary window management with pixel-perfect restoration
- **🛡️ Minimal Permissions**: Operates with the least required system access

### 🏗️ Architecture at a Glance

```
┌─────────────── 🎯 Pilot / Facade ───────────────┐
│      AppPilot (actor)                            │
│  ├─ CommandRouter   ← Three-layer strategy      │
│  ├─ VisibilityMgr   (minimize/Space control)    │
│  ├─ SpaceController (MissionControl Driver)     │
│  └─ LiveAXHub       (AXObserver → AsyncStream)  │
└──────────┬──────────┬──────────┬────────────────┘
           ▼          ▼          ▼
    🎯 Domain    🌉 Bridge   🚗 Drivers   📦 Support
   Commands     Coordinates  AX/Event/MC    Types
```

## 🚀 Quick Start

### Installation

Add AppPilot to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AppPilot.git", from: "1.0.0")
]
```

### Basic Usage

```swift
import AppPilot

let pilot = AppPilot()

// 🔍 Discover applications and windows
let apps = try await pilot.listApplications()
let windows = try await pilot.listWindows(in: apps.first!.id)

// 🖱️ Click without bringing window to front
let result = try await pilot.click(
    window: windows.first!.id,
    at: Point(x: 100, y: 200),
    policy: .STAY_HIDDEN  // 🥷 Stealth mode
)

// ⌨️ Type text in background
try await pilot.type(
    text: "Hello from the shadows!",
    into: windows.first!.id,
    policy: .STAY_HIDDEN
)

// 👀 Monitor UI changes in real-time
for await event in pilot.subscribeAX(window: windows.first!.id) {
    print("UI changed: \(event.type) at \(event.timestamp)")
}
```

## 🎯 Core Concepts

### Command Policies

Control how AppPilot interacts with target applications:

```swift
public enum Policy {
    case STAY_HIDDEN                           // 🥷 Operate in stealth
    case UNMINIMIZE(tempMs: Int = 150)        // 📱 Briefly unminimize
    case BRING_FORE_TEMP(restore: AppID)      // 🔄 Temporary focus
}
```

### Smart Route Selection

AppPilot automatically chooses the best approach for each command:

```swift
public enum Route {
    case APPLE_EVENT  // 📨 High-level scripting
    case AX_ACTION    // ♿ Accessibility API
    case UI_EVENT     // 🖱️ Low-level events
}
```

### Wait Specifications

Precise timing control for complex automation workflows:

```swift
public enum WaitSpec {
    case time(ms: Int)                                    // ⏱️ Simple delay
    case ui_change(window: WindowID, timeoutMs: Int)     // 🎯 Event-driven
}
```

## 🧪 Testing Framework

AppPilot uses **Swift Testing** (Swift 6 native) for comprehensive test coverage:

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter ".unit"
swift test --filter ".integration"

# Build the project
swift build
```

### Test Architecture

- **Unit Tests**: Mock drivers with 100% coverage
- **Integration Tests**: Real macOS API testing with TestApp
- **Stress Tests**: 1-hour endurance testing
- **Performance Tests**: <10ms response time validation

## 🛠️ Development Setup

### Prerequisites

- **macOS**: Ventura 13.6+ or Sonoma 14.2+
- **Xcode**: 15.2+ with Swift 6.1 toolchain
- **Hardware**: Apple Silicon (M1/M2) recommended

### Required Permissions

Add these entitlements to your app:

```xml
<key>com.apple.security.automation.apple-events</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
```

Grant these system permissions:
- ✅ Accessibility
- ✅ Screen Recording
- ✅ Automation

### Building

```bash
# Clean build
swift package clean

# Build release
swift build -c release

# Generate Xcode project
swift package generate-xcodeproj
```

## 📚 API Reference

### Main AppPilot Actor

**Query Methods** (prefixed with `list*`):
- `listApplications()` → `[AppInfo]`
- `listWindows(in: AppID)` → `[WindowInfo]`
- `capture(window: WindowID)` → `CGImage`
- `accessibilityTree(window: WindowID, depth: Int)` → `AXElement`

**Command Methods** (prefixed with `command*` or action verbs):
- `click(window:at:button:count:policy:route:)` → `CommandResult`
- `type(text:into:policy:route:)` → `CommandResult`
- `gesture(window:_:policy:durationMs:)` → `CommandResult`
- `performAX(window:path:action:)` → `CommandResult`
- `sendAppleEvent(app:spec:)` → `CommandResult`
- `wait(_:)` → `Void`

**Streaming Methods**:
- `subscribeAX(window:mask:)` → `AsyncStream<AXEvent>`

## 🎨 Examples

Explore the `Examples/` directory for comprehensive usage patterns:

- **BasicUsage.swift**: Getting started guide
- **TestApp/**: Full integration testing application
- **Advanced patterns**: Coming soon

## 🔧 Error Handling

AppPilot provides detailed error information:

```swift
enum PilotError: Error {
    case PERMISSION_DENIED(PermissionKind)
    case NOT_FOUND(EntityKind, String?)
    case ROUTE_UNAVAILABLE(String)
    case VISIBILITY_REQUIRED(String)
    case TIMEOUT(ms: Int)
    case OS_FAILURE(api: String, status: Int32)
}
```

## 🚦 Project Status

**✅ Completed:**
- Core architecture and actor system
- Three-layer command routing
- Mock driver implementations
- Comprehensive test suite
- Documentation and examples

**🔧 In Development:**
- Production macOS API implementations
- Mission Control private API integration
- Audit logging system
- Performance optimizations

## 🤝 Contributing

We welcome contributions! Please see our [contribution guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Run tests: `swift test`
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

## 📄 License

AppPilot is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built with Swift 6 and the native Swift Testing framework
- Inspired by the need for truly background macOS automation
- Thanks to the macOS accessibility and automation community

---

<div align="center">

**Made with ❤️ for the macOS automation community**

[Documentation](docs/) • [Examples](Examples/) • [Issues](issues/) • [Discussions](discussions/)

</div>