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

// Get windows
var windowsValue: CFTypeRef?
AXUIElementCopyAttributeValue(weatherAXApp, kAXWindowsAttribute as CFString, &windowsValue)

guard let windows = windowsValue as? [AXUIElement], !windows.isEmpty else {
    print("No windows found for Weather app")
    exit(1)
}

// Function to recursively dump UI elements
func dumpElement(_ element: AXUIElement, indent: String = "") {
    // Get role
    var roleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
    let role = roleValue as? String ?? "Unknown"
    
    // Get title
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
    let title = titleValue as? String
    
    // Get value
    var valueValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueValue)
    let value = valueValue as? String
    
    // Get description
    var descValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue)
    let description = descValue as? String
    
    // Get identifier
    var identifierValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifierValue)
    let identifier = identifierValue as? String
    
    // Get position and size
    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
    
    var positionStr = ""
    var sizeStr = ""
    if let positionValue = positionValue {
        var position = CGPoint.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        positionStr = "(\(Int(position.x)), \(Int(position.y)))"
    }
    if let sizeValue = sizeValue {
        var size = CGSize.zero
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        sizeStr = "\(Int(size.width))x\(Int(size.height))"
    }
    
    // Build output
    var output = "\(indent)[\(role)]"
    if let title = title, !title.isEmpty {
        output += " title=\"\(title)\""
    }
    if let value = value, !value.isEmpty {
        output += " value=\"\(value)\""
    }
    if let description = description, !description.isEmpty {
        output += " desc=\"\(description)\""
    }
    if let identifier = identifier, !identifier.isEmpty {
        output += " id=\"\(identifier)\""
    }
    if !positionStr.isEmpty && !sizeStr.isEmpty {
        output += " pos=\(positionStr) size=\(sizeStr)"
    }
    
    print(output)
    
    // Get children
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
    
    if let children = childrenValue as? [AXUIElement] {
        for child in children {
            dumpElement(child, indent: indent + "  ")
        }
    }
}

// Dump the first window
print("=== Weather App UI Tree Dump ===")
print("")

for (index, window) in windows.enumerated() {
    var windowTitleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitleValue)
    let windowTitle = windowTitleValue as? String ?? "Untitled"
    
    print("Window \(index): \"\(windowTitle)\"")
    print(String(repeating: "-", count: 50))
    dumpElement(window)
    print("")
}

print("\n=== Summary of Key Elements ===")

// Find specific elements
func findElements(in element: AXUIElement, role: String? = nil, depth: Int = 0, maxDepth: Int = 10) -> [AXUIElement] {
    if depth > maxDepth { return [] }
    
    var results: [AXUIElement] = []
    
    // Check current element
    if let targetRole = role {
        var currentRoleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &currentRoleValue)
        if let currentRole = currentRoleValue as? String, currentRole == targetRole {
            results.append(element)
        }
    } else {
        results.append(element)
    }
    
    // Check children
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
    if let children = childrenValue as? [AXUIElement] {
        for child in children {
            results += findElements(in: child, role: role, depth: depth + 1, maxDepth: maxDepth)
        }
    }
    
    return results
}

// Find buttons
let buttons = windows.flatMap { findElements(in: $0, role: "AXButton") }
print("\nButtons found: \(buttons.count)")
for button in buttons.prefix(5) {
    var titleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(button, kAXTitleAttribute as CFString, &titleValue)
    if let title = titleValue as? String {
        print("  - \(title)")
    }
}

// Find text fields
let textFields = windows.flatMap { findElements(in: $0, role: "AXTextField") }
print("\nText fields found: \(textFields.count)")
for field in textFields {
    var titleValue: CFTypeRef?
    var valueValue: CFTypeRef?
    AXUIElementCopyAttributeValue(field, kAXTitleAttribute as CFString, &titleValue)
    AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &valueValue)
    let title = titleValue as? String ?? "Untitled"
    let value = valueValue as? String ?? ""
    print("  - \(title): \"\(value)\"")
}

// Find static text
let staticTexts = windows.flatMap { findElements(in: $0, role: "AXStaticText") }
print("\nStatic texts found: \(staticTexts.count)")
for text in staticTexts.prefix(10) {
    var valueValue: CFTypeRef?
    AXUIElementCopyAttributeValue(text, kAXValueAttribute as CFString, &valueValue)
    if let value = valueValue as? String, !value.isEmpty {
        print("  - \"\(value)\"")
    }
}