import Testing
import Foundation
@testable import AppPilot

@Suite("Keyboard Input Tests (KB)")
struct KeyboardInputTests {
    private let config = TestConfiguration(verboseLogging: true)
    private let client = TestAppClient()
    private let discovery = TestAppDiscovery(config: TestConfiguration())
    
    // Test cases as defined in specification
    private let keyboardTestCases = [
        KeyboardTestCase(testId: "KB-01", input: "Hello123", expectedAccuracy: 1.0, description: "Basic alphanumeric characters"),
        KeyboardTestCase(testId: "KB-02", input: "こんにちは世界", expectedAccuracy: 0.98, description: "Unicode characters (Japanese)"),
        KeyboardTestCase(testId: "KB-03", input: "Line1\nLine2\tTabbed", expectedAccuracy: 0.95, description: "Control characters with newline and tab")
    ]
    
    @Test("KB-01: Basic alphanumeric text input - perfect match required",
          .tags(.integration, .keyboard))
    func testBasicAlphanumericInput() async throws {
        try await performKeyboardTest(keyboardTestCases[0])
    }
    
    @Test("KB-02: Japanese Unicode text input - 98% accuracy required",
          .tags(.integration, .keyboard, .unicode))
    func testJapaneseUnicodeInput() async throws {
        try await performKeyboardTest(keyboardTestCases[1])
    }
    
    @Test("KB-03: Control characters - 95% accuracy required",
          .tags(.integration, .keyboard, .controlChars))
    func testControlCharacters() async throws {
        try await performKeyboardTest(keyboardTestCases[2])
    }
    
    
    @Test("KB-Route: Keyboard input route selection",
          .tags(.integration, .routing))
    func testKeyboardInputRouteSelection() async throws {
        // Test different route selection scenarios for keyboard input
        
        // Test 1: With AX available (should prefer AX for text input)
        let mockAccessibilityDriver = MockAccessibilityDriver()
        await mockAccessibilityDriver.setCanPerform(true)
        
        let pilot1 = AppPilot(
            appleEventDriver: MockAppleEventDriver(),
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: MockUIEventDriver(),
            screenDriver: MockScreenDriver(),
            missionControlDriver: MockMissionControlDriver()
        )
        
        let mockWindow = Window(
            id: WindowID(id: 100),
            title: "TestApp",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        let result1 = try await pilot1.type(
            text: "AX Route Test",
            into: mockWindow.id,
            policy: .STAY_HIDDEN
        )
        
        print("Type with AX available: \(result1.route)")
        #expect(result1.route == .AX_ACTION, "Should use AX_ACTION route when available for text input")
        
        // Test 2: With AX disabled (should fallback to UI_EVENT)
        await mockAccessibilityDriver.setCanPerform(false)
        
        let result2 = try await pilot1.type(
            text: "UI Route Test",
            into: mockWindow.id,
            policy: .STAY_HIDDEN
        )
        
        print("Type with AX disabled: \(result2.route)")
        #expect(result2.route == .UI_EVENT, "Should fallback to UI_EVENT when AX is unavailable")
    }
    
    @Test("KB-Special: Special characters and symbols",
          .tags(.integration, .keyboard, .specialChars))
    func testSpecialCharactersInput() async throws {
        let specialCases = [
            ("Symbols", "!@#$%^&*()_+-=[]{}|;':\",./<>?"),
            ("Mixed", "Test123!@# こんにちは\nNew line"),
            ("Escape sequences", "Line1\\nLine2\\tTab\\rReturn")
        ]
        
        let pilot = AppPilot()
        try await client.resetState()
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        let testWindow = readinessInfo.window
        
        for (testName, input) in specialCases {
            print("Testing special characters: \(testName)")
            
            let startTime = Date()
            let result = try await pilot.type(
                text: input,
                into: testWindow.id,
                policy: .STAY_HIDDEN
            )
            let duration = Date().timeIntervalSince(startTime)
            
            print("  Result: \(result.success) in \(String(format: "%.3f", duration * 1000))ms")
            #expect(result.success, "Special character input should succeed for \(testName)")
            
            // Wait for TestApp to process
            try await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Verify with TestApp API
            if let keyboardTest = try await client.waitForKeyboardTest(testName: testName, timeout: 2.0) {
                print("  TestApp accuracy: \(String(format: "%.1f", keyboardTest.accuracy * 100))%")
                #expect(keyboardTest.accuracy >= 0.90, "Special character accuracy should be >= 90% for \(testName)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performKeyboardTest(_ testCase: KeyboardTestCase) async throws {
        let pilot = AppPilot()
        
        // Setup
        try await client.resetState()
        let sessionId = try await client.startSession()
        print("Started keyboard test session: \(sessionId)")
        
        // Discover TestApp
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        #expect(readinessInfo.isReady, "TestApp should be ready")
        
        let testWindow = readinessInfo.window
        
        print("Executing \(testCase.testId): \(testCase.description)")
        print("Input text: \"\(testCase.input.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\t", with: "\\t"))\"")
        
        let startTime = Date()
        
        // Execute keyboard input with STAY_HIDDEN policy (as per specification)
        let result = try await pilot.type(
            text: testCase.input,
            into: testWindow.id,
            policy: .STAY_HIDDEN
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        print("Type operation: \(result.success ? "SUCCESS" : "FAILED") via \(result.route) in \(String(format: "%.3f", duration * 1000))ms")
        #expect(result.success, "Type operation should succeed")
        
        // Wait for TestApp to process the input
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Verify the result through TestApp API
        if let keyboardTest = try await client.waitForKeyboardTest(testName: testCase.testId, timeout: 5.0) {
            print("TestApp verification:")
            print("  Expected: \"\(keyboardTest.expectedText)\"")
            print("  Actual: \"\(keyboardTest.actualText)\"")
            print("  Matches: \(keyboardTest.matches)")
            print("  Accuracy: \(String(format: "%.1f", keyboardTest.accuracy * 100))%")
            
            // Verify accuracy meets requirements
            #expect(keyboardTest.accuracy >= testCase.expectedAccuracy, 
                   "Accuracy \(String(format: "%.1f", keyboardTest.accuracy * 100))% should be >= \(String(format: "%.1f", testCase.expectedAccuracy * 100))%")
            
            // For KB-01 (basic text), require perfect match
            if testCase.testId == "KB-01" {
                #expect(keyboardTest.matches, "Basic alphanumeric text should match perfectly")
            }
            
        } else {
            throw TestAppError.keyboardTestNotFound(testCase.testId)
        }
        
        // End session and verify overall stats
        let session = try await client.endSession()
        print("Session completed with overall success rate: \(String(format: "%.1f", session.successRate * 100))%")
        
        #expect(session.successRate >= config.successRateThreshold, 
               "Session success rate should meet threshold")
    }
}

// MARK: - Test Case Model

private struct KeyboardTestCase {
    let testId: String
    let input: String
    let expectedAccuracy: Double
    let description: String
}
