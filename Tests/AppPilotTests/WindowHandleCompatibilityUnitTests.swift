import Testing
import Foundation
import CryptoKit
@testable import AppPilot

@Suite("Window Handle Compatibility Unit Tests")
struct WindowHandleCompatibilityUnitTests {
    
    // Test the handle format detection logic
    @Test("Handle format detection logic")
    func testHandleFormatDetection() async throws {
        // Test accessibility format detection directly
        let accessibilityId = "win_ax_SceneWindow"
        if accessibilityId.hasPrefix("win_ax_") {
            let identifier = String(accessibilityId.dropFirst(7))
            #expect(identifier == "SceneWindow")
        } else {
            throw PilotError.invalidArgument("Expected accessibility format")
        }
        
        // Test hash-based format detection
        let hashId = "win_9A5EACFE5572C654"
        if hashId.hasPrefix("win_") && hashId.count == 20 {
            let hash = String(hashId.dropFirst(4))
            if hash.allSatisfy({ $0.isHexDigit }) {
                #expect(hash == "9A5EACFE5572C654")
            } else {
                throw PilotError.invalidArgument("Expected valid hex hash")
            }
        } else {
            throw PilotError.invalidArgument("Expected hash format")
        }
        
        // Test unknown format detection
        let unknownId = "unknown_format_123"
        let isAccessibility = unknownId.hasPrefix("win_ax_")
        let isHash = unknownId.hasPrefix("win_") && unknownId.count == 20 && String(unknownId.dropFirst(4)).allSatisfy({ $0.isHexDigit })
        #expect(!isAccessibility && !isHash) // Should be neither
        
        print("✅ Handle format detection working correctly")
    }
    
    // Test hex digit detection
    @Test("Hex digit detection logic")
    func testHexDigitDetection() async throws {
        #expect("0".first!.isHexDigit == true)
        #expect("9".first!.isHexDigit == true)
        #expect("A".first!.isHexDigit == true)
        #expect("F".first!.isHexDigit == true)
        #expect("a".first!.isHexDigit == true)
        #expect("f".first!.isHexDigit == true)
        #expect("G".first!.isHexDigit == false)
        #expect("Z".first!.isHexDigit == false)
        #expect("!".first!.isHexDigit == false)
        
        // Test full hex string
        let hexString = "9A5EACFE5572C654"
        #expect(hexString.allSatisfy { $0.isHexDigit })
        
        let nonHexString = "9A5EACFE5572C65G"
        #expect(!nonHexString.allSatisfy { $0.isHexDigit })
        
        print("✅ Hex digit detection working correctly")
    }
    
    // Test that WindowHandle creation works with different formats
    @Test("WindowHandle creation with different formats")
    func testWindowHandleCreation() async throws {
        // Test accessibility-based handle
        let accessibilityHandle = WindowHandle(id: "win_ax_SceneWindow")
        #expect(accessibilityHandle.id == "win_ax_SceneWindow")
        
        // Test hash-based handle  
        let hashHandle = WindowHandle(id: "win_9A5EACFE5572C654")
        #expect(hashHandle.id == "win_9A5EACFE5572C654")
        
        // Test that handles are Hashable (can be used as dictionary keys)
        var handleDict: [WindowHandle: String] = [:]
        handleDict[accessibilityHandle] = "accessibility"
        handleDict[hashHandle] = "hash"
        
        #expect(handleDict[accessibilityHandle] == "accessibility")
        #expect(handleDict[hashHandle] == "hash")
        
        print("✅ WindowHandle creation working correctly")
    }
    
    // Test stable hash creation
    @Test("Stable hash creation consistency")
    func testStableHashCreation() async throws {
        // Test that the same input produces the same hash
        let input1 = "app_0001_TestWindow_100_200_800_600"
        let hash1 = createStableHash(from: input1)
        let hash2 = createStableHash(from: input1)
        
        #expect(hash1 == hash2)
        #expect(hash1.count == 16) // Should be 16 hex characters
        #expect(hash1.allSatisfy { $0.isHexDigit })
        
        // Test that different inputs produce different hashes
        let input2 = "app_0001_TestWindow_100_200_800_601" // Slightly different
        let hash3 = createStableHash(from: input2)
        
        #expect(hash1 != hash3)
        
        print("✅ Stable hash creation working correctly")
        print("   Sample hash: \(hash1)")
    }
    
    // Helper function for testing hash creation
    private func createStableHash(from input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        
        let hashBytes = digest.prefix(8)
        let hexString = hashBytes.map { String(format: "%02X", $0) }.joined()
        
        return hexString
    }
}