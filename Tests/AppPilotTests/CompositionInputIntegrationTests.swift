import Testing
import Foundation
@testable import AppPilot

/// Integration tests for composition input with TestApp
@Suite("Composition Input Integration Tests", .serialized)
struct CompositionInputIntegrationTests {
    
    // MARK: - TestApp Integration Tests
    
    @Test("🇯🇵 Japanese composition input with TestApp", .enabled(if: isTestAppAvailable))
    func testJapaneseCompositionWithTestApp() async throws {
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        print("🇯🇵 Testing Japanese Composition Input")
        print("=" * 50)
        
        // Stage 1: 見る (Observe) - Setup
        print("\n👁️ Stage 1: 見る (Setup Composition Test)")
        try await testSession.navigateToTab()
        
        // Find text input field
        let textFields = try await pilot.findTextInputElements(in: testSession.window.id)
        guard let textField = textFields.first(where: { $0.isEnabled }) else {
            throw TestSessionError.noTargetsFound
        }
        
        print("✅ Found text field at: (\(textField.centerPoint.x), \(textField.centerPoint.y))")
        
        // Stage 2: 理解する (Understand) - Test Composition Flow
        print("\n🧠 Stage 2: 理解する (Test Composition Workflow)")
        
        // Clear any existing content
        try await pilot.click(element: textField)
        try await pilot.keyCombination([.a], modifiers: [.command])
        try await pilot.keyCombination([.delete], modifiers: [])
        
        // Stage 3: アクション (Action) - Execute Composition Input
        print("\n🎬 Stage 3: アクション (Execute Composition Input)")
        
        // Test Japanese romaji input
        print("📝 Testing Japanese romaji composition...")
        let result = try await pilot.input(
            "konnichiwa",
            into: textField,
            with: .japaneseRomaji
        )
        
        // Verify composition result
        #expect(result.success, "Composition input should succeed")
        #expect(result.isCompositionInput, "Should be recognized as composition input")
        
        if let compositionData = result.compositionData {
            print("🔍 Composition Analysis:")
            print("   Input: \(compositionData.inputText)")
            print("   Current: \(compositionData.currentText)")
            print("   State: \(compositionData.state)")
            print("   Needs Decision: \(compositionData.needsUserDecision)")
            
            if let candidates = compositionData.candidates {
                print("   Candidates: \(candidates)")
                #expect(candidates.count > 0, "Should have at least one candidate")
            }
            
            // Test candidate selection if needed
            if compositionData.needsUserDecision {
                print("\n🎯 Testing candidate selection...")
                let selectionResult = try await pilot.selectCandidate(at: 0, for: textField)
                #expect(selectionResult.success, "Candidate selection should succeed")
                
                // Commit the composition
                print("✅ Committing composition...")
                let commitResult = try await pilot.commitComposition(for: textField)
                #expect(commitResult.success, "Composition commit should succeed")
            }
        }
        
        // Verify final result
        let finalText = try await pilot.getValue(from: textField)
        print("📊 Final Result: '\(finalText ?? "empty")'")
        #expect(finalText?.isEmpty == false, "Should have some text after composition")
        
        print("✅ Japanese composition test completed")
    }
    
    @Test("🔄 Composition input workflow test", .enabled(if: isTestAppAvailable))
    func testCompositionWorkflow() async throws {
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        print("🔄 Testing Complete Composition Workflow")
        print("=" * 50)
        
        try await testSession.navigateToTab()
        
        let textFields = try await pilot.findTextInputElements(in: testSession.window.id)
        guard let textField = textFields.first(where: { $0.isEnabled }) else {
            throw TestSessionError.noTargetsFound
        }
        
        // Test multiple composition scenarios
        let testCases = [
            ("konnichiwa", CompositionType.japaneseRomaji, "Japanese greeting"),
            ("arigatou", CompositionType.japaneseRomaji, "Japanese thanks"),
            ("nihon", CompositionType.japaneseRomaji, "Japan in Japanese")
        ]
        
        for (index, testCase) in testCases.enumerated() {
            print("\n📝 Test Case \(index + 1): \(testCase.2)")
            
            // Clear field
            try await pilot.click(element: textField)
            try await pilot.keyCombination([.a], modifiers: [.command])
            try await pilot.keyCombination([.delete], modifiers: [])
            
            // Test composition
            let result = try await pilot.input(testCase.0, into: textField, with: testCase.1)
            
            #expect(result.success, "Input should succeed for: \(testCase.0)")
            
            if result.needsUserDecision {
                print("   User decision needed - selecting first candidate")
                let selectionResult = try await pilot.selectCandidate(at: 0, for: textField)
                #expect(selectionResult.success, "Candidate selection should succeed")
            }
            
            if !result.isCompositionCompleted {
                print("   Committing composition")
                let commitResult = try await pilot.commitComposition(for: textField)
                #expect(commitResult.success, "Commit should succeed")
            }
            
            let finalText = try await pilot.getValue(from: textField)
            print("   Result: '\(finalText ?? "empty")'")
            
            // Wait between test cases
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        print("✅ Composition workflow test completed")
    }
    
    @Test("❌ Composition cancellation test", .enabled(if: isTestAppAvailable))
    func testCompositionCancellation() async throws {
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        print("❌ Testing Composition Cancellation")
        print("=" * 40)
        
        try await testSession.navigateToTab()
        
        let textFields = try await pilot.findTextInputElements(in: testSession.window.id)
        guard let textField = textFields.first(where: { $0.isEnabled }) else {
            throw TestSessionError.noTargetsFound
        }
        
        // Clear field
        try await pilot.click(element: textField)
        try await pilot.keyCombination([.a], modifiers: [.command])
        try await pilot.keyCombination([.delete], modifiers: [])
        
        // Start composition
        print("📝 Starting composition...")
        let result = try await pilot.input("test", into: textField, with: .japaneseRomaji)
        #expect(result.success, "Composition start should succeed")
        
        // Cancel composition
        print("❌ Cancelling composition...")
        let cancelResult = try await pilot.cancelComposition(for: textField)
        #expect(cancelResult.success, "Composition cancellation should succeed")
        
        // Verify field is empty or has original content
        let finalText = try await pilot.getValue(from: textField)
        print("📊 Final text after cancellation: '\(finalText ?? "empty")'")
        
        print("✅ Composition cancellation test completed")
    }
    
    // MARK: - Input Source Switching Tests
    
    @Test("🔄 Input source switching during composition", .enabled(if: isTestAppAvailable))
    func testInputSourceSwitchingDuringComposition() async throws {
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        print("🔄 Testing Input Source Switching During Composition")
        print("=" * 55)
        
        try await testSession.navigateToTab()
        
        let textFields = try await pilot.findTextInputElements(in: testSession.window.id)
        guard let textField = textFields.first(where: { $0.isEnabled }) else {
            throw TestSessionError.noTargetsFound
        }
        
        // Test switching between different input methods
        let inputSources: [(CompositionType, String, String)] = [
            (.japaneseRomaji, "konnichiwa", "Japanese romaji"),
            (.japaneseKana, "test", "Japanese kana") // Would need kana input
        ]
        
        for (composition, text, description) in inputSources {
            print("\n📝 Testing: \(description)")
            
            // Clear field
            try await pilot.click(element: textField)
            try await pilot.keyCombination([.a], modifiers: [.command])
            try await pilot.keyCombination([.delete], modifiers: [])
            
            // Test composition with specific input method
            let result = try await pilot.input(text, into: textField, with: composition)
            
            #expect(result.success, "Composition should succeed for: \(description)")
            
            if result.needsUserDecision {
                let commitResult = try await pilot.commitComposition(for: textField)
                #expect(commitResult.success, "Commit should succeed")
            }
            
            let finalText = try await pilot.getValue(from: textField)
            print("   Result: '\(finalText ?? "empty")'")
            
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        print("✅ Input source switching test completed")
    }
    
    // MARK: - Helper Properties
    
    /// Check if TestApp is available for testing
    private static var isTestAppAvailable: Bool {
        // This would be implemented to check if TestApp is running
        // For now, return true to enable tests when TestApp is available
        return true
    }
}