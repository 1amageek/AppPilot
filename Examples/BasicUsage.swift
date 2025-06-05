import Foundation
import AppPilot

// Example: Basic AppPilot Usage
@main
struct BasicUsageExample {
    static func main() async throws {
        let pilot = AppPilot()
        
        print("AppPilot SDK Example")
        print("===================")
        
        do {
            // List all running applications
            print("\n1. Listing applications...")
            let apps = try await pilot.listApplications()
            print("Found \(apps.count) applications")
            
            for app in apps.prefix(3) {
                print("  - \(app.name) (PID: \(app.id.pid))")
                
                // List windows for this app
                let windows = try await pilot.listWindows(in: app.id)
                print("    Windows: \(windows.count)")
                
                for window in windows.prefix(2) {
                    print("      * \(window.title ?? "Untitled") - Minimized: \(window.isMinimized)")
                }
            }
            
            // Example: Click operation (would require actual window)
            /*
            if let firstApp = apps.first,
               let windows = try? await pilot.listWindows(in: firstApp.id),
               let firstWindow = windows.first {
                
                print("\n2. Performing click operation...")
                let result = try await pilot.click(
                    window: firstWindow.id,
                    at: Point(x: 100, y: 100),
                    policy: .STAY_HIDDEN  // Click without bringing window to front
                )
                
                print("Click result: \(result.success) via \(result.route)")
            }
            */
            
            // Example: Type text (would require actual window)
            /*
            print("\n3. Typing text...")
            let typeResult = try await pilot.type(
                text: "Hello from AppPilot!",
                into: windowID,
                policy: .STAY_HIDDEN
            )
            
            print("Type result: \(typeResult.success) via \(typeResult.route)")
            */
            
            // Example: Subscribe to UI changes
            /*
            print("\n4. Monitoring UI changes...")
            let stream = await pilot.subscribeAX(window: windowID, mask: .all)
            
            for await event in stream {
                print("UI Event: \(event.type) at \(event.timestamp)")
                break // Just show one event for demo
            }
            */
            
            print("\nExample completed successfully!")
            
        } catch {
            print("Error: \(error)")
        }
    }
}