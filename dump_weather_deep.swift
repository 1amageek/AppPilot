#!/usr/bin/env swift

import Foundation
import ApplicationServices
import AppKit

// Find Weather app
let runningApps = NSWorkspace.shared.runningApplications
guard let weatherApp = runningApps.first(where: { 
    $0.bundleIdentifier == "com.apple.weather" 
}) else {
    print("Weather app not found. Please launch it first.")
    exit(1)
}

// Activate Weather app
weatherApp.activate(options: .activateIgnoringOtherApps)
Thread.sleep(forTimeInterval: 1.0)

// Get Weather app's AXUIElement
let weatherAXApp = AXUIElementCreateApplication(weatherApp.processIdentifier)

// Function to get specific attributes
func getElementInfo(_ element: AXUIElement) -> String {
    var info = ""
    
    // Get common attributes
    let attributes = [
        ("Role", kAXRoleAttribute),
        ("RoleDescription", kAXRoleDescriptionAttribute),
        ("Title", kAXTitleAttribute),
        ("Value", kAXValueAttribute),
        ("Description", kAXDescriptionAttribute),
        ("Identifier", kAXIdentifierAttribute),
        ("Help", kAXHelpAttribute),
        ("PlaceholderValue", kAXPlaceholderValueAttribute),
        ("Selected", kAXSelectedAttribute),
        ("Enabled", kAXEnabledAttribute),
        ("Focused", kAXFocusedAttribute),
        ("Position", kAXPositionAttribute),
        ("Size", kAXSizeAttribute)
    ]
    
    for (name, attr) in attributes {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        
        if result == .success, let value = value {
            // Format different value types
            if CFGetTypeID(value) == AXValueGetTypeID() {
                let axValue = value as! AXValue
                let valueType = AXValueGetType(axValue)
                
                switch valueType {
                case .cgPoint:
                    var point = CGPoint.zero
                    AXValueGetValue(axValue, .cgPoint, &point)
                    info += "  \(name): (\(Int(point.x)), \(Int(point.y)))\n"
                case .cgSize:
                    var size = CGSize.zero
                    AXValueGetValue(axValue, .cgSize, &size)
                    info += "  \(name): \(Int(size.width))x\(Int(size.height))\n"
                case .cgRect:
                    var rect = CGRect.zero
                    AXValueGetValue(axValue, .cgRect, &rect)
                    info += "  \(name): x:\(Int(rect.origin.x)) y:\(Int(rect.origin.y)) w:\(Int(rect.width)) h:\(Int(rect.height))\n"
                default:
                    break
                }
            } else if let stringValue = value as? String {
                if !stringValue.isEmpty {
                    info += "  \(name): \"\(stringValue)\"\n"
                }
            } else if let numberValue = value as? NSNumber {
                info += "  \(name): \(numberValue)\n"
            }
        }
    }
    
    return info
}

// Recursive function to dump elements
func dumpElement(_ element: AXUIElement, indent: String = "", depth: Int = 0, maxDepth: Int = 20) {
    if depth > maxDepth { return }
    
    // Get element info
    let info = getElementInfo(element)
    if !info.isEmpty {
        print("\(indent)Element:")
        print(info.split(separator: "\n").map { indent + String($0) }.joined(separator: "\n"))
    }
    
    // Get children
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
    
    if let children = childrenValue as? [AXUIElement], !children.isEmpty {
        for (index, child) in children.enumerated() {
            print("\(indent)Child[\(index)]:")
            dumpElement(child, indent: indent + "  ", depth: depth + 1, maxDepth: maxDepth)
        }
    }
}

// Get windows
var windowsValue: CFTypeRef?
AXUIElementCopyAttributeValue(weatherAXApp, kAXWindowsAttribute as CFString, &windowsValue)

print("=== Weather App Deep Dump ===\n")

if let windows = windowsValue as? [AXUIElement], !windows.isEmpty {
    // Just dump the first window deeply
    if let firstWindow = windows.first {
        print("Window[0]:")
        dumpElement(firstWindow, indent: "  ", maxDepth: 15)
    }
} else {
    print("No windows found")
}

// Also find specific interesting elements
print("\n\n=== Specific Elements ===\n")

// Function to find elements by role
func findElementsByRole(in element: AXUIElement, role: String, depth: Int = 0, maxDepth: Int = 10) -> [(element: AXUIElement, info: String)] {
    if depth > maxDepth { return [] }
    
    var results: [(element: AXUIElement, info: String)] = []
    
    // Check current element
    var currentRoleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &currentRoleValue)
    if let currentRole = currentRoleValue as? String, currentRole == role {
        results.append((element, getElementInfo(element)))
    }
    
    // Check children
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
    if let children = childrenValue as? [AXUIElement] {
        for child in children {
            results += findElementsByRole(in: child, role: role, depth: depth + 1, maxDepth: maxDepth)
        }
    }
    
    return results
}

if let windows = windowsValue as? [AXUIElement], let firstWindow = windows.first {
    // Find all static text elements
    print("Static Text Elements:")
    let staticTexts = findElementsByRole(in: firstWindow, role: "AXStaticText")
    for (index, (_, info)) in staticTexts.prefix(10).enumerated() {
        print("\nStaticText[\(index)]:")
        print(info)
    }
    
    // Find all generic elements (these often contain weather data)
    print("\n\nGeneric Elements:")
    let genericElements = findElementsByRole(in: firstWindow, role: "AXGenericElement")
    for (index, (_, info)) in genericElements.prefix(10).enumerated() {
        print("\nGenericElement[\(index)]:")
        print(info)
    }
}