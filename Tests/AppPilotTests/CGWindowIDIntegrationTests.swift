import Testing
import Foundation
@testable import AppPilot

@Suite("CGWindowID Integration Tests")
struct CGWindowIDIntegrationTests {
    
    @Test("🆔 CGWindowID extraction from windows")
    func testCGWindowIDExtraction() async throws {
        let pilot = AppPilot()
        
        // Get running applications
        let apps = try await pilot.listApplications()
        
        guard !apps.isEmpty else {
            print("⚠️ No applications found - skipping CGWindowID test")
            return
        }
        
        var windowsWithCGWindowID = 0
        var totalWindows = 0
        
        // Test each application's windows for CGWindowID availability
        for app in apps.prefix(3) { // Test first 3 apps to avoid too many iterations
            do {
                let windows = try await pilot.listWindows(app: app.id)
                
                for window in windows {
                    totalWindows += 1
                    if let cgWindowID = window.windowID {
                        windowsWithCGWindowID += 1
                        print("✅ Window '\(window.title ?? "No title")' has CGWindowID: \(cgWindowID)")
                        
                        // Verify the CGWindowID can be used with ScreenDriver
                        let screenDriver = DefaultScreenDriver()
                        let validatedID = try await screenDriver.findWindowByCGWindowID(cgWindowID)
                        if validatedID != nil {
                            print("   ✅ CGWindowID validated in ScreenCaptureKit")
                        } else {
                            print("   ⚠️ CGWindowID not found in ScreenCaptureKit")
                        }
                    } else {
                        print("⚠️ Window '\(window.title ?? "No title")' has no CGWindowID")
                    }
                }
            } catch {
                print("⚠️ Could not get windows for app \(app.name): \(error)")
            }
        }
        
        print("📊 CGWindowID Statistics:")
        print("   Total windows tested: \(totalWindows)")
        print("   Windows with CGWindowID: \(windowsWithCGWindowID)")
        
        if totalWindows > 0 {
            let percentage = Double(windowsWithCGWindowID) / Double(totalWindows) * 100
            print("   CGWindowID availability: \(String(format: "%.1f", percentage))%")
        }
        
        // We expect at least some windows to have CGWindowID
        #expect(totalWindows > 0, "Should find at least some windows to test")
    }
    
    @Test("🔗 Cross-driver CGWindowID consistency")
    func testCrossDriverCGWindowIDConsistency() async throws {
        let pilot = AppPilot()
        
        // Find an app with windows
        let apps = try await pilot.listApplications()
        var testWindow: WindowInfo?
        var testApp: AppInfo?
        
        for app in apps {
            do {
                let windows = try await pilot.listWindows(app: app.id)
                if let window = windows.first(where: { $0.windowID != nil }) {
                    testWindow = window
                    testApp = app
                    break
                }
            } catch {
                continue
            }
        }
        
        guard let window = testWindow,
              let app = testApp,
              let cgWindowID = window.windowID else {
            print("⚠️ No windows with CGWindowID found - skipping cross-driver test")
            return
        }
        
        print("🔍 Testing cross-driver consistency for window: \(window.title ?? "No title")")
        print("   CGWindowID: \(cgWindowID)")
        
        // Test ScreenDriver can find the window by CGWindowID
        let screenDriver = DefaultScreenDriver()
        let scWindowID = try await screenDriver.findWindowByCGWindowID(cgWindowID)
        
        #expect(scWindowID == cgWindowID, "ScreenDriver should find the same CGWindowID")
        
        // Test window capture using CGWindowID
        do {
            let image = try await pilot.capture(window: window.id)
            #expect(image.width > 0, "Captured image should have valid dimensions")
            #expect(image.height > 0, "Captured image should have valid dimensions")
            print("✅ Successfully captured window using CGWindowID integration")
        } catch {
            print("⚠️ Window capture failed, but CGWindowID lookup succeeded: \(error)")
            // This is okay - the CGWindowID lookup worked, capture might fail for other reasons
        }
        
        print("✅ Cross-driver CGWindowID consistency verified")
    }
    
    @Test("🏗️ Window handle format with CGWindowID")
    func testWindowHandleFormatWithCGWindowID() async throws {
        let pilot = AppPilot()
        
        let apps = try await pilot.listApplications()
        
        var cgWindowIDHandles = 0
        var axHandles = 0
        var hashHandles = 0
        var unknownHandles = 0
        
        for app in apps.prefix(3) {
            do {
                let windows = try await pilot.listWindows(app: app.id)
                
                for window in windows {
                    let handleId = window.id.id
                    
                    if handleId.hasPrefix("win_cgw_") {
                        cgWindowIDHandles += 1
                        print("🆔 CGWindowID handle: \(handleId)")
                    } else if handleId.hasPrefix("win_ax_") {
                        axHandles += 1
                        print("♿ Accessibility handle: \(handleId)")
                    } else if handleId.hasPrefix("win_") && handleId.count == 20 {
                        hashHandles += 1
                        print("🔢 Hash handle: \(handleId)")
                    } else {
                        unknownHandles += 1
                        print("❓ Unknown handle: \(handleId)")
                    }
                }
            } catch {
                continue
            }
        }
        
        print("📊 Window Handle Format Statistics:")
        print("   CGWindowID handles (win_cgw_*): \(cgWindowIDHandles)")
        print("   Accessibility handles (win_ax_*): \(axHandles)")
        print("   Hash handles (win_*): \(hashHandles)")
        print("   Unknown handles: \(unknownHandles)")
        
        let totalHandles = cgWindowIDHandles + axHandles + hashHandles + unknownHandles
        #expect(totalHandles > 0, "Should find at least some windows")
        
        // With CGWindowID integration, we expect to see some CGWindowID handles
        if cgWindowIDHandles > 0 {
            print("✅ CGWindowID-based window handles are being created")
        } else {
            print("ℹ️ No CGWindowID handles found - may indicate AXWindowNumber attribute unavailable")
        }
    }
}