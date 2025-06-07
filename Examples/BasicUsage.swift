import Foundation
import AppPilot

// MARK: - AppPilot v3.0 Basic Usage Example

@main
struct BasicUsageExample {
    static func main() async {
        print("🚀 AppPilot v3.0 - UI Element-Based Automation Example")
        
        do {
            // Initialize AppPilot
            let pilot = AppPilot()
            
            // 1. List all running applications
            print("\n📱 Listing applications...")
            let apps = try await pilot.listApplications()
            print("Found \(apps.count) applications:")
            for app in apps.prefix(5) {
                print("  - \(app.name) (ID: \(app.id))")
            }
            
            // 2. Find a target application (e.g., Finder)
            guard let finderApp = apps.first(where: { $0.name.contains("Finder") || $0.name.contains("System") }) else {
                print("❌ Could not find Finder or System app")
                return
            }
            
            print("\n🎯 Target app: \(finderApp.name)")
            
            // 3. List windows for the target application
            print("\n🪟 Listing windows for \(finderApp.name)...")
            let windows = try await pilot.listWindows(app: finderApp.id)
            print("Found \(windows.count) windows:")
            for window in windows {
                print("  - \(window.title ?? "Untitled") (\(window.bounds))")
            }
            
            // 4. Discover UI elements in the first window
            if let firstWindow = windows.first {
                print("\n🔍 Discovering UI elements...")
                let elements = try await pilot.findElements(in: firstWindow.id)
                print("Found \(elements.count) UI elements:")
                for element in elements.prefix(10) {
                    print("  - \(element.role): \(element.title ?? element.identifier ?? "No title") at \(element.bounds)")
                }
                
                // 5. Find specific buttons
                print("\n🔘 Looking for buttons...")
                let buttons = try await pilot.findElements(in: firstWindow.id, role: .button)
                print("Found \(buttons.count) buttons:")
                for button in buttons.prefix(5) {
                    print("  - Button: \(button.title ?? "Untitled") at \(button.centerPoint)")
                }
                
                // 6. Element-based click (if we found any buttons)
                if let firstButton = buttons.first {
                    print("\n🖱️ Element-based click example...")
                    print("⚠️ This would click button: \(firstButton.title ?? "Untitled")")
                    // Uncomment to actually click:
                    // let result = try await pilot.clickElement(firstButton, in: firstWindow.id)
                    // print("Click result: \(result)")
                }
                
                // 7. Smart element discovery
                print("\n🎯 Smart element discovery...")
                if let closeButton = try? await pilot.findButton(in: firstWindow.id, title: "Close") {
                    print("Found Close button at: \(closeButton.centerPoint)")
                }
            }
            
            // 8. Type text example
            print("\n⌨️ Text input example...")
            print("⚠️ This would type 'Hello AppPilot v3.0!'")
            // Uncomment to actually type:
            // let typeResult = try await pilot.type(text: "Hello AppPilot v3.0!")
            // print("Type result: \(typeResult)")
            
            // 9. Wait example
            print("\n⏰ Waiting for 1 second...")
            try await pilot.wait(.time(seconds: 1.0))
            print("Wait completed!")
            
            // 10. Capture window screenshot
            if let firstWindow = windows.first {
                print("\n📷 Capturing window screenshot...")
                let image = try await pilot.capture(window: firstWindow.id)
                print("Screenshot captured: \(image.width)x\(image.height) pixels")
            }
            
            print("\n✅ AppPilot v3.0 element-based automation example completed!")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
}