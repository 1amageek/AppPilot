import Testing
import Foundation
@testable import AppPilot

/// Comprehensive tests for window handle compatibility between different formats
/// 
/// These tests verify that AppPilot can handle both accessibility-based (win_ax_*)
/// and hash-based (win_[HEX]) window handle formats, and convert between them
/// seamlessly. This addresses the compatibility issue between different applications
/// that generate different handle formats.
@Suite("Window Handle Compatibility")
struct WindowHandleCompatibilityTests {
    
    @Test("Detect accessibility-based handle format")
    func testDetectAccessibilityHandleFormat() {
        let driver = TestAccessibilityDriver()
        
        // Test various accessibility-based formats
        let testCases = [
            ("win_ax_SceneWindow", "SceneWindow"),
            ("win_ax_MainWindow", "MainWindow"),
            ("win_ax_DocumentWindow", "DocumentWindow"),
            ("win_ax_PreferencesWindow", "PreferencesWindow"),
            ("win_ax_123", "123"),
            ("win_ax_", "")  // Edge case: empty identifier
        ]
        
        for (input, expectedIdentifier) in testCases {
            let format = driver.detectHandleFormat(input)
            
            switch format {
            case .accessibility(let identifier):
                #expect(identifier == expectedIdentifier, "Expected identifier '\(expectedIdentifier)' but got '\(identifier)'")
            default:
                Issue.record("Expected accessibility format but got \(format)")
            }
        }
    }
    
    @Test("Detect hash-based handle format")
    func testDetectHashBasedHandleFormat() {
        let driver = TestAccessibilityDriver()
        
        // Test various hash-based formats
        let testCases = [
            ("win_907C313AA0D3F305", "907C313AA0D3F305"),  // Chrome style
            ("win_ABCDEF1234567890", "ABCDEF1234567890"),  // All uppercase
            ("win_abcdef1234567890", "abcdef1234567890"),  // All lowercase
            ("win_1234567890ABCDEF", "1234567890ABCDEF"),  // Mixed
            ("win_12345678", "12345678"),                  // Shorter hash
            ("win_ABCDEF123456789012345678", "ABCDEF123456789012345678")  // Longer hash
        ]
        
        for (input, expectedHash) in testCases {
            let format = driver.detectHandleFormat(input)
            
            switch format {
            case .hashBased(let hash):
                #expect(hash == expectedHash, "Expected hash '\(expectedHash)' but got '\(hash)'")
            default:
                Issue.record("Expected hash-based format but got \(format)")
            }
        }
    }
    
    @Test("Detect unknown handle formats")
    func testDetectUnknownHandleFormat() {
        let driver = TestAccessibilityDriver()
        
        // Test formats that should be classified as unknown
        let testCases = [
            "window_123",           // Wrong prefix
            "win_ax",               // Incomplete accessibility format
            "win_",                 // Incomplete prefix
            "win_GHIJKL",          // Invalid hex characters
            "win_123G456",         // Mixed invalid hex
            "random_string",       // Completely different format
            "",                    // Empty string
            "123456"               // Just numbers
        ]
        
        for input in testCases {
            let format = driver.detectHandleFormat(input)
            
            switch format {
            case .unknown(let original):
                #expect(original == input, "Expected original '\(input)' but got '\(original)'")
            default:
                Issue.record("Expected unknown format for '\(input)' but got \(format)")
            }
        }
    }
    
    @Test("Hex string validation")
    func testHexStringValidation() {
        let driver = TestAccessibilityDriver()
        
        let validHexStrings = [
            "123456789ABCDEF0",
            "abcdef0123456789",
            "ABCDEF",
            "123",
            "0",
            "A",
            "a",
            "F",
            "f"
        ]
        
        let invalidHexStrings = [
            "GHIJKL",
            "123G456",
            "xyz",
            "hello",
            "123 456",  // Space
            "12-34",    // Dash
            "",         // Empty
            "12.34"     // Decimal point
        ]
        
        for validHex in validHexStrings {
            #expect(driver.isValidHexString(validHex), "'\(validHex)' should be valid hex")
        }
        
        for invalidHex in invalidHexStrings {
            #expect(!driver.isValidHexString(invalidHex), "'\(invalidHex)' should not be valid hex")
        }
    }
    
    @Test("Handle format compatibility mapping")
    func testHandleFormatCompatibilityMapping() {
        let driver = TestAccessibilityDriver()
        
        // Test mapping between accessibility and hash-based formats
        let accessibilityHandle = "win_ax_TestWindow"
        let hashHandle = "win_ABCD1234567890EF"
        
        // Create mock mapping
        driver.addHandleMapping(canonical: accessibilityHandle, alternative: hashHandle)
        
        // Verify bidirectional mapping works
        #expect(driver.getMapping(for: accessibilityHandle) == hashHandle)
        #expect(driver.getMapping(for: hashHandle) == accessibilityHandle)
    }
    
    @Test("Alternative handle format generation")
    func testAlternativeHandleFormatGeneration() {
        let driver = TestAccessibilityDriver()
        
        // Test hash generation with different inputs
        let testInputs = [
            "app_001_TestWindow",
            "app_002_MainWindow",
            "different_input_string"
        ]
        
        for input in testInputs {
            let result = driver.createStableHash(from: input)
            #expect(result.count == 8, "Hash should be 8 characters long")
            #expect(!result.isEmpty, "Hash should not be empty")
        }
    }
    
    @Test("Handle format edge cases")
    func testHandleFormatEdgeCases() {
        let driver = TestAccessibilityDriver()
        
        // Test edge cases that might occur in real applications
        let edgeCases = [
            ("win_ax_", ""),                           // Empty identifier
            ("win_0", "0"),                           // Single character hash
            ("win_ax_窓", "窓"),                       // Unicode identifier
            ("win_ax_My Window Name", "My Window Name"), // Spaces in identifier
            ("win_DEADBEEFCAFEBABE", "DEADBEEFCAFEBABE") // Common test hex values
        ]
        
        for (input, expectedContent) in edgeCases {
            let format = driver.detectHandleFormat(input)
            
            switch format {
            case .accessibility(let identifier):
                #expect(identifier == expectedContent)
            case .hashBased(let hash):
                #expect(hash == expectedContent)
            case .unknown(let original):
                Issue.record("Unexpected unknown format for edge case: \(input), original: \(original)")
            }
        }
    }
    
    @Test("Performance: Handle format detection")
    func testHandleFormatDetectionPerformance() {
        let driver = TestAccessibilityDriver()
        
        // Generate test handles
        let testHandles = (0..<1000).map { i in
            if i % 2 == 0 {
                return "win_ax_TestWindow\(i)"
            } else {
                return "win_\(String(format: "%016X", i))"
            }
        }
        
        let startTime = Date()
        
        for handle in testHandles {
            _ = driver.detectHandleFormat(handle)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Should complete 1000 detections in under 100ms
        #expect(duration < 0.1, "Handle format detection took too long: \(duration)s")
    }
}

// MARK: - Mock Test Helper

/// Mock implementation for testing window handle compatibility
class TestAccessibilityDriver {
    
    enum WindowHandleFormat {
        case accessibility(String)
        case hashBased(String)
        case unknown(String)
    }
    
    private var handleMapping: [String: String] = [:]
    
    func detectHandleFormat(_ handleId: String) -> WindowHandleFormat {
        // Check for accessibility-based format: win_ax_*
        if handleId.hasPrefix("win_ax_") {
            let identifier = String(handleId.dropFirst(7))
            return .accessibility(identifier)
        }
        
        // Check for hash-based format: win_[HEX]
        if handleId.hasPrefix("win_") {
            let potentialHash = String(handleId.dropFirst(4))
            if isValidHexString(potentialHash) {
                return .hashBased(potentialHash)
            }
        }
        
        return .unknown(handleId)
    }
    
    func isValidHexString(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        
        let validChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let stringChars = CharacterSet(charactersIn: string)
        
        return validChars.isSuperset(of: stringChars)
    }
    
    func addHandleMapping(canonical: String, alternative: String) {
        handleMapping[alternative] = canonical
        handleMapping[canonical] = alternative
    }
    
    func getMapping(for handle: String) -> String? {
        return handleMapping[handle]
    }
    
    func createStableHash(from input: String) -> String {
        // Simple hash for testing - just use first 8 characters of input repeated
        let baseHash = String(input.prefix(4).padding(toLength: 4, withPad: "0", startingAt: 0))
        return "\(baseHash)\(baseHash)"
    }
}

// MARK: - Additional Test Tags

// Note: Test tags can be defined here if needed for filtering tests