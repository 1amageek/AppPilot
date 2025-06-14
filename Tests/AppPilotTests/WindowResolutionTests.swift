import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

@Suite("Window Resolution Bug Investigation", .serialized)
struct WindowResolutionTests {
    
    init() {
        // Set environment variable to indicate automated testing mode
        setenv("APPPILOT_TESTING", "1", 1)
    }
    
    // MARK: - Weather App Window Resolution Test
    
    @Test("🌤️ Weather app window resolution verification", .serialized)
    func testWeatherAppWindowResolution() async throws {
        print("🔍 Starting Weather App Window Resolution Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // Stage 1: Find Weather app by bundle ID
        print("\n📱 Stage 1: Finding Weather app by bundle ID")
        let weatherApp: AppHandle
        do {
            weatherApp = try await pilot.findApplication(bundleId: "com.apple.weather")
            print("✅ Found Weather app: \(weatherApp.id)")
        } catch {
            print("⚠️ Weather app not found or not running. Skipping test.")
            throw error
        }
        
        // Stage 2: Get all windows for Weather app
        print("\n🪟 Stage 2: Getting windows for Weather app")
        let weatherWindows = try await pilot.listWindows(app: weatherApp)
        
        print("📊 Weather app windows found: \(weatherWindows.count)")
        for (index, window) in weatherWindows.enumerated() {
            let title = window.title ?? "No title"
            let appName = window.appName
            print("   Window \(index + 1): '\(title)' (App: \(appName))")
            print("     ID: \(window.id.id)")
            print("     Bounds: \(window.bounds)")
            print("     Visible: \(window.isVisible), Main: \(window.isMain)")
        }
        
        // Stage 3: Verify window ownership
        print("\n🔍 Stage 3: Verifying window ownership")
        for (index, window) in weatherWindows.enumerated() {
            let appName = window.appName
            print("   Window \(index + 1): App name reported as '\(appName)'")
            
            // This is the critical test - all windows should belong to Weather app
            if !appName.localizedCaseInsensitiveContains("weather") && 
               !appName.localizedCaseInsensitiveContains("天気") {
                print("❌ PROBLEM DETECTED: Window '\(window.title ?? "No title")' reports app name as '\(appName)' but should be Weather app!")
                print("     This indicates the window resolution bug!")
                
                // Continue collecting information instead of failing immediately
            } else {
                print("✅ Window correctly belongs to Weather app")
            }
        }
        
        // Stage 4: Cross-reference with all applications
        print("\n🔗 Stage 4: Cross-referencing with all running applications")
        let allApps = try await pilot.listApplications()
        print("📋 Total running applications: \(allApps.count)")
        
        var suspiciousWindows: [(window: WindowInfo, suspectedApp: AppInfo)] = []
        
        for app in allApps {
            if app.id == weatherApp { continue } // Skip Weather app itself
            
            let appWindows = try await pilot.listWindows(app: app.id)
            for appWindow in appWindows {
                // Check if any Weather app windows match windows from other apps
                for weatherWindow in weatherWindows {
                    if weatherWindow.title == appWindow.title && 
                       weatherWindow.bounds == appWindow.bounds {
                        print("🚨 DUPLICATE WINDOW DETECTED!")
                        print("   Window '\(weatherWindow.title ?? "No title")' appears in both:")
                        print("     - Weather app (com.apple.weather)")
                        print("     - \(app.name) (\(app.bundleIdentifier ?? "No bundle ID"))")
                        
                        suspiciousWindows.append((window: weatherWindow, suspectedApp: app))
                    }
                }
            }
        }
        
        // Stage 5: Report findings
        print("\n📋 Stage 5: Test Results Summary")
        if suspiciousWindows.isEmpty {
            print("✅ No duplicate windows found - window resolution appears correct")
        } else {
            print("❌ Found \(suspiciousWindows.count) suspicious window(s):")
            for (window, app) in suspiciousWindows {
                print("   - '\(window.title ?? "No title")' may actually belong to \(app.name)")
            }
            print("\n🔧 This confirms the reported window resolution bug!")
        }
        
        // Don't fail the test immediately - we want to collect information
        // Instead, document the problem for investigation
        if !suspiciousWindows.isEmpty {
            print("\n📝 Bug confirmed: Weather app window resolution returns windows from other applications")
        }
    }
    
    // MARK: - General Window Ownership Verification
    
    @Test("🔍 General window ownership verification", .serialized)
    func testWindowOwnershipConsistency() async throws {
        print("🔍 Starting General Window Ownership Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // Get all running applications
        let allApps = try await pilot.listApplications()
        print("📋 Testing \(allApps.count) running applications")
        
        var inconsistencies: [(app: AppInfo, window: WindowInfo, issue: String)] = []
        
        for app in allApps {
            print("\n🔍 Testing app: \(app.name) (\(app.bundleIdentifier ?? "No bundle ID"))")
            
            do {
                let windows = try await pilot.listWindows(app: app.id)
                print("   Found \(windows.count) window(s)")
                
                for (index, window) in windows.enumerated() {
                    let windowAppName = window.appName
                    let title = window.title ?? "No title"
                    
                    print("     Window \(index + 1): '\(title)' (Reports app: '\(windowAppName)')")
                    
                    // Check if window's reported app name matches the requested app
                    if !windowAppName.localizedCaseInsensitiveContains(app.name) &&
                       windowAppName.lowercased() != app.name.lowercased() {
                        
                        let issue = "Window reports app '\(windowAppName)' but was retrieved from '\(app.name)'"
                        inconsistencies.append((app: app, window: window, issue: issue))
                        print("       ⚠️ INCONSISTENCY: \(issue)")
                    }
                }
            } catch {
                print("   ❌ Error getting windows: \(error)")
                // Continue with other apps
            }
        }
        
        // Report all inconsistencies
        print("\n📋 Window Ownership Inconsistency Summary")
        if inconsistencies.isEmpty {
            print("✅ All windows report consistent app ownership")
        } else {
            print("❌ Found \(inconsistencies.count) window ownership inconsistencies:")
            for (index, inconsistency) in inconsistencies.enumerated() {
                print("   \(index + 1). \(inconsistency.issue)")
                print("       Window: '\(inconsistency.window.title ?? "No title")'")
                print("       Expected app: \(inconsistency.app.name)")
                print("       Reported app: \(inconsistency.window.appName)")
            }
        }
        
        // Log statistics
        var totalWindowsTested = inconsistencies.count
        for app in allApps {
            do {
                let windows = try await pilot.listWindows(app: app.id)
                totalWindowsTested += windows.count
            } catch {
                // Continue counting
                continue
            }
        }
        
        print("\n📊 Test Statistics:")
        print("   Total applications tested: \(allApps.count)")
        print("   Total inconsistencies found: \(inconsistencies.count)")
        print("   Consistency rate: \(String(format: "%.1f%%", Double(totalWindowsTested - inconsistencies.count) / Double(totalWindowsTested) * 100))")
    }
    
    // MARK: - Specific Bundle ID Window Resolution Test
    
    @Test("🎯 Bundle ID window resolution accuracy", .serialized)
    func testBundleIdWindowResolutionAccuracy() async throws {
        print("🎯 Starting Bundle ID Window Resolution Accuracy Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // Test with specific well-known applications
        let testCases = [
            ("com.apple.weather", "Weather"),
            ("com.apple.finder", "Finder"),
            ("com.apple.Safari", "Safari"),
            ("com.apple.systempreferences", "System Preferences")
        ]
        
        var testResults: [(bundleId: String, expectedName: String, success: Bool, actualWindows: [WindowInfo])] = []
        
        for (bundleId, expectedName) in testCases {
            print("\n🔍 Testing bundle ID: \(bundleId) (Expected: \(expectedName))")
            
            do {
                // Find app by bundle ID
                let app = try await pilot.findApplication(bundleId: bundleId)
                print("   ✅ App found: \(app.id)")
                
                // Get windows for this app
                let windows = try await pilot.listWindows(app: app)
                print("   📊 Found \(windows.count) window(s)")
                
                var allWindowsMatch = true
                
                for (index, window) in windows.enumerated() {
                    let windowAppName = window.appName
                    let title = window.title ?? "No title"
                    
                    print("     Window \(index + 1): '\(title)' (App: '\(windowAppName)')")
                    
                    // Check if window belongs to expected app
                    if !windowAppName.localizedCaseInsensitiveContains(expectedName) {
                        print("       ❌ Window does not belong to expected app!")
                        print("          Expected: \(expectedName)")
                        print("          Actual: \(windowAppName)")
                        allWindowsMatch = false
                    } else {
                        print("       ✅ Window correctly belongs to \(expectedName)")
                    }
                }
                
                testResults.append((
                    bundleId: bundleId, 
                    expectedName: expectedName, 
                    success: allWindowsMatch, 
                    actualWindows: windows
                ))
                
            } catch {
                print("   ⚠️ App not found or error: \(error)")
                testResults.append((
                    bundleId: bundleId, 
                    expectedName: expectedName, 
                    success: false, 
                    actualWindows: []
                ))
            }
        }
        
        // Summary
        print("\n📋 Bundle ID Window Resolution Test Results")
        let successCount = testResults.filter { $0.success }.count
        let totalCount = testResults.count
        
        print("   Successful tests: \(successCount)/\(totalCount)")
        print("   Success rate: \(String(format: "%.1f%%", Double(successCount) / Double(totalCount) * 100))")
        
        for result in testResults {
            let status = result.success ? "✅" : "❌"
            print("   \(status) \(result.bundleId) (\(result.expectedName)): \(result.actualWindows.count) windows")
        }
        
        if successCount < totalCount {
            print("\n🚨 Window resolution issues detected in \(totalCount - successCount) application(s)")
        }
    }
    
    // MARK: - Chrome-Specific Window Resolution Test
    
    @Test("🌐 Chrome window resolution bug investigation", .serialized)
    func testChromeWindowResolutionBug() async throws {
        print("🌐 Starting Chrome Window Resolution Bug Investigation")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // Stage 1: Find Google Chrome
        print("\n🔍 Stage 1: Finding Google Chrome")
        let chromeApp: AppHandle
        do {
            chromeApp = try await pilot.findApplication(bundleId: "com.google.Chrome")
            print("✅ Found Chrome: \(chromeApp.id)")
        } catch {
            print("⚠️ Chrome not found or not running. Skipping test.")
            throw error
        }
        
        // Stage 2: Get Chrome windows with detailed debugging
        print("\n🪟 Stage 2: Getting Chrome windows with ownership verification")
        let chromeWindows = try await pilot.listWindows(app: chromeApp)
        
        print("📊 Chrome windows found: \(chromeWindows.count)")
        var ownershipIssues: [(window: WindowInfo, issue: String)] = []
        
        for (index, window) in chromeWindows.enumerated() {
            let title = window.title ?? "No title"
            let appName = window.appName
            let handle = window.id.id
            
            print("   Window \(index + 1): '\(title)'")
            print("     Handle: \(handle)")
            print("     Reported App: '\(appName)'")
            print("     Bounds: \(window.bounds)")
            print("     Visible: \(window.isVisible), Main: \(window.isMain)")
            
            // Chrome-specific verification
            if !appName.localizedCaseInsensitiveContains("chrome") && 
               !appName.localizedCaseInsensitiveContains("google") {
                let issue = "Chrome window '\(title)' reports app name as '\(appName)' instead of Chrome"
                ownershipIssues.append((window: window, issue: issue))
                print("     ❌ OWNERSHIP ISSUE: \(issue)")
            } else {
                print("     ✅ Window correctly belongs to Chrome")
            }
            
            // Check for suspicious window handles (the bug mentioned win_6DDE400DA3C9DC6E pattern)
            if handle.hasPrefix("win_") && handle.count > 10 && !handle.hasPrefix("win_ax_") {
                print("     🔍 Handle Pattern: Hash-based (potential issue indicator)")
            } else if handle.hasPrefix("win_ax_") {
                print("     ✅ Handle Pattern: Accessibility-based (stable)")
            }
        }
        
        // Stage 3: Cross-check with other browsers
        print("\n🔗 Stage 3: Cross-checking with other browser applications")
        let browserBundleIds = [
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.operasoftware.Opera"
        ]
        
        var crossContamination: [(chromeWindow: WindowInfo, otherApp: String)] = []
        
        for bundleId in browserBundleIds {
            do {
                let otherBrowser = try await pilot.findApplication(bundleId: bundleId)
                let otherWindows = try await pilot.listWindows(app: otherBrowser)
                
                print("   Checking against \(bundleId): \(otherWindows.count) windows")
                
                for otherWindow in otherWindows {
                    for chromeWindow in chromeWindows {
                        // Check for duplicate windows (same title and bounds)
                        if chromeWindow.title == otherWindow.title && 
                           chromeWindow.bounds == otherWindow.bounds {
                            crossContamination.append((chromeWindow: chromeWindow, otherApp: bundleId))
                            print("     🚨 DUPLICATE: Chrome window '\(chromeWindow.title ?? "No title")' also appears in \(bundleId)")
                        }
                    }
                }
            } catch {
                print("   ⚠️ \(bundleId) not found or error: \(error)")
            }
        }
        
        // Stage 4: Window handle consistency analysis
        print("\n📊 Stage 4: Window handle consistency analysis")
        let accessibilityHandles = chromeWindows.filter { $0.id.id.hasPrefix("win_ax_") }
        let hashHandles = chromeWindows.filter { $0.id.id.hasPrefix("win_") && !$0.id.id.hasPrefix("win_ax_") }
        
        print("   Accessibility-based handles: \(accessibilityHandles.count)")
        print("   Hash-based handles: \(hashHandles.count)")
        
        if hashHandles.count > accessibilityHandles.count {
            print("   ⚠️ Majority of Chrome windows use hash-based handles (potential instability)")
        }
        
        // Stage 5: Process ID verification (if accessible)
        print("\n🔍 Stage 5: Chrome process verification")
        let allApps = try await pilot.listApplications()
        if let chromeAppInfo = allApps.first(where: { $0.id == chromeApp }) {
            print("   Chrome app info:")
            print("     Name: \(chromeAppInfo.name)")
            print("     Bundle ID: \(chromeAppInfo.bundleIdentifier ?? "N/A")")
            print("     Active: \(chromeAppInfo.isActive)")
            
            // Verify that all Chrome windows report the correct app name
            let correctWindows = chromeWindows.filter { window in
                window.appName.localizedCaseInsensitiveContains("chrome") ||
                window.appName.localizedCaseInsensitiveContains("google")
            }
            
            let accuracy = Double(correctWindows.count) / Double(chromeWindows.count) * 100
            print("   Window ownership accuracy: \(String(format: "%.1f%%", accuracy)) (\(correctWindows.count)/\(chromeWindows.count))")
        }
        
        // Stage 6: Report findings
        print("\n📋 Stage 6: Chrome Window Resolution Test Results")
        print("=" * 60)
        
        if ownershipIssues.isEmpty && crossContamination.isEmpty {
            print("✅ Chrome window resolution appears correct")
        } else {
            print("❌ Chrome window resolution issues detected:")
            
            if !ownershipIssues.isEmpty {
                print("\n🚨 Ownership Issues (\(ownershipIssues.count)):")
                for (index, issue) in ownershipIssues.enumerated() {
                    print("   \(index + 1). \(issue.issue)")
                }
            }
            
            if !crossContamination.isEmpty {
                print("\n🚨 Cross-Contamination Issues (\(crossContamination.count)):")
                for (index, contamination) in crossContamination.enumerated() {
                    print("   \(index + 1). Chrome window '\(contamination.chromeWindow.title ?? "No title")' also found in \(contamination.otherApp)")
                }
            }
            
            print("\n🔧 This confirms the Chrome-specific window resolution bug!")
        }
        
        // Document the specific bug pattern mentioned in the original report
        let hashBasedWindows = chromeWindows.filter { $0.id.id.matches("win_[A-F0-9]{16}") }
        if !hashBasedWindows.isEmpty {
            print("\n📝 Found \(hashBasedWindows.count) window(s) with the reported pattern (win_[16-hex-chars]):")
            for window in hashBasedWindows {
                print("   - \(window.id.id): '\(window.title ?? "No title")' (App: \(window.appName))")
            }
        }
    }
}

// MARK: - Helper Extensions

extension String {
    /// Check if string matches a regular expression pattern
    func matches(_ pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(self.startIndex..., in: self)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

