import Foundation
import AppPilot

// MARK: - AppPilot v2.0 Basic Usage Example

@main
struct BasicUsageExample {
    static func main() async {
        print("🚀 AppPilot v2.0 - Basic Usage Example")
        
        do {
            // Initialize AppPilot with default drivers
            let pilot = AppPilot()
            
            // 1. List all running applications
            print("\n📱 Listing applications...")
            let apps = try await pilot.listApplications()
            print("Found \(apps.count) applications:")
            for app in apps.prefix(5) {
                print("  - \(app.name) (PID: \(app.id.pid))")
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
            
            // 4. Get window bounds for coordinate conversion
            if let firstWindow = windows.first {
                print("\n📐 Getting window bounds...")
                let bounds = try await pilot.getWindowBounds(window: firstWindow.id)
                print("Window bounds: \(bounds)")
                
                // 5. Convert window-relative coordinates to screen coordinates
                let windowRelativePoint = Point(x: 50.0, y: 50.0)
                let screenPoint = try await pilot.windowToScreen(point: windowRelativePoint, window: firstWindow.id)
                print("Window point \(windowRelativePoint) → Screen point \(screenPoint)")
                
                // 6. Simulate a click (this would actually move the cursor!)
                print("\n🖱️ Simulating click at screen coordinates...")
                print("⚠️ This would actually click at (\(screenPoint.x), \(screenPoint.y))")
                // Uncomment the next line to actually perform the click:
                // let result = try await pilot.click(at: screenPoint)
                // print("Click result: \(result)")
            }
            
            // 7. Simulate typing (this would actually type!)
            print("\n⌨️ Simulating typing...")
            print("⚠️ This would actually type 'Hello AppPilot v2.0!'")
            // Uncomment the next line to actually type:
            // let typeResult = try await pilot.type(text: "Hello AppPilot v2.0!")
            // print("Type result: \(typeResult)")
            
            // 8. Wait example
            print("\n⏰ Waiting for 1 second...")
            try await pilot.wait(.time(seconds: 1.0))
            print("Wait completed!")
            
            // 9. Capture window screenshot
            if let firstWindow = windows.first {
                print("\n📷 Capturing window screenshot...")
                let image = try await pilot.capture(window: firstWindow.id)
                print("Screenshot captured: \(image.width)x\(image.height) pixels")
            }
            
            print("\n✅ AppPilot v2.0 basic usage example completed!")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
}