import Testing
import AppPilot
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@Test("🔍 CGWindowID debugging test")
func cgWindowIDDebuggingTest() async throws {
    let pilot = AppPilot()
    
    print("🔍 Debugging CGWindowID integration...")
    
    // Find Chrome application
    let chromeApp: AppHandle
    do {
        chromeApp = try await pilot.findApplication(bundleID: "com.google.Chrome")
        print("✅ Found Chrome application: \(chromeApp.id)")
    } catch {
        print("❌ Chrome not found")
        return
    }
    
    // Get windows with detailed CGWindowID information
    let windows = try await pilot.listWindows(app: chromeApp)
    print("📱 Found \(windows.count) Chrome windows")
    
    for (index, window) in windows.enumerated() {
        print("\n🪟 Window \(index + 1): \(window.id)")
        print("   Title: '\(window.title ?? "No title")'")
        print("   Size: \(Int(window.bounds.width)) x \(Int(window.bounds.height))")
        print("   CGWindowID: \(window.windowID?.description ?? "None")")
        print("   Visible: \(window.isVisible)")
        print("   Main: \(window.isMain)")
        
        // Focus on main-sized windows
        if window.bounds.width >= 500 && window.bounds.height >= 500 {
            print("   🎯 Testing large window capture...")
            
            do {
                let screenshot = try await pilot.capture(window: window.id)
                print("   ✅ Capture SUCCESS: \(screenshot.width) x \(screenshot.height)")
                
                // Save the large screenshot
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = formatter.string(from: Date())
                
                let filename = "cgwindowid_success_\(timestamp)_\(screenshot.width)x\(screenshot.height).png"
                let filepath = "/Users/1amageek/Desktop/AppPilot/\(filename)"
                
                let url = URL(fileURLWithPath: filepath)
                if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, screenshot, nil)
                    if CGImageDestinationFinalize(destination) {
                        print("   💾 Large screenshot saved: \(filepath)")
                    }
                }
                
                // We got a successful large capture, break
                break
                
            } catch {
                print("   ❌ Capture FAILED: \(error)")
                print("   🔍 Detailed error info:")
                print("      Error type: \(type(of: error))")
                print("      Error description: \(error.localizedDescription)")
                
                if let pilotError = error as? PilotError {
                    switch pilotError {
                    case .windowNotFound(let handle):
                        print("      WindowHandle not found: \(handle)")
                    case .cgWindowIDMismatch(let axID, let scID):
                        print("      CGWindowID mismatch - AX: \(axID), SC: \(scID)")
                    case .cgWindowIDUnavailable(let handle):
                        print("      CGWindowID unavailable for handle: \(handle)")
                    default:
                        print("      Other PilotError: \(pilotError)")
                    }
                }
            }
        }
    }
    
    print("\n🎯 CGWindowID debugging completed")
}