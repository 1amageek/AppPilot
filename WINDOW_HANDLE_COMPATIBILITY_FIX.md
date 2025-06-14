# Window Handle Compatibility Fix

## Problem Description

The AppPilot codebase had an incompatibility issue between different window handle formats:
- **Accessibility-based handles**: `win_ax_[identifier]` (e.g., `win_ax_SceneWindow`)
- **Hash-based handles**: `win_[16-hex-chars]` (e.g., `win_9A5EACFE5572C654`)

This incompatibility caused window lookup failures when the system generated one format but later tried to lookup using a different format.

## Root Cause Analysis

The issue was in the window handle caching and lookup mechanism in `AccessibilityDriver.swift`:

1. **Inconsistent Handle Generation**: The same window could get different handle formats at different times
2. **Direct Dictionary Lookup**: `windowHandles[windowHandle.id]` failed when handle formats didn't match exactly
3. **No Format Normalization**: The system didn't account for different formats representing the same logical window
4. **Cache Invalidation**: Stale handles in the cache could become incompatible with newly generated handles

## Solution Implemented

### 1. Handle Format Detection and Normalization

Added comprehensive window handle format detection:

```swift
private enum WindowHandleFormat {
    case accessibility(identifier: String)  // win_ax_identifier
    case hashBased(hash: String)            // win_[16-hex-chars]
    case unknown(original: String)
}

private func detectHandleFormat(_ handleId: String) -> WindowHandleFormat {
    if handleId.hasPrefix("win_ax_") {
        let identifier = String(handleId.dropFirst(7))
        return .accessibility(identifier: identifier)
    } else if handleId.hasPrefix("win_") && handleId.count == 20 {
        let hash = String(handleId.dropFirst(4))
        if hash.allSatisfy({ $0.isHexDigit }) {
            return .hashBased(hash: hash)
        }
    }
    return .unknown(original: handleId)
}
```

### 2. Improved Window Handle Lookup

Replaced direct dictionary lookup with intelligent resolution:

```swift
private func findCanonicalWindowHandle(_ handleId: String) -> WindowHandleData? {
    // Try direct lookup first
    if let data = windowHandles[handleId] {
        return data
    }
    
    // Try mapped handle lookup
    if let mappedId = handleMapping[handleId], let data = windowHandles[mappedId] {
        return data
    }
    
    // Try reverse mapping lookup
    for (canonical, mapped) in handleMapping {
        if mapped == handleId, let data = windowHandles[canonical] {
            return data
        }
    }
    
    // Try finding by window properties (fallback for format inconsistencies)
    let format = detectHandleFormat(handleId)
    
    switch format {
    case .accessibility(let identifier):
        return findWindowByAccessibilityIdentifier(identifier)
    case .hashBased(let hash):
        return findWindowByHashMatch(hash)
    case .unknown:
        return nil
    }
}
```

### 3. Handle Mapping System

Added bidirectional mapping between different handle formats for the same window:

```swift
// Handle mapping for different formats of the same logical window
private var handleMapping: [String: String] = [:]

private func addHandleMapping(canonical: String, alternative: String) {
    handleMapping[alternative] = canonical
    handleMapping[canonical] = alternative
}
```

### 4. Alternative Handle Format Creation

Enhanced window handle generation to create and store alternative formats:

```swift
private func createAlternativeHandleFormats(for axWindow: AXUIElement, appHandle: AppHandle, canonicalId: String, windowData: WindowHandleData) throws {
    let format = detectHandleFormat(canonicalId)
    
    switch format {
    case .accessibility(_):
        // For accessibility handles, also create a hash-based alternative
        do {
            let hashId = try createHashBasedWindowID(for: axWindow, appHandle: appHandle)
            if hashId != canonicalId {
                addHandleMapping(canonical: canonicalId, alternative: hashId)
                logger.debug("Created handle mapping: \(canonicalId) ↔ \(hashId)")
            }
        } catch {
            // Hash creation failed, continue without alternative
        }
        
    case .hashBased:
        // For hash-based handles, try to create accessibility alternative if available
        if let axIdentifier = getStringAttribute(from: axWindow, attribute: kAXIdentifierAttribute),
           !axIdentifier.isEmpty {
            let axId = "win_ax_\(axIdentifier)"
            if axId != canonicalId {
                addHandleMapping(canonical: canonicalId, alternative: axId)
                logger.debug("Created handle mapping: \(canonicalId) ↔ \(axId)")
            }
        }
        
    case .unknown:
        // Cannot create alternatives for unknown formats
        break
    }
}
```

### 5. Enhanced Error Handling and Debugging

Added comprehensive logging for window handle resolution failures:

```swift
guard let windowData = findCanonicalWindowHandle(windowHandle.id) else {
    logger.warning("Window handle not found: \(windowHandle.id)")
    let format = detectHandleFormat(windowHandle.id)
    logger.warning("Requested handle format: \(String(describing: format))")
    logWindowHandleState()
    throw PilotError.windowNotFound(windowHandle)
}
```

### 6. Hex Digit Detection Utility

Added proper hex digit validation:

```swift
extension Character {
    var isHexDigit: Bool {
        return isNumber || (isLetter && self.uppercased().first! >= "A" && self.uppercased().first! <= "F")
    }
}
```

## Key Benefits

1. **Backward Compatibility**: Existing code using either handle format continues to work
2. **Forward Compatibility**: New handle formats can be easily added to the detection system
3. **Automatic Mapping**: The system automatically creates mappings between formats when possible
4. **Robust Fallbacks**: Multiple lookup strategies ensure window resolution succeeds even with format mismatches
5. **Better Debugging**: Comprehensive logging helps diagnose handle resolution issues

## Files Modified

1. **`Sources/AppPilot/Driver/AccessibilityDriver.swift`**:
   - Added handle format detection and normalization
   - Implemented improved window handle lookup
   - Added handle mapping system
   - Enhanced error handling and debugging

2. **`Tests/AppPilotTests/WindowResolutionTests.swift`**:
   - Added comprehensive window handle compatibility test

3. **`Tests/AppPilotTests/WindowHandleCompatibilityUnitTests.swift`** (new):
   - Unit tests for handle format detection logic
   - Tests for hex digit validation
   - Tests for stable hash creation
   - Tests for WindowHandle type functionality

## Test Results

All tests pass successfully:

- ✅ Window Handle Compatibility Unit Tests (4/4 tests)
- ✅ Window Resolution Bug Investigation Tests (5/5 tests)
- ✅ General window ownership verification
- ✅ Bundle ID window resolution accuracy
- ✅ Chrome window resolution bug investigation
- ✅ Window handle format compatibility verification

## Usage

The fix is transparent to existing code. Applications using AppPilot can continue using either handle format:

```swift
// Both of these work seamlessly now:
let accessibilityWindow = WindowHandle(id: "win_ax_SceneWindow")
let hashWindow = WindowHandle(id: "win_9A5EACFE5572C654")

// Window operations work with either format:
let elements1 = try await pilot.findElements(in: accessibilityWindow, role: .button)
let elements2 = try await pilot.findElements(in: hashWindow, role: .button)
```

## Conclusion

This fix resolves the window handle format incompatibility issue while maintaining full backward compatibility and providing a robust foundation for future handle format variations.