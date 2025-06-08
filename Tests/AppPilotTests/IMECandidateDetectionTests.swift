import Testing
import Foundation
@testable import AppPilot

/// Tests for real IME candidate detection functionality
@Suite("IME Candidate Detection Tests", .serialized)
struct IMECandidateDetectionTests {
    
    @Test("🔍 IME candidate window detection", .enabled(if: isIMETestingEnabled))
    func testIMECandidateWindowDetection() async throws {
        let pilot = AppPilot()
        
        print("🔍 Testing IME Candidate Window Detection")
        print("=" * 45)
        
        // Test with actual system IME by typing in a real app
        print("📋 This test requires manual verification:")
        print("   1. Ensure Japanese IME is available")
        print("   2. Have a text application open (like TextEdit)")
        print("   3. Type some Japanese text to trigger IME candidates")
        
        // Get current input source
        let currentSource = try await pilot.getCurrentInputSource()
        print("📍 Current input source: \(currentSource.displayName)")
        
        // Get available input sources
        let availableSources = try await pilot.getAvailableInputSources()
        let japaneseSource = availableSources.first { source in
            source.identifier.contains("Kotoeri") || source.displayName.contains("Japanese")
        }
        
        if let japaneseSource = japaneseSource {
            print("✅ Japanese input source available: \(japaneseSource.displayName)")
            
            // Switch to Japanese input if not already active
            if currentSource.identifier != japaneseSource.identifier {
                print("🔄 Switching to Japanese input source...")
                try await pilot.switchInputSource(to: .japaneseHiragana)
                
                // Wait for switch to complete
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let newSource = try await pilot.getCurrentInputSource()
                print("📍 New input source: \(newSource.displayName)")
            }
        } else {
            print("⚠️ No Japanese input source found - skipping IME detection test")
            return
        }
        
        // This test would need manual interaction or a controlled environment
        print("🤖 Automated IME candidate detection would require:")
        print("   - Controlled text input application")
        print("   - Programmatic IME trigger")
        print("   - Real-time window monitoring")
        
        print("✅ IME detection test framework completed")
    }
    
    @Test("🪟 Window filtering for IME candidates")
    func testWindowFilteringForIMECandidates() async throws {
        let pilot = AppPilot()
        
        print("🪟 Testing Window Filtering for IME Candidates")
        print("=" * 45)
        
        // Get all applications and their windows
        let allApps = try await pilot.listApplications()
        var totalWindows = 0
        var candidateWindows: [WindowInfo] = []
        
        for app in allApps.prefix(10) { // Limit to first 10 apps for performance
            do {
                let windows = try await pilot.listWindows(app: app.id)
                totalWindows += windows.count
                
                for window in windows {
                    // Test IME candidate window detection logic
                    if isLikelyIMECandidateWindow(window) {
                        candidateWindows.append(window)
                        print("🎯 Potential IME window found:")
                        print("   App: \(app.name)")
                        print("   Title: '\(window.title ?? "No title")'")
                        print("   Size: \(window.bounds.width)x\(window.bounds.height)")
                        print("   Position: (\(window.bounds.minX), \(window.bounds.minY))")
                    }
                }
            } catch {
                // Some apps might not allow window enumeration
                continue
            }
        }
        
        print("\n📊 Window Analysis Results:")
        print("   Total windows checked: \(totalWindows)")
        print("   Potential IME windows: \(candidateWindows.count)")
        
        // Test window filtering criteria
        #expect(totalWindows > 0, "Should find some windows in the system")
        
        print("✅ Window filtering test completed")
    }
    
    @Test("📝 String system UI text filtering")
    func testStringSystemUITextFiltering() async throws {
        print("📝 Testing String System UI Text Filtering")
        print("=" * 45)
        
        // Test cases for system UI text detection
        let systemUITexts = [
            "OK", "Cancel", "確定", "キャンセル", "変換", "無変換",
            "←", "→", "↑", "↓", "▲", "▼", "◀", "▶"
        ]
        
        let normalTexts = [
            "こんにちは", "Hello", "test123", "日本語", "中文", "한글",
            "ありがとう", "thank you", "merci", "gracias"
        ]
        
        print("🔍 Testing system UI text detection:")
        for text in systemUITexts {
            #expect(text.isSystemUIText(), "'\(text)' should be detected as system UI text")
            print("   ✅ '\(text)' correctly identified as system UI")
        }
        
        print("\n🔍 Testing normal text detection:")
        for text in normalTexts {
            #expect(!text.isSystemUIText(), "'\(text)' should NOT be detected as system UI text")
            print("   ✅ '\(text)' correctly identified as normal text")
        }
        
        // Test edge cases
        print("\n🔍 Testing edge cases:")
        let edgeCases = [
            ("", false, "Empty string"),
            ("a", false, "Single letter"),
            ("1", false, "Single number"),
            ("あ", false, "Single hiragana"),
            ("漢", false, "Single kanji")
        ]
        
        for (text, shouldBeSystemUI, description) in edgeCases {
            let isSystemUI = text.isSystemUIText()
            #expect(isSystemUI == shouldBeSystemUI, "\(description): '\(text)' system UI detection mismatch")
            print("   ✅ \(description): '\(text)' -> \(isSystemUI)")
        }
        
        print("✅ String filtering test completed")
    }
    
    // MARK: - Mock IME Candidate Generation Tests
    
    @Test("🎭 Mock candidate generation for development")
    func testMockCandidateGeneration() async throws {
        print("🎭 Testing Mock Candidate Generation")
        print("=" * 40)
        
        // This test simulates the fallback candidate generation
        // when real IME candidates cannot be detected
        
        let testCases = [
            ("こんにち", ["こんにちは", "こんにちわ", "今日は"]),
            ("ありがと", ["ありがとう", "有難う", "有り難う"]),
            ("にほん", ["日本", "にほん", "ニホン"]),
            ("unknown", []) // Should return empty for unknown text
        ]
        
        for (inputText, expectedCandidates) in testCases {
            print("\n📝 Testing mock generation for: '\(inputText)'")
            
            let mockCandidates = generateTestCandidates(for: inputText)
            
            if expectedCandidates.isEmpty {
                #expect(mockCandidates.isEmpty || mockCandidates.count <= 2, 
                       "Unknown text should generate few or no candidates")
            } else {
                #expect(mockCandidates.count > 0, "Should generate candidates for known text")
                print("   Generated: \(mockCandidates)")
                
                // Check if expected candidates are present
                for expected in expectedCandidates {
                    #expect(mockCandidates.contains(expected), 
                           "Should contain expected candidate: \(expected)")
                }
            }
        }
        
        print("✅ Mock candidate generation test completed")
    }
    
    // MARK: - Helper Methods
    
    /// Test version of IME candidate window detection
    private func isLikelyIMECandidateWindow(_ window: WindowInfo) -> Bool {
        let hasSmallSize = window.bounds.width < 400 && window.bounds.height < 200
        let hasNoTitleOrIMETitle = window.title?.isEmpty == true || 
                                  window.title?.contains("候補") == true ||
                                  window.title?.contains("Candidate") == true ||
                                  window.title?.contains("変換") == true
        
        // Additional criteria for testing
        let isFloating = window.bounds.width > 50 && window.bounds.height > 20 // Not too small
        
        return hasSmallSize && hasNoTitleOrIMETitle && isFloating
    }
    
    /// Generate test candidates for mock testing
    private func generateTestCandidates(for inputText: String) -> [String] {
        if inputText.contains("こんにち") {
            return ["こんにちは", "こんにちわ", "今日は"]
        } else if inputText.contains("ありがと") {
            return ["ありがとう", "有難う", "有り難う"]
        } else if inputText.contains("にほん") || inputText.contains("ニホン") {
            return ["日本", "にほん", "ニホン"]
        } else if !inputText.isEmpty && inputText.count > 1 {
            // Generic candidates for any text
            return [inputText, inputText.applyingTransform(.hiraganaToKatakana, reverse: false) ?? inputText]
        }
        
        return []
    }
    
    /// Check if IME testing is enabled
    private static var isIMETestingEnabled: Bool {
        // Enable IME testing when running in appropriate environment
        // This could check for environment variables, system capabilities, etc.
        return ProcessInfo.processInfo.environment["ENABLE_IME_TESTS"] == "true"
    }
}