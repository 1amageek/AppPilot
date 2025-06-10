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

// Function to get all attributes of an element
func getAllAttributes(_ element: AXUIElement) -> [String: Any] {
    var attributes: [String: Any] = [:]
    
    // Get list of all attributes
    var attributeNames: CFArray?
    let result = AXUIElementCopyAttributeNames(element, &attributeNames)
    
    guard result == .success, let names = attributeNames as? [String] else {
        return attributes
    }
    
    // Get value for each attribute
    for name in names {
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        
        if valueResult == .success, let value = value {
            // Convert AXValue types to readable format
            if CFGetTypeID(value) == AXValueGetTypeID() {
                let axValue = value as! AXValue
                let valueType = AXValueGetType(axValue)
                
                switch valueType {
                case .cgPoint:
                    var point = CGPoint.zero
                    AXValueGetValue(axValue, .cgPoint, &point)
                    attributes[name] = "CGPoint(x: \(point.x), y: \(point.y))"
                case .cgSize:
                    var size = CGSize.zero
                    AXValueGetValue(axValue, .cgSize, &size)
                    attributes[name] = "CGSize(width: \(size.width), height: \(size.height))"
                case .cgRect:
                    var rect = CGRect.zero
                    AXValueGetValue(axValue, .cgRect, &rect)
                    attributes[name] = "CGRect(x: \(rect.origin.x), y: \(rect.origin.y), width: \(rect.width), height: \(rect.height))"
                case .cfRange:
                    var range = CFRange(location: 0, length: 0)
                    AXValueGetValue(axValue, .cfRange, &range)
                    attributes[name] = "CFRange(location: \(range.location), length: \(range.length))"
                default:
                    attributes[name] = "<AXValue type: \(valueType.rawValue)>"
                }
            } else if let stringValue = value as? String {
                attributes[name] = stringValue
            } else if let numberValue = value as? NSNumber {
                attributes[name] = numberValue
            } else if let arrayValue = value as? [Any] {
                attributes[name] = "<Array with \(arrayValue.count) items>"
            } else {
                attributes[name] = "<\(type(of: value))>"
            }
        }
    }
    
    return attributes
}

// Function to recursively dump elements with raw data
func dumpElementRaw(_ element: AXUIElement, indent: String = "", depth: Int = 0, maxDepth: Int = 5) {
    if depth > maxDepth { return }
    
    // Get all attributes
    let attributes = getAllAttributes(element)
    
    // Print element with all attributes
    print("\(indent)Element:")
    for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
        if key != "AXChildren" {  // Skip children for now
            print("\(indent)  \(key): \(value)")
        }
    }
    
    // Get children
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
    
    if let children = childrenValue as? [AXUIElement] {
        print("\(indent)  AXChildren: \(children.count) items")
        for (index, child) in children.enumerated() {
            print("\(indent)  Child [\(index)]:")
            dumpElementRaw(child, indent: indent + "    ", depth: depth + 1, maxDepth: maxDepth)
        }
    }
    
    print("")  // Empty line for readability
}

// Get windows
var windowsValue: CFTypeRef?
AXUIElementCopyAttributeValue(weatherAXApp, kAXWindowsAttribute as CFString, &windowsValue)

print("=== Weather App Raw Dump ===")
print("")
print("Application attributes:")
let appAttributes = getAllAttributes(weatherAXApp)
for (key, value) in appAttributes.sorted(by: { $0.key < $1.key }) {
    if key != "AXWindows" && key != "AXChildren" {
        print("  \(key): \(value)")
    }
}
print("")

if let windows = windowsValue as? [AXUIElement], !windows.isEmpty {
    print("Windows: \(windows.count)")
    for (index, window) in windows.enumerated() {
        print("\nWindow [\(index)]:")
        dumpElementRaw(window, indent: "  ", maxDepth: 3)  // Limit depth to avoid too much output
    }
} else {
    print("No windows found")
}

print("\n=== Specific Element Examples ===")

// Show a few specific elements in detail
if let windows = windowsValue as? [AXUIElement], let firstWindow = windows.first {
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(firstWindow, kAXChildrenAttribute as CFString, &childrenValue)
    
    if let children = childrenValue as? [AXUIElement], !children.isEmpty {
        print("\nFirst child of window (detailed):")
        if let firstChild = children.first {
            let attrs = getAllAttributes(firstChild)
            for (key, value) in attrs.sorted(by: { $0.key < $1.key }) {
                print("  \(key): \(value)")
            }
        }
    }
}