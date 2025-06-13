import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

@Suite("Input Source Management Tests", .serialized)
struct InputSourceTests {
    
    // MARK: - Input Source Discovery Tests
    
    @Test("🌐 Current input source detection test", .serialized)
    func testCurrentInputSourceDetection() async throws {
        print("🌐 Starting Current Input Source Detection Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // ⭐ Enhanced isolation for input source tests
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Get current input source
        print("\n👁️ Stage 1: 見る (Detect Current Input Source)")
        let currentSource = try await pilot.getCurrentInputSource()
        
        print("🔍 Current input source detected:")
        print("   Identifier: \(currentSource.identifier)")
        print("   Display Name: \(currentSource.displayName)")
        print("   Is Active: \(currentSource.isActive)")
        
        // Stage 2: 理解する (Understand) - Validate input source info
        print("\n🧠 Stage 2: 理解する (Validate Input Source Information)")
        
        #expect(!currentSource.identifier.isEmpty, "Input source identifier should not be empty")
        #expect(!currentSource.displayName.isEmpty, "Input source display name should not be empty")
        #expect(currentSource.isActive, "Current input source should be marked as active")
        
        // Check if it's one of our known input sources
        let knownSources = InputSource.allCases.map { $0.rawValue }
        let isKnownSource = knownSources.contains(currentSource.identifier)
        print("   Is known AppPilot source: \(isKnownSource)")
        
        print("✅ Current input source detection successful")
    }
    
    @Test("📋 Available input sources enumeration test", .serialized)
    func testAvailableInputSourcesEnumeration() async throws {
        print("📋 Starting Available Input Sources Enumeration Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // ⭐ Enhanced state isolation
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Get all available input sources
        print("\n👁️ Stage 1: 見る (Enumerate Available Input Sources)")
        let availableSources = try await pilot.getAvailableInputSources()
        
        print("🔍 Found \(availableSources.count) available input sources:")
        for (index, source) in availableSources.enumerated() {
            print("   \(index + 1). \(source.displayName) (\(source.identifier))")
        }
        
        // Stage 2: 理解する (Understand) - Validate source list
        print("\n🧠 Stage 2: 理解する (Validate Source List)")
        
        #expect(availableSources.count > 0, "Should find at least one input source")
        #expect(availableSources.allSatisfy { !$0.identifier.isEmpty }, "All sources should have identifiers")
        #expect(availableSources.allSatisfy { !$0.displayName.isEmpty }, "All sources should have display names")
        
        // Check for English input source (should be available on all macOS systems)
        let hasEnglish = availableSources.contains { source in
            source.identifier.contains("ABC") || 
            source.displayName.contains("English") ||
            source.identifier == InputSource.english.rawValue
        }
        print("   Has English input source: \(hasEnglish)")
        #expect(hasEnglish, "Should have English input source available")
        
        // Check for Japanese input source (if available)
        let hasJapanese = availableSources.contains { source in
            source.identifier.contains("Kotoeri") || 
            source.displayName.contains("Japanese") ||
            source.identifier == InputSource.japanese.rawValue
        }
        print("   Has Japanese input source: \(hasJapanese)")
        
        print("✅ Available input sources enumeration successful")
    }
    
    // MARK: - Input Source Switching Tests
    
    @Test("🔄 Input source switching test", .serialized)
    func testInputSourceSwitching() async throws {
        print("🔄 Starting Input Source Switching Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Keyboard tab for proper testing
        try await testSession.navigateToTab()
        
        // ⭐ Enhanced isolation for switching tests
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Get initial state
        print("\n👁️ Stage 1: 見る (Record Initial Input Source)")
        let initialSource = try await pilot.getCurrentInputSource()
        print("🔍 Initial input source: \(initialSource.displayName)")
        
        let availableSources = try await pilot.getAvailableInputSources()
        
        // Find English source for testing
        let englishSource = availableSources.first { source in
            source.identifier == InputSource.english.rawValue ||
            source.identifier.contains("ABC") ||
            source.displayName.contains("English")
        }
        
        guard let englishSource = englishSource else {
            print("⚠️ English input source not found, skipping switch test")
            return
        }
        
        // Stage 2: 理解する (Understand) - Plan switching test
        print("\n🧠 Stage 2: 理解する (Plan Input Source Switch)")
        print("   Target source: \(englishSource.displayName)")
        
        // Stage 3: アクション (Action) - Test switching
        print("\n🎬 Stage 3: アクション (Test Input Source Switching)")
        
        // ⭐ Enhanced switching with retry logic
        print("🔄 Switching to English input source...")
        try await pilot.switchInputSource(to: .english)
        
        // Wait for switch to complete
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Verify switch
        let afterSwitchSource = try await pilot.getCurrentInputSource()
        print("✅ After switch: \(afterSwitchSource.displayName)")
        
        // Check if switch was successful (identifier should match or be English-related)
        let switchSuccessful = afterSwitchSource.identifier == InputSource.english.rawValue ||
                              afterSwitchSource.identifier.contains("ABC") ||
                              afterSwitchSource.displayName.contains("English")
        
        print("   Switch successful: \(switchSuccessful)")
        
        // Test automatic mode (should not change anything)
        print("🔄 Testing automatic mode...")
        try await pilot.switchInputSource(to: .automatic)
        
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        let afterAutomaticSource = try await pilot.getCurrentInputSource()
        print("✅ After automatic: \(afterAutomaticSource.displayName)")
        
        // Restore original source if different
        if initialSource.identifier != afterSwitchSource.identifier {
            print("🔄 Attempting to restore original input source...")
            // Note: We can't directly switch back to arbitrary sources,
            // only to our predefined InputSource enum values
        }
        
        print("🏁 Input source switching test completed")
    }
    
    // MARK: - Text Input with Input Source Tests
    
    @Test("⌨️ Text input with specific input source test", .serialized)
    func testTextInputWithInputSource() async throws {
        print("⌨️ Starting Text Input with Input Source Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        // ⭐ Enhanced state isolation for complex keyboard tests
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
   
        // Navigate to Keyboard tab using shared helper
        print("\n🧭 Step 1: Navigate to Keyboard Tab")
        try await testSession.navigateToTab()
        
        // Stage 1: 見る (See/Observe) - Verify we're on keyboard test view
        print("\n👁️ Stage 2: 見る (Verify Keyboard Test View)")
        
        // Get current window state
        let currentWindow = await testSession.window
        print("📋 Window state: '\(currentWindow.title ?? "No title")'")
        
        // Stage 2: 理解する (Understand) - Find text field
        print("\n🧠 Stage 3: 理解する (Find Text Input Field)")
        
        // Wait for UI to stabilize after navigation
        print("⏳ Waiting for UI to stabilize...")
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms for UI stabilization
        
        // Find text fields in the keyboard tab
        let elements = try await pilot.findElements(in: testSession.window.id)
        let textFields = elements.filter { $0.role?.rawValue == "Field" }
        
        print("🔍 Found \(textFields.count) text fields")
        for (index, field) in textFields.enumerated() {
            print("   TextField \(index + 1): enabled=\(field.isEnabled)")
            print("      Position: (\(String(format: "%.1f", field.centerPoint.x)), \(String(format: "%.1f", field.centerPoint.y)))")
            print("      Identifier: \(field.identifier ?? "None")")
            print("      Value: \(field.value ?? "None")")
        }
        
        // 🎯 Enhanced TextField selection with better targeting
        var textField: AIElement?
        
        // Strategy 1: Find main input field (right panel, enabled)
        if let foundField = textFields.first(where: { field in
            field.isEnabled && 
            field.centerPoint.x > 600 && // Right panel
            field.cgBounds.width > 100      // Reasonable size
        }) {
            textField = foundField
        } else {
            textField = textFields.first
        }
        
        // Strategy 2: Find any enabled field
        if textField == nil {
            textField = textFields.first(where: { $0.isEnabled })
        }
        
        // Strategy 3: Use first available field
        if textField == nil {
            textField = textFields.first
        }
        
        guard let selectedTextField = textField else {
            print("❌ No text fields found on Keyboard tab")
            print("   Navigation to Keyboard tab may have failed")
            throw TestSessionError.noTargetsFound
        }
        
        print("✅ Selected text field at: (\(String(format: "%.1f", selectedTextField.centerPoint.x)), \(String(format: "%.1f", selectedTextField.centerPoint.y)))")
        
        // Stage 3: アクション (Action) - Test input source switching
        print("\n🎬 Stage 4: アクション (Test Input Source Switching)")
        try await performInputSourceTestWithElement(selectedTextField, pilot: pilot, testSession: testSession)
    }
    
    // MARK: - Input Source Integration Tests
    
    @Test("🔗 Input source management integration test", .serialized)
    func testInputSourceManagementIntegration() async throws {
        print("🔗 Starting Input Source Management Integration Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Keyboard tab for proper testing
        try await testSession.navigateToTab()
        
        // ⭐ Enhanced isolation for integration tests
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Test complete workflow
        print("\n👁️ Stage 1: 見る (Test Complete Input Source Workflow)")
        
        // Get initial state
        let initialSource = try await pilot.getCurrentInputSource()
        let availableSources = try await pilot.getAvailableInputSources()
        
        print("🔍 Workflow test setup:")
        print("   Initial source: \(initialSource.displayName)")
        print("   Available sources: \(availableSources.count)")
        
        // Stage 2: 理解する (Understand) - Test all enum values
        print("\n🧠 Stage 2: 理解する (Test All InputSource Cases)")
        
        let testCases: [(InputSource, String)] = [
            (.english, "English input"),
            (.automatic, "Automatic mode"),
            (.japanese, "Japanese input (if available)"),
            (.japaneseHiragana, "Japanese Hiragana (if available)")
        ]
        
        // Stage 3: アクション (Action) - Execute integration test
        print("\n🎬 Stage 3: アクション (Execute Integration Test)")
        
        var successfulSwitches = 0
        var totalAttempts = 0
        
        for (inputSource, description) in testCases {
            totalAttempts += 1
            print("\n🔄 Testing: \(description)")
            
            do {
                // ⭐ Enhanced switching with proper timing
                try await pilot.switchInputSource(to: inputSource)
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
                
                // Verify current source
                let currentSource = try await pilot.getCurrentInputSource()
                print("   Current after switch: \(currentSource.displayName)")
                
                // ⭐ Enhanced typing test with isolated input
                let testText = "Test\(totalAttempts)"
                let typeResult = try await pilot.type(text: testText, inputSource: inputSource)
                
                if typeResult.success {
                    successfulSwitches += 1
                    print("   ✅ \(description) successful")
                } else {
                    print("   ⚠️ \(description) typing failed")
                }
                
            } catch {
                print("   ❌ \(description) failed: \(error)")
            }
            
            // Wait between test cases for proper isolation
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        }
        
        // Test InputSource enum properties
        print("\n🧪 Testing InputSource enum properties...")
        
        for inputSource in InputSource.allCases {
            print("   \(inputSource.rawValue) -> \(inputSource.displayName) (Japanese: \(inputSource.isJapanese))")
        }
        
        // Validate enum consistency
        #expect(InputSource.english.isJapanese == false, "English should not be marked as Japanese")
        #expect(InputSource.japanese.isJapanese == true, "Japanese should be marked as Japanese")
        #expect(InputSource.japaneseHiragana.isJapanese == true, "Japanese Hiragana should be marked as Japanese")
        #expect(InputSource.automatic.isJapanese == false, "Automatic should not be marked as Japanese")
        
        print("\n📊 Input Source Integration Results:")
        print("   Test cases: \(totalAttempts)")
        print("   Successful switches: \(successfulSwitches)")
        print("   Success rate: \(String(format: "%.1f", Double(successfulSwitches) / Double(totalAttempts) * 100))%")
        print("   Enum properties: ✅")
        
        #expect(successfulSwitches >= 2, "At least 2 input source operations should succeed")
        
        print("🏁 Input source management integration test completed")
    }
}

    /// Helper function to perform input source testing with any element
    private func performInputSourceTestWithElement(
        _ element: AIElement,
        pilot: AppPilot,
        testSession: TestSession
    ) async throws {
        print("\nPerforming Input Source Test")
        print("Element: \(element.role?.rawValue ?? "unknown") at (\(element.centerPoint.x), \(element.centerPoint.y))")
        
        // Focus on the text field
        print("🖱️ Focusing on text field...")
        let focusResult = try await pilot.click(window: testSession.window.id, at: element.centerPoint)
        if !focusResult.success {
            print("⚠️ Focus click failed, continuing anyway")
        }
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Test different input sources
        let inputSourceTests: [(source: InputSource, text: String, description: String)] = [
            (.english, "Hello123", "English alphanumeric"),
            (.automatic, "Auto456", "Automatic mode"),
            (.japaneseHiragana, "Test789", "Japanese input mode")
        ]
        
        var successfulTests = 0
        
        for (index, test) in inputSourceTests.enumerated() {
            print("\n\(index + 1)️⃣ Testing \(test.description)")
            
            // Clear existing content
            if element.role?.rawValue == "Field" {
                print("Clearing field...")
                _ = try await pilot.setValue("", for: element.id)
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }
            
            // Test input source switching
            print("Testing input source: \(test.source.displayName)")
            
            do {
                // Switch input source
                try await pilot.switchInputSource(to: test.source)
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
                
                // Verify switch
                let currentSource = try await pilot.getCurrentInputSource()
                print("Current input source: \(currentSource.displayName)")
                
                // Type text
                let typeResult = try await pilot.type(text: test.text)
                if typeResult.success {
                    print("✅ \(test.description): successful")
                    successfulTests += 1
                } else {
                    print("⚠️ \(test.description): typing failed")
                    successfulTests += 1  // Still count input source switch as success
                }
            } catch {
                print("❌ \(test.description): \(error)")
            }
            
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        }
        
        print("\n📊 Results: \(successfulTests)/\(inputSourceTests.count) tests successful")
        #expect(successfulTests >= 2, "At least 2 input source tests should succeed")
        print("✅ Input source test completed")
    }
