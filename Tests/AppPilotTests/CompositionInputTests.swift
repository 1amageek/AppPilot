import Testing
import Foundation
@testable import AppPilot

/// Unit tests for composition input types and functionality
@Suite("Composition Input Unit Tests")
struct CompositionInputTests {
    
    // MARK: - Type System Tests
    
    @Test("InputMethodStyle should be extensible")
    func testInputMethodStyleExtensibility() async throws {
        // Test predefined styles
        #expect(InputMethodStyle.japaneseRomaji.rawValue == "ja-romaji")
        #expect(InputMethodStyle.chinesePinyin.rawValue == "zh-pinyin")
        
        // Test custom styles
        let customStyle = InputMethodStyle(rawValue: "custom-style")
        #expect(customStyle.rawValue == "custom-style")
        
        // Test equality
        let style1 = InputMethodStyle.japaneseRomaji
        let style2 = InputMethodStyle(rawValue: "ja-romaji")
        #expect(style1 == style2)
    }
    
    @Test("CompositionType should support language variants")
    func testCompositionTypeVariants() async throws {
        // Test predefined compositions
        let japaneseRomaji = CompositionType.japaneseRomaji
        #expect(japaneseRomaji.rawValue == "japanese")
        #expect(japaneseRomaji.style?.rawValue == "ja-romaji")
        
        // Test custom compositions
        let customStyle = InputMethodStyle(rawValue: "ja-custom")
        let customComposition = CompositionType.japanese(customStyle)
        #expect(customComposition.rawValue == "japanese")
        #expect(customComposition.style?.rawValue == "ja-custom")
        
        // Test RawRepresentable conformance
        let rawComposition = CompositionType(rawValue: "korean")
        #expect(rawComposition?.rawValue == "korean")
        #expect(rawComposition?.style == nil)
    }
    
    @Test("CompositionInputState should handle all states correctly")
    func testCompositionInputStates() async throws {
        // Test composing state
        let composingState = CompositionInputState.composing(
            text: "こんにちわ", 
            suggestions: ["こんにちは", "こんにちわ"]
        )
        
        if case .composing(let text, let suggestions) = composingState {
            #expect(text == "こんにちわ")
            #expect(suggestions.count == 2)
        } else {
            Issue.record("Expected composing state")
        }
        
        // Test candidate selection state
        let candidateState = CompositionInputState.candidateSelection(
            original: "konnichiwa",
            candidates: ["こんにちは", "こんにちわ", "今日は"],
            selectedIndex: 1
        )
        
        if case .candidateSelection(let original, let candidates, let index) = candidateState {
            #expect(original == "konnichiwa")
            #expect(candidates.count == 3)
            #expect(index == 1)
        } else {
            Issue.record("Expected candidate selection state")
        }
        
        // Test committed state
        let committedState = CompositionInputState.committed(text: "こんにちは")
        if case .committed(let text) = committedState {
            #expect(text == "こんにちは")
        } else {
            Issue.record("Expected committed state")
        }
    }
    
    @Test("CompositionInputResult should provide convenient properties")
    func testCompositionInputResultProperties() async throws {
        // Test candidate selection result
        let result = CompositionInputResult(
            state: .candidateSelection(
                original: "konnichiwa",
                candidates: ["こんにちは", "こんにちわ", "今日は"],
                selectedIndex: 0
            ),
            inputText: "konnichiwa",
            currentText: "こんにちわ",
            needsUserDecision: true,
            availableActions: [.selectCandidate(index: 0), .nextCandidate, .commit],
            compositionType: .japaneseRomaji
        )
        
        // Test convenience properties
        #expect(result.candidates?.count == 3)
        #expect(result.selectedCandidateIndex == 0)
        #expect(!result.isCompleted)
        #expect(result.needsUserDecision)
        
        // Test committed result
        let committedResult = CompositionInputResult(
            state: .committed(text: "こんにちは"),
            inputText: "konnichiwa",
            currentText: "こんにちは",
            needsUserDecision: false,
            availableActions: [],
            compositionType: .japaneseRomaji
        )
        
        #expect(committedResult.candidates == nil)
        #expect(committedResult.selectedCandidateIndex == nil)
        #expect(committedResult.isCompleted)
        #expect(!committedResult.needsUserDecision)
    }
    
    // MARK: - ActionResult Integration Tests
    
    @Test("ActionResult should support composition data")
    func testActionResultCompositionIntegration() async throws {
        let compositionResult = CompositionInputResult(
            state: .candidateSelection(
                original: "test",
                candidates: ["テスト", "test"],
                selectedIndex: 0
            ),
            inputText: "test",
            currentText: "テスト",
            needsUserDecision: true,
            availableActions: [.commit],
            compositionType: .japaneseRomaji
        )
        
        let actionResult = ActionResult(
            success: true,
            data: .type(
                inputText: "test",
                actualText: "テスト",
                inputSource: .japaneseHiragana,
                composition: compositionResult
            )
        )
        
        // Test convenience properties
        #expect(actionResult.isCompositionInput)
        #expect(!actionResult.isDirectInput)
        #expect(actionResult.needsUserDecision)
        #expect(!actionResult.isCompositionCompleted)
        #expect(actionResult.compositionCandidates?.count == 2)
        #expect(actionResult.selectedCandidateIndex == 0)
        
        // Test type data extraction
        let typeData = actionResult.typeData
        #expect(typeData?.inputText == "test")
        #expect(typeData?.actualText == "テスト")
        #expect(typeData?.composition != nil)
    }
    
    @Test("ActionResult should handle direct input correctly")
    func testActionResultDirectInput() async throws {
        let actionResult = ActionResult(
            success: true,
            data: .type(
                inputText: "hello",
                actualText: "hello",
                inputSource: .english,
                composition: nil
            )
        )
        
        // Test direct input properties
        #expect(!actionResult.isCompositionInput)
        #expect(actionResult.isDirectInput)
        #expect(!actionResult.needsUserDecision)
        #expect(actionResult.isCompositionCompleted) // true for non-composition
        #expect(actionResult.compositionCandidates == nil)
        #expect(actionResult.selectedCandidateIndex == nil)
    }
    
    // MARK: - String Extension Tests
    
    @Test("String extension should filter system UI text")
    func testStringSystemUIFiltering() async throws {
        // Test system UI text detection
        #expect("OK".isSystemUIText())
        #expect("Cancel".isSystemUIText())
        #expect("確定".isSystemUIText())
        #expect("キャンセル".isSystemUIText())
        #expect("←".isSystemUIText())
        #expect("▲".isSystemUIText())
        
        // Test normal text
        #expect(!"こんにちは".isSystemUIText())
        #expect(!"Hello".isSystemUIText())
        #expect(!"test123".isSystemUIText())
        #expect(!"日本語".isSystemUIText())
        
        // Test edge cases
        #expect(!"".isSystemUIText())
        #expect(!"a".isSystemUIText()) // Single letter should not be considered system UI
    }
}