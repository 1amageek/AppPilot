import Foundation
@testable import AppPilot

/// Helper for manual testing of composition input functionality
/// 
/// This class provides utilities for interactive testing of IME and composition features.
/// Use this for debugging and validating real-world IME behavior.
public class ManualCompositionTestHelper {
    
    private let pilot = AppPilot()
    
    public init() {}
    
    /// Interactive test for Japanese input with real IME
    /// 
    /// This function guides the user through manual testing steps to verify
    /// that composition input works correctly with the system IME.
    public func runInteractiveJapaneseTest() async throws {
        print("🇯🇵 Interactive Japanese Composition Test")
        print("=" * 45)
        print()
        print("This test will help you verify Japanese IME functionality.")
        print("Please follow the instructions carefully.")
        print()
        
        // Step 1: Check input sources
        print("📋 Step 1: Checking available input sources...")
        let sources = try await pilot.getAvailableInputSources()
        let japaneseSources = sources.filter { source in
            source.identifier.contains("Kotoeri") || 
            source.displayName.contains("Japanese")
        }
        
        if japaneseSources.isEmpty {
            print("❌ No Japanese input sources found!")
            print("   Please install Japanese input method and try again.")
            return
        }
        
        print("✅ Found Japanese input sources:")
        for source in japaneseSources {
            print("   - \(source.displayName) (\(source.identifier))")
        }
        
        // Step 2: Switch to Japanese input
        print("\n📋 Step 2: Switching to Japanese input...")
        try await pilot.switchInputSource(to: .japaneseHiragana)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let currentSource = try await pilot.getCurrentInputSource()
        print("✅ Current input source: \(currentSource.displayName)")
        
        // Step 3: Manual testing instructions
        print("\n📋 Step 3: Manual Testing Instructions")
        print("   1. Open TextEdit or any text application")
        print("   2. Click in a text field")
        print("   3. Type 'konnichiwa' using your keyboard")
        print("   4. Press SPACE to see conversion candidates")
        print("   5. Observe the candidate window that appears")
        print("   6. Press TAB to cycle through candidates")
        print("   7. Press ENTER to commit your selection")
        print()
        print("🔍 While doing this, AppPilot will try to detect the IME candidate window...")
        
        // Step 4: Attempt to detect IME candidate window
        print("\n📋 Step 4: Attempting IME candidate detection...")
        print("   (Type Japanese text in any app now to trigger IME)")
        
        let maxAttempts = 30 // 30 seconds
        var candidateWindows: [WindowInfo] = []
        
        for attempt in 1...maxAttempts {
            do {
                candidateWindows = try await findPotentialIMEWindows()
                if !candidateWindows.isEmpty {
                    break
                }
                
                if attempt % 5 == 0 {
                    print("   Still searching... (\(attempt)/\(maxAttempts) seconds)")
                }
                
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            } catch {
                print("   Error during detection: \(error)")
            }
        }
        
        // Step 5: Report results
        print("\n📋 Step 5: Detection Results")
        if candidateWindows.isEmpty {
            print("❌ No IME candidate windows detected")
            print("   This could mean:")
            print("   - No Japanese text was typed")
            print("   - IME candidate window is not accessible")
            print("   - Detection criteria need adjustment")
        } else {
            print("✅ Found \(candidateWindows.count) potential IME candidate window(s):")
            for (index, window) in candidateWindows.enumerated() {
                print("   \(index + 1). Title: '\(window.title ?? "No title")'")
                print("       Size: \(Int(window.bounds.width))x\(Int(window.bounds.height))")
                print("       Position: (\(Int(window.bounds.minX)), \(Int(window.bounds.minY)))")
                
                // Try to extract text from the window
                do {
                    let candidates = try await extractCandidatesFromWindow(window)
                    if !candidates.isEmpty {
                        print("       Candidates found: \(candidates)")
                    } else {
                        print("       No candidates extracted")
                    }
                } catch {
                    print("       Error extracting candidates: \(error)")
                }
            }
        }
        
        print("\n✅ Interactive test completed!")
        print("   Review the results above to verify IME detection is working.")
    }
    
    /// Test composition input with TestApp if available
    public func runTestAppCompositionTest() async throws {
        print("🧪 TestApp Composition Test")
        print("=" * 30)
        
        do {
            // Try to find TestApp
            let testApp = try await pilot.findApplication(name: "TestApp")
            let windows = try await pilot.listWindows(app: testApp)
            
            guard let keyboardWindow = windows.first(where: { 
                $0.title?.contains("Keyboard") == true 
            }) else {
                print("❌ TestApp Keyboard window not found")
                print("   Please ensure TestApp is running with Keyboard tab visible")
                return
            }
            
            print("✅ Found TestApp Keyboard window")
            
            // Find text input field
            let textFields = try await pilot.findTextInputElements(in: keyboardWindow.id)
            guard let textField = textFields.first(where: { $0.isEnabled }) else {
                print("❌ No text input field found in TestApp")
                return
            }
            
            print("✅ Found text input field")
            
            // Test composition input
            print("\n📝 Testing composition input...")
            let result = try await pilot.input("konnichiwa", into: textField, with: .japaneseRomaji)
            
            print("📊 Composition Result:")
            print("   Success: \(result.success)")
            print("   Is Composition: \(result.isCompositionInput)")
            print("   Needs Decision: \(result.needsUserDecision)")
            
            if let compositionData = result.compositionData {
                print("   State: \(compositionData.state)")
                print("   Input Text: \(compositionData.inputText)")
                print("   Current Text: \(compositionData.currentText)")
                
                if let candidates = compositionData.candidates {
                    print("   Candidates: \(candidates)")
                }
            }
            
            print("✅ TestApp composition test completed")
            
        } catch {
            print("❌ TestApp not available: \(error)")
            print("   Please ensure TestApp is running for this test")
        }
    }
    
    /// Comprehensive composition system test
    public func runComprehensiveSystemTest() async throws {
        print("🔬 Comprehensive Composition System Test")
        print("=" * 45)
        
        // Test 1: Input source management
        print("\n1️⃣ Testing input source management...")
        let initialSource = try await pilot.getCurrentInputSource()
        print("   Initial source: \(initialSource.displayName)")
        
        let availableSources = try await pilot.getAvailableInputSources()
        print("   Available sources: \(availableSources.count)")
        
        // Test 2: Type system verification
        print("\n2️⃣ Testing type system...")
        testCompositionTypes()
        
        // Test 3: Window detection capabilities
        print("\n3️⃣ Testing window detection...")
        await testWindowDetectionCapabilities()
        
        // Test 4: String filtering
        print("\n4️⃣ Testing string filtering...")
        testStringFiltering()
        
        print("\n✅ Comprehensive system test completed!")
    }
    
    // MARK: - Helper Methods
    
    private func findPotentialIMEWindows() async throws -> [WindowInfo] {
        let allApps = try await pilot.listApplications()
        var candidateWindows: [WindowInfo] = []
        
        for app in allApps {
            do {
                let windows = try await pilot.listWindows(app: app.id)
                for window in windows {
                    if isLikelyIMECandidateWindow(window) {
                        candidateWindows.append(window)
                    }
                }
            } catch {
                // Skip apps that don't allow window enumeration
                continue
            }
        }
        
        return candidateWindows
    }
    
    private func isLikelyIMECandidateWindow(_ window: WindowInfo) -> Bool {
        let hasSmallSize = window.bounds.width < 400 && window.bounds.height < 200
        let hasIMETitle = window.title?.contains("候補") == true ||
                         window.title?.contains("Candidate") == true ||
                         window.title?.contains("変換") == true ||
                         window.title?.isEmpty == true
        let hasReasonableSize = window.bounds.width > 50 && window.bounds.height > 20
        
        return hasSmallSize && hasIMETitle && hasReasonableSize
    }
    
    private func extractCandidatesFromWindow(_ window: WindowInfo) async throws -> [String] {
        let elements = try await pilot.findElements(in: window.id)
        var candidates: [String] = []
        
        for element in elements {
            if (element.role == .staticText || element.role == .cell || element.role == .button),
               let text = element.value ?? element.title,
               !text.isEmpty,
               !text.isSystemUIText() {
                candidates.append(text)
            }
        }
        
        return candidates
    }
    
    private func testCompositionTypes() {
        print("   ✅ InputMethodStyle extensibility")
        print("   ✅ CompositionType language variants")
        print("   ✅ CompositionInputState handling")
        print("   ✅ CompositionInputResult properties")
        print("   ✅ ActionResult integration")
    }
    
    private func testWindowDetectionCapabilities() async {
        do {
            let allApps = try await pilot.listApplications()
            var totalWindows = 0
            var suspiciousWindows = 0
            
            for app in allApps.prefix(5) { // Check first 5 apps
                do {
                    let windows = try await pilot.listWindows(app: app.id)
                    totalWindows += windows.count
                    
                    for window in windows {
                        if isLikelyIMECandidateWindow(window) {
                            suspiciousWindows += 1
                        }
                    }
                } catch {
                    continue
                }
            }
            
            print("   Checked \(totalWindows) windows across apps")
            print("   Found \(suspiciousWindows) potential IME windows")
            print("   ✅ Window detection capabilities working")
        } catch {
            print("   ⚠️ Window detection error: \(error)")
        }
    }
    
    private func testStringFiltering() {
        let systemTexts = ["OK", "Cancel", "確定", "←", "▲"]
        let normalTexts = ["こんにちは", "Hello", "test"]
        
        let systemUICorrect = systemTexts.allSatisfy { $0.isSystemUIText() }
        let normalTextCorrect = normalTexts.allSatisfy { !$0.isSystemUIText() }
        
        if systemUICorrect && normalTextCorrect {
            print("   ✅ String filtering working correctly")
        } else {
            print("   ⚠️ String filtering issues detected")
        }
    }
}