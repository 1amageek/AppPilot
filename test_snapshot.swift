#!/usr/bin/env swift

import Foundation
import AppPilot
import AppKit

// Simple test script to demonstrate UISnapshot functionality

@main
struct TestSnapshot {
    static func main() async throws {
        let pilot = AppPilot()
        
        print("Testing UISnapshot functionality...")
        print("=================================")
        
        // Find TestApp
        do {
            let app = try await pilot.findApplication(name: "TestApp")
            print("✓ Found TestApp")
            
            // Get windows
            let windows = try await pilot.listWindows(app: app)
            guard let window = windows.first else {
                print("✗ No windows found in TestApp")
                return
            }
            
            print("✓ Found window: \(window.title ?? "Untitled")")
            
            // Create snapshot with metadata
            let snapshot = try await pilot.snapshot(
                window: window.id,
                metadata: SnapshotMetadata(
                    description: "TestApp UI snapshot demo",
                    tags: ["test", "demo", "snapshot"],
                    customData: ["timestamp": ISO8601DateFormatter().string(from: Date())]
                )
            )
            
            print("\n📸 Snapshot captured successfully!")
            print("   Window: \(snapshot.windowInfo.title ?? "Untitled")")
            print("   Size: \(snapshot.windowInfo.bounds.size)")
            print("   Elements found: \(snapshot.elements.count)")
            print("   Timestamp: \(snapshot.timestamp)")
            
            // Analyze UI elements
            print("\n🔍 UI Element Analysis:")
            print("   Buttons: \(snapshot.clickableElements.count)")
            print("   Text fields: \(snapshot.textInputElements.count)")
            print("   All elements: \(snapshot.elements.count)")
            
            // List clickable elements
            if !snapshot.clickableElements.isEmpty {
                print("\n📱 Clickable Elements:")
                for element in snapshot.clickableElements.prefix(5) {
                    let title = element.title ?? element.identifier ?? "Untitled"
                    print("   - \(element.role.displayName): \"\(title)\" at \(element.bounds)")
                }
                if snapshot.clickableElements.count > 5 {
                    print("   ... and \(snapshot.clickableElements.count - 5) more")
                }
            }
            
            // Save screenshot to file if possible
            if let image = snapshot.image {
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let fileURL = desktopURL.appendingPathComponent("testapp_snapshot_\(Int(Date().timeIntervalSince1970)).png")
                
                if let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil)
                    if CGImageDestinationFinalize(destination) {
                        print("\n💾 Screenshot saved to: \(fileURL.path)")
                    }
                }
            }
            
            // Demonstrate finding specific elements in snapshot
            if let mouseClickButton = snapshot.findElement(role: .button, title: "Mouse Click") {
                print("\n✨ Found 'Mouse Click' button at: \(mouseClickButton.bounds)")
            }
            
            // Show metadata
            if let metadata = snapshot.metadata {
                print("\n📋 Metadata:")
                print("   Description: \(metadata.description ?? "None")")
                print("   Tags: \(metadata.tags.joined(separator: ", "))")
                if !metadata.customData.isEmpty {
                    print("   Custom data:")
                    for (key, value) in metadata.customData {
                        print("     - \(key): \(value)")
                    }
                }
            }
            
        } catch {
            print("✗ Error: \(error.localizedDescription)")
        }
    }
}