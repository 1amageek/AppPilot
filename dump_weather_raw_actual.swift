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

// Get windows - this returns a CFTypeRef
var windowsValue: CFTypeRef?
let result = AXUIElementCopyAttributeValue(weatherAXApp, kAXWindowsAttribute as CFString, &windowsValue)

print("=== Raw AXUIElementCopyAttributeValue Results ===")
print("")
print("Result code: \(result.rawValue)")
print("Windows value type: \(type(of: windowsValue))")
print("Windows value: \(String(describing: windowsValue))")
print("")

if let windows = windowsValue as? [AXUIElement] {
    print("Windows array count: \(windows.count)")
    print("")
    
    if let firstWindow = windows.first {
        print("First window type: \(type(of: firstWindow))")
        print("First window: \(firstWindow)")
        print("")
        
        // Get a single attribute
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(firstWindow, kAXRoleAttribute as CFString, &roleValue)
        print("Role result code: \(roleResult.rawValue)")
        print("Role value type: \(type(of: roleValue))")
        print("Role value: \(String(describing: roleValue))")
        print("")
        
        // Get children
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(firstWindow, kAXChildrenAttribute as CFString, &childrenValue)
        print("Children result code: \(childrenResult.rawValue)")
        print("Children value type: \(type(of: childrenValue))")
        print("Children value: \(String(describing: childrenValue))")
        print("")
        
        if let children = childrenValue as? [AXUIElement] {
            print("Children array count: \(children.count)")
            if let firstChild = children.first {
                print("First child: \(firstChild)")
                
                // Get description of first child
                var descValue: CFTypeRef?
                let descResult = AXUIElementCopyAttributeValue(firstChild, kAXDescriptionAttribute as CFString, &descValue)
                print("Description result: \(descResult.rawValue)")
                print("Description value: \(String(describing: descValue))")
            }
        }
        
        print("\n=== Getting all attribute names ===")
        var attributeNames: CFArray?
        let namesResult = AXUIElementCopyAttributeNames(firstWindow, &attributeNames)
        print("Attribute names result: \(namesResult.rawValue)")
        print("Attribute names type: \(type(of: attributeNames))")
        if let names = attributeNames as? [String] {
            print("Available attributes: \(names)")
        }
        
        print("\n=== Raw position value ===")
        var positionValue: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(firstWindow, kAXPositionAttribute as CFString, &positionValue)
        print("Position result: \(posResult.rawValue)")
        print("Position value type: \(type(of: positionValue))")
        print("Position value (raw): \(String(describing: positionValue))")
        
        if let axValue = positionValue {
            print("Is AXValue: \(CFGetTypeID(axValue) == AXValueGetTypeID())")
            if CFGetTypeID(axValue) == AXValueGetTypeID() {
                let valueType = AXValueGetType(axValue as! AXValue)
                print("AXValue type: \(valueType.rawValue)")
                
                var point = CGPoint.zero
                let success = AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
                print("Extract success: \(success)")
                print("Extracted point: \(point)")
            }
        }
    }
}

print("\n=== Direct CFCopyDescription output ===")
if let windows = windowsValue as? [AXUIElement], let firstWindow = windows.first {
    let cfDesc = CFCopyDescription(firstWindow)
    print("Window CFDescription: \(cfDesc)")
    
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(firstWindow, kAXChildrenAttribute as CFString, &childrenValue)
    if let children = childrenValue as? [AXUIElement], let firstChild = children.first {
        let childDesc = CFCopyDescription(firstChild)
        print("First child CFDescription: \(childDesc)")
    }
}