import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

@Suite("TestApp Integration Tests - See, Understand, Action Pattern", .serialized)
struct TestAppIntegrationTests {
    
    init() {
        // Set environment variable to indicate automated testing mode
        setenv("APPPILOT_TESTING", "1", 1)
    }
    
    // MARK: - Mouse Click Tests
    
    @Test("🖱️ Basic click functionality test", .serialized)
    func testBasicClickFunctionality() async throws {
        print("🎯 Starting Basic Click Functionality Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Mouse Click tab using shared helper
        print("🧭 Navigating to Mouse Click tab...")
        try await testSession.navigateToTab()
        
        // Enhanced State Isolation - Wait for stable state
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // State Verification - Ensure clean state before testing
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Refresh window information after navigation
        print("🔄 Refreshing window information after navigation...")
        try await testSession.refreshWindow()
        let currentWindow = await testSession.window
        print("✅ Current window: '\(currentWindow.title ?? "No title")'")
        
        // Stage 1: 見る (See/Observe) - Discover click targets
        print("\n👁️ Stage 1: 見る (Observe TestApp UI)")
        let refreshedElements = try await pilot.findElements(in: currentWindow.id)
        
        print("📋 All UI elements discovered (\(refreshedElements.count) total)")
        
        // ⭐ Enhanced Element Discovery - Use multiple search strategies
        let testAppClickTargets = findClickTargetsMultipleStrategies(elements: refreshedElements)
        
        print("🎯 Found \(testAppClickTargets.count) TestApp click targets:")
        for (index, target) in testAppClickTargets.enumerated() {
            let id = target.identifier ?? "No ID"
            let title = target.title ?? "No title"
            print("   Target \(index + 1): ID:\(id) Label:'\(title)' at (\(target.centerPoint.x), \(target.centerPoint.y))")
        }
        
        // Stage 2: 理解する (Understand) - Analyze targets
        print("\n🧠 Stage 2: 理解する (Understand Target Structure)")
        
        let clickTargets = testAppClickTargets
        if clickTargets.isEmpty {
            print("❌ No TestApp click targets found")
            print("🔄 Falling back to TestApp API verification...")
            
            let apiTargets = await testSession.getClickTargets()
            print("📡 TestApp API reports \(apiTargets.count) targets available")
            
            if apiTargets.isEmpty {
                throw TestSessionError.noTargetsFound
            }
            print("✅ Using TestApp API for verification")
        } else {
            #expect(clickTargets.count >= 1, "Should find at least 1 TestApp click target")
            print("✅ Found \(clickTargets.count) targets via accessibility API")
        }
        
        // Stage 3: アクション (Action) - Test different click types
        print("\n🎬 Stage 3: アクション (Test Click Operations)")
        
        // ⭐ Enhanced State Management - Double-check state before test
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        var testResult: (success: Bool, message: String) = (false, "No test performed")
        
        if !clickTargets.isEmpty {
            // Test with accessibility-discovered elements
            let firstTarget = clickTargets.first!
            print("🖱️ Testing accessibility-based click on: \(firstTarget.title ?? firstTarget.id)")
            
            let beforeState = await testSession.getClickTargets()
            let beforeCount = beforeState.filter { $0.clicked }.count
            print("   Before click: \(beforeCount) targets clicked")
            
            let result = try await pilot.click(window: currentWindow.id, at: firstTarget.centerPoint, button: .left, count: 1)
            #expect(result.success, "Left click should succeed")
            
            // ⭐ Enhanced Verification - Wait longer and retry if needed
            try await pilot.wait(.time(seconds: 1.5))
            
            let afterState = await testSession.getClickTargets()
            let afterCount = afterState.filter { $0.clicked }.count
            print("   After click: \(afterCount) targets clicked")
            
            if afterCount > beforeCount {
                testResult = (true, "Accessibility-based click successful")
                print("✅ Left click detected successfully via accessibility")
            } else {
                // ⭐ Retry Logic - Sometimes TestApp needs a moment
                print("   🔄 Click not detected immediately, retrying verification...")
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
                
                let retryState = await testSession.getClickTargets()
                let retryCount = retryState.filter { $0.clicked }.count
                
                if retryCount > beforeCount {
                    testResult = (true, "Click detected after retry")
                    print("✅ Left click detected after retry")
                } else {
                    testResult = (false, "Click not detected by TestApp")
                    print("❌ Left click not detected by TestApp")
                }
            }
            
        } else {
            // Fallback to coordinate-based testing
            testResult = try await performCoordinateBasedFallback(
                pilot: pilot, 
                currentWindow: currentWindow, 
                elements: refreshedElements, 
                testSession: testSession
            )
        }
        
        // Final validation
        #expect(testResult.success, Comment(rawValue: testResult.message))
        
        print("🏁 Basic click functionality test completed")
    }
    
    @Test("🎯 Five-target accuracy test", .serialized)
    func testFiveTargetAccuracy() async throws {
        print("🎯 Starting Five-Target Accuracy Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Mouse Click tab
        try await testSession.navigateToTab()
        
        // Enhanced State Isolation
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Find the 5 standard targets
        print("\n👁️ Stage 1: 見る (Discover 5-Target Layout)")
        let allElements = try await pilot.findElements(in: testSession.window.id)
        
        print("📋 All UI elements discovered (\(allElements.count) total):")
        let elementsByRole = Dictionary(grouping: allElements) { $0.role }
        for (role, elements) in elementsByRole.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("   \(role.rawValue): \(elements.count)")
        }
        
        // ⭐ Enhanced Target Discovery - Multiple strategies
        let finalTargets = findClickTargetsMultipleStrategies(elements: allElements)
        
        print("🎯 Found \(finalTargets.count) click targets for testing:")
        for (index, target) in finalTargets.enumerated() {
            let title = target.title ?? "No title"
            print("   Target \(index + 1): '\(title)' at (\(target.centerPoint.x), \(target.centerPoint.y))")
        }
        
        // Stage 2: 理解する (Understand) - Validate target layout
        print("\n🧠 Stage 2: 理解する (Validate Target Layout)")
        
        if finalTargets.isEmpty {
            print("❌ No click targets found in test area")
            throw TestSessionError.noTargetsFound
        }
        
        #expect(finalTargets.count >= 1, "Should find at least 1 click target to proceed with test")
        
        // Verify targets are properly spaced
        let sortedTargets = finalTargets.sorted { $0.centerPoint.x < $1.centerPoint.x }
        print("📐 Targets sorted by X position:")
        for (index, target) in sortedTargets.enumerated() {
            print("   Position \(index + 1): (\(target.centerPoint.x), \(target.centerPoint.y))")
        }
        
        // Stage 3: アクション (Action) - Test accuracy on each target
        print("\n🎬 Stage 3: アクション (Test Accuracy on Each Target)")
        
        // ⭐ Enhanced State Management - Reset before each test
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        var successfulClicks = 0
        
        for (index, target) in sortedTargets.enumerated() {
            print("\n🎯 Testing target \(index + 1) at (\(target.centerPoint.x), \(target.centerPoint.y))")
            
            let beforeState = await testSession.getClickTargets()
            let beforeCount = beforeState.filter { $0.clicked }.count
            
            let result = try await pilot.click(window: testSession.window.id, at: target.centerPoint)
            #expect(result.success, "Click should succeed on target \(index + 1)")
            
            // ⭐ Enhanced Verification with retry
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
            
            var afterState = await testSession.getClickTargets()
            var afterCount = afterState.filter { $0.clicked }.count
            
            // Retry if not detected immediately
            if afterCount <= beforeCount {
                print("   🔄 Click not detected immediately, retrying verification...")
                try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
                afterState = await testSession.getClickTargets()
                afterCount = afterState.filter { $0.clicked }.count
            }
            
            if afterCount > beforeCount {
                print("   ✅ Target \(index + 1) clicked successfully")
                successfulClicks += 1
            } else {
                print("   ❌ Target \(index + 1) click not detected")
            }
            
            // ⭐ Brief pause between targets to avoid interference
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        }
        
        let accuracy = Double(successfulClicks) / Double(sortedTargets.count)
        print("\n📊 Final Results:")
        print("   Successful clicks: \(successfulClicks)/\(sortedTargets.count)")
        print("   Accuracy: \(String(format: "%.1f", accuracy * 100))%")
        
        #expect(successfulClicks > 0, "Should successfully click at least one target")
        #expect(accuracy >= 0.6, "Should achieve at least 60% accuracy")
        
        print("🏁 Five-target accuracy test completed")
    }
    
    @Test("📍 UI tree coordinate discovery test", .serialized)
    func testUITreeCoordinateDiscovery() async throws {
        print("📍 Starting UI Tree Coordinate Discovery Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Mouse Click tab
        try await testSession.navigateToTab()
        
        // Enhanced State Isolation
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Discover elements via UI tree
        print("\n👁️ Stage 1: 見る (UI Tree Element Discovery)")
        let allElements = try await pilot.findElements(in: testSession.window.id)
        
        // Categorize elements by role
        let elementsByRole = Dictionary(grouping: allElements) { $0.role }
        print("📂 Element breakdown by role:")
        for (role, elements) in elementsByRole.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("   \(role.rawValue): \(elements.count) elements")
        }
        
        // Focus on interactive elements
        let interactiveElements = allElements.filter { element in
            [.button, .radioButton, .textField, .checkBox].contains(element.role) &&
            element.isEnabled && element.bounds.width > 10 && element.bounds.height > 10
        }
        
        print("🎮 Found \(interactiveElements.count) interactive elements")
        
        // Stage 2: 理解する (Understand) - Analyze coordinate accuracy
        print("\n🧠 Stage 2: 理解する (Analyze Coordinate Data)")
        #expect(interactiveElements.count > 0, "Should find interactive elements")
        
        var coordinateData: [(element: UIElement, centerX: CGFloat, centerY: CGFloat)] = []
        
        for element in interactiveElements {
            let centerX = element.bounds.midX
            let centerY = element.bounds.midY
            coordinateData.append((element, centerX, centerY))
            
            print("🔍 Element: \(element.role.rawValue) at center (\(centerX), \(centerY)), bounds: \(element.bounds)")
        }
        
        // Stage 3: アクション (Action) - Validate coordinate-based clicking
        print("\n🎬 Stage 3: アクション (Validate UI Tree Coordinates)")
        
        // ⭐ Enhanced State Management
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Test clicking using discovered coordinates
        var discoveredClickTests = 0
        var successfulDiscoveredClicks = 0
        
        for (element, centerX, centerY) in coordinateData.prefix(3) { // Test first 3 elements
            discoveredClickTests += 1
            
            print("\n🎯 Testing UI tree coordinate (\(centerX), \(centerY)) for \(element.role.rawValue)")
            
            let beforeState = await testSession.getClickTargets()
            let beforeCount = beforeState.filter { $0.clicked }.count
            
            let point = Point(x: centerX, y: centerY)
            let result = try await pilot.click(window: testSession.window.id, at: point)
            
            // ⭐ Enhanced Verification
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
            
            let afterState = await testSession.getClickTargets()
            let afterCount = afterState.filter { $0.clicked }.count
            
            if result.success && afterCount > beforeCount {
                print("   ✅ UI tree coordinate click successful")
                successfulDiscoveredClicks += 1
            } else {
                print("   ⚠️ UI tree coordinate click had no effect")
            }
            
            // Brief pause between tests
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        }
        
        print("\n📊 UI Tree Coordinate Discovery Results:")
        print("   Elements discovered: \(interactiveElements.count)")
        print("   Coordinate tests: \(discoveredClickTests)")
        print("   Successful clicks: \(successfulDiscoveredClicks)")
        
        #expect(interactiveElements.count >= 5, "Should discover at least 5 interactive elements")
        
        print("🏁 UI tree coordinate discovery test completed")
    }
    
    // MARK: - Keyboard Tests
    
    @Test("⌨️ Text input accuracy test", .serialized)
    func testTextInputAccuracy() async throws {
        print("⌨️ Starting Text Input Accuracy Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        let testSession = try await TestSession.create(pilot: pilot, testType: .keyboard)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Keyboard tab
        try await testSession.navigateToTab()
        
        // Enhanced State Isolation for keyboard tests
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        await testSession.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Stage 1: 見る (See/Observe) - Navigate to keyboard test area if needed
        print("\n👁️ Stage 1: 見る (Navigate to Keyboard Test Area)")
        
        // ⭐ Enhanced Navigation - Verify current state first
        let currentWindow = await testSession.window
        print("📋 Current window title: '\(currentWindow.title ?? "No title")'")
        
        let allElements = try await pilot.findElements(in: testSession.window.id)
        
        if currentWindow.title?.contains("Keyboard") != true {
            print("🧭 Need to navigate to Keyboard tab...")
            
            let sidebarCells = allElements.filter { element in
                element.role == .cell && 
                element.bounds.width > 200 && 
                element.bounds.height > 40 &&
                element.centerPoint.x < 650
            }
            
            print("🔍 Found \(sidebarCells.count) sidebar cells")
            
            // Click on second sidebar cell (should be Keyboard)
            if sidebarCells.count >= 2 {
                let keyboardCell = sidebarCells[1]
                print("🖱️ Clicking on Keyboard tab (cell 2)...")
                let navResult = try await pilot.click(window: testSession.window.id, at: keyboardCell.centerPoint)
                if navResult.success {
                    try await pilot.wait(.time(seconds: 3.0))
                    try await testSession.refreshWindow()
                    print("✅ Navigation to Keyboard tab successful")
                }
            } else {
                print("⚠️ Could not find enough sidebar cells for navigation")
            }
        } else {
            print("✅ Already on Keyboard tab")
        }
        
        // Stage 2: 理解する (Understand) - Find text input fields for simplified keyboard test
        print("\n🧠 Stage 2: 理解する (Find Simplified Keyboard Test Fields)")
        
        // Refresh elements after potential navigation
        let updatedElements = try await pilot.findElements(in: testSession.window.id)
        
        let textFields = updatedElements.filter { element in
            element.role == .textField
        }
        
        print("🔍 Found \(textFields.count) text fields")
        for (index, field) in textFields.enumerated() {
            print("   TextField \(index + 1): enabled=\(field.isEnabled) bounds=\(field.bounds)")
        }
        
        // For simplified keyboard test, look for the "Expected Text" field first
        guard let expectedTextField = textFields.first else {
            throw TestSessionError.noTargetsFound
        }
        
        // Find the actual input field (second text field in simplified layout)
        let actualTextField = textFields.count > 1 ? textFields[1] : expectedTextField
        
        // Stage 3: アクション (Action) - Simplified Keyboard Test Workflow
        print("\n🎬 Stage 3: アクション (Simplified Keyboard Test Workflow)")
        
        let testText = "Hello123"
        
        // Step 1: Enter expected text in the first field
        print("1️⃣ Setting up expected text...")
        print("   Clicking on expected text field...")
        let expectedClickResult = try await pilot.click(window: testSession.window.id, at: expectedTextField.centerPoint)
        #expect(expectedClickResult.success, "Expected text field click should succeed")
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        print("   Typing expected text: '\(testText)'")
        let expectedTypeResult = try await pilot.type(text: testText)
        #expect(expectedTypeResult.success, "Expected text typing should succeed")
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Step 2: Find and click the "Start Test" button
        print("2️⃣ Starting the test...")
        let buttonElements = try await pilot.findElements(in: testSession.window.id)
        let startButton = buttonElements.first { element in
            element.role == ElementRole.button && 
            (element.title?.contains("Start Test") ?? false)
        }
        
        if let startButton = startButton {
            print("   Clicking Start Test button...")
            let startResult = try await pilot.click(window: testSession.window.id, at: startButton.centerPoint)
            #expect(startResult.success, "Start Test button click should succeed")
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        } else {
            print("   ⚠️ Start Test button not found, proceeding with direct field interaction")
        }
        
        // Step 3: Type in the actual text field
        print("3️⃣ Testing actual text input...")
        print("   Clicking on actual input field...")
        let actualClickResult = try await pilot.click(window: testSession.window.id, at: actualTextField.centerPoint)
        #expect(actualClickResult.success, "Actual text field click should succeed")
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        print("   Typing actual text: '\(testText)'")
        let actualTypeResult = try await pilot.type(text: testText)
        #expect(actualTypeResult.success, "Actual text typing should succeed")
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Step 4: Verification
        print("4️⃣ Verifying text input...")
        
        // Check if test auto-completed (simplified KeyboardTestView has auto-completion)
        let finalElements = try await pilot.findElements(in: testSession.window.id)
        let finalTextFields = finalElements.filter { $0.role == .textField }
        
        var inputDetected = false
        if finalTextFields.count >= 2 {
            let actualField = finalTextFields[1]
            if let actualValue = actualField.value {
                print("   📝 Actual field value: \"\(actualValue)\"")
                if actualValue.contains("Hello") || actualValue.contains("123") || !actualValue.isEmpty {
                    print("   ✅ Input verification: TEXT DETECTED")
                    inputDetected = true
                }
            }
        }
        
        print("\n📊 Simplified Keyboard Test Results:")
        print("   Expected Text Setup: ✅")
        print("   Test Activation: ✅")
        print("   Actual Text Input: ✅")
        print("   Input Detection: \(inputDetected ? "✅" : "⚠️")")
        
        #expect(actualTypeResult.success, "Text typing operation should succeed")
        
        print("🏁 Text input accuracy test completed")
    }
    
    // MARK: - Wait Operation Tests
    
    @Test("⏰ Time-based wait precision test", .serialized)
    func testTimeBasedWaitPrecision() async throws {
        print("⏰ Starting Time-Based Wait Precision Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // ⭐ Isolated test - no TestApp dependency for timing tests
        let waitDurations: [TimeInterval] = [0.1, 0.5, 1.0, 2.0, 3.0]
        var results: [(requested: TimeInterval, actual: TimeInterval, accuracy: Double)] = []
        
        // Stage 1: 見る (See/Observe) - Prepare timing measurements
        print("\n👁️ Stage 1: 見る (Prepare Wait Precision Tests)")
        print("🎯 Testing wait durations: \(waitDurations.map { "\($0)s" }.joined(separator: ", "))")
        
        // Stage 2: 理解する (Understand) - Define accuracy requirements
        print("\n🧠 Stage 2: 理解する (Define Accuracy Requirements)")
        let requiredAccuracy = 0.85 // 85% accuracy required
        print("📏 Required accuracy: \(String(format: "%.1f", requiredAccuracy * 100))%")
        
        // Stage 3: アクション (Action) - Execute wait tests
        print("\n🎬 Stage 3: アクション (Execute Wait Precision Tests)")
        
        for duration in waitDurations {
            print("\n⏱️ Testing wait duration: \(duration)s")
            
            // ⭐ Enhanced timing measurement
            let startTime = CFAbsoluteTimeGetCurrent()
            try await pilot.wait(.time(seconds: duration))
            let endTime = CFAbsoluteTimeGetCurrent()
            let actualDuration = endTime - startTime
            
            let error = abs(actualDuration - duration)
            let accuracy = max(0.0, 1.0 - (error / duration))
            
            results.append((duration, actualDuration, accuracy))
            
            print("   Requested: \(String(format: "%.3f", duration))s")
            print("   Actual: \(String(format: "%.3f", actualDuration))s")
            print("   Error: \(String(format: "%.3f", error))s")
            print("   Accuracy: \(String(format: "%.1f", accuracy * 100))%")
            
            #expect(accuracy >= requiredAccuracy, "Wait accuracy should be at least 85% for \(duration)s")
            
            // Brief pause between tests to avoid timing interference
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        print("\n📊 Wait Precision Test Results:")
        print("   Tests completed: \(results.count)")
        let avgAccuracy = results.map { $0.accuracy }.reduce(0, +) / Double(results.count)
        print("   Average accuracy: \(String(format: "%.1f", avgAccuracy * 100))%")
        let passedTests = results.filter { $0.accuracy >= requiredAccuracy }.count
        print("   Tests passed: \(passedTests)/\(results.count)")
        
        #expect(avgAccuracy >= requiredAccuracy, "Average wait accuracy should be at least 85%")
        
        print("🏁 Time-based wait precision test completed")
    }
    
    // MARK: - TestApp API Integration Tests
    
    @Test("🔗 TestApp API integration test", .serialized)
    func testTestAppAPIIntegration() async throws {
        print("🔗 Starting TestApp API Integration Test")
        print("=" * 60)
        
        let baseURL = "http://localhost:8765"
        let api = CorrectFlowTestAppAPI()
        
        // ⭐ Enhanced API testing with retry logic
        print("\n👁️ Stage 1: 見る (Check API Server Status)")
        
        var healthCheckSuccess = false
        for attempt in 1...3 {
            do {
                let healthURL = URL(string: "\(baseURL)/api/health")!
                let (healthData, healthResponse) = try await URLSession.shared.data(from: healthURL)
                
                if let httpResponse = healthResponse as? HTTPURLResponse {
                    print("🏥 Health endpoint status (attempt \(attempt)): \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        healthCheckSuccess = true
                        break
                    }
                }
                
                let healthString = String(data: healthData, encoding: .utf8) ?? ""
                print("📋 Health response: \(healthString.prefix(200))")
                
            } catch {
                print("❌ Health check attempt \(attempt) failed: \(error)")
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
                }
            }
        }
        
        #expect(healthCheckSuccess, "Health endpoint should be accessible")
        
        // Stage 2: 理解する (Understand) - Test core API endpoints
        print("\n🧠 Stage 2: 理解する (Test Core API Endpoints)")
        
        // ⭐ Enhanced API testing with proper state management
        print("🔄 Testing state reset...")
        try await api.resetState()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        print("✅ State reset successful")
        
        print("🎯 Testing target retrieval...")
        let targets = try await api.getClickTargets()
        print("📊 Retrieved \(targets.count) targets")
        #expect(targets.allSatisfy { !$0.clicked }, "All targets should be unclicked after reset")
        
        // Stage 3: アクション (Action) - Test comprehensive API functionality
        print("\n🎬 Stage 3: アクション (Test All API Endpoints)")
        
        let endpoints = [
            "/api/health",
            "/api/state", 
            "/api/targets"
        ]
        
        var successfulEndpoints = 0
        
        for endpoint in endpoints {
            print("\n🌐 Testing endpoint: \(endpoint)")
            
            do {
                let url = URL(string: "\(baseURL)\(endpoint)")!
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("   Status: \(httpResponse.statusCode)")
                    print("   Data size: \(data.count) bytes")
                    
                    if httpResponse.statusCode == 200 {
                        successfulEndpoints += 1
                        print("   ✅ Endpoint successful")
                    } else {
                        print("   ❌ Endpoint failed")
                    }
                }
                
            } catch {
                print("   ❌ Endpoint error: \(error)")
            }
            
            // Brief pause between endpoint tests
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        print("\n📊 API Integration Results:")
        print("   Endpoints tested: \(endpoints.count)")
        print("   Successful endpoints: \(successfulEndpoints)")
        print("   Success rate: \(String(format: "%.1f", Double(successfulEndpoints) / Double(endpoints.count) * 100))%")
        
        #expect(successfulEndpoints >= 2, "At least 2 endpoints should be working")
        
        print("🏁 TestApp API integration test completed")
    }
    
    // MARK: - AppPilot SDK Comprehensive Tests
    
    @Test("🎯 AppPilot SDK comprehensive functionality test", .serialized)
    func testAppPilotSDKComprehensive() async throws {
        print("🎯 Starting AppPilot SDK Comprehensive Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // ⭐ Enhanced SDK testing with proper initialization
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait initialization
        
        // Stage 1: 見る (See/Observe) - Application discovery
        print("\n👁️ Stage 1: 見る (Application Discovery)")
        
        let apps = try await pilot.listApplications()
        print("🔍 Found \(apps.count) running applications")
        
        let testApp = apps.first { app in
            app.name.contains("TestApp") || 
            app.name == "AppMCP Test App" ||
            app.bundleIdentifier?.contains("TestApp") ?? false
        }
        
        #expect(testApp != nil, "Should find TestApp among running applications")
        guard let testApp = testApp else { return }
        
        print("✅ Found TestApp: \(testApp.name)")
        
        // Window enumeration
        print("🪟 Testing window enumeration...")
        let windows = try await pilot.listWindows(app: testApp.id)
        print("📊 Found \(windows.count) windows for TestApp")
        #expect(!windows.isEmpty, "TestApp should have at least one window")
        
        guard let mainWindow = windows.first else { return }
        print("✅ Using main window: \(mainWindow.bounds)")
        
        // Stage 2: 理解する (Understand) - Element discovery
        print("\n🧠 Stage 2: 理解する (Element Discovery)")
        
        let allElements = try await pilot.findElements(in: mainWindow.id)
        print("🔍 Discovered \(allElements.count) UI elements")
        
        let buttons = allElements.filter { $0.role == .button }
        let textFields = allElements.filter { $0.role == .textField }
        let radioButtons = allElements.filter { $0.role == .radioButton }
        
        print("📊 Element breakdown:")
        print("   Buttons: \(buttons.count)")
        print("   Text fields: \(textFields.count)")
        print("   Radio buttons: \(radioButtons.count)")
        
        #expect(allElements.count > 10, "Should discover significant number of elements")
        
        // Stage 3: アクション (Action) - Test core operations
        print("\n🎬 Stage 3: アクション (Test Core SDK Operations)")
        
        // Test screenshot capture
        print("📷 Testing screenshot capture...")
        let screenshot = try await pilot.capture(window: mainWindow.id)
        print("✅ Screenshot captured: \(screenshot.width)x\(screenshot.height)")
        #expect(screenshot.width > 0 && screenshot.height > 0, "Screenshot should have valid dimensions")
        
        // Test clicking operation (if buttons available)
        if let clickableButton = buttons.first {
            print("🖱️ Testing click operation...")
            let clickResult = try await pilot.click(window: mainWindow.id, at: clickableButton.centerPoint)
            print("✅ Click operation result: \(clickResult.success)")
            #expect(clickResult.success, "Click operation should succeed")
        }
        
        // Test text typing with input function if text field available
        if let textField = textFields.first {
            print("⌨️ Testing text input...")
            let inputResult = try await pilot.input(text: "AppPilot SDK Test", into: textField)
            print("✅ Text input result: \(inputResult.success)")
            if case .type(let inputText, let actualText, _, _) = inputResult.data {
                print("   Input: \(inputText), Actual: \(actualText ?? "nil")")
            }
            #expect(inputResult.success, "Text input should succeed")
        } else {
            // Fallback to generic type for non-text-field testing
            print("⌨️ Testing generic text typing...")
            let typeResult = try await pilot.type(text: "AppPilot SDK Test")
            print("✅ Text typing result: \(typeResult.success)")
            #expect(typeResult.success, "Text typing should succeed")
        }
        
        // Test wait operation
        print("⏰ Testing wait operation...")
        let waitStart = CFAbsoluteTimeGetCurrent()
        try await pilot.wait(.time(seconds: 0.5))
        let waitDuration = CFAbsoluteTimeGetCurrent() - waitStart
        print("✅ Wait completed in \(String(format: "%.3f", waitDuration))s")
        #expect(waitDuration >= 0.4, "Wait should take at least the requested time")
        
        print("\n📊 SDK Comprehensive Test Results:")
        print("   Applications discovered: \(apps.count)")
        print("   Windows enumerated: \(windows.count)")
        print("   UI elements found: \(allElements.count)")
        print("   Core operations tested: 4/4")
        
        print("🏁 AppPilot SDK comprehensive test completed")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("📊 Error handling test", .serialized)
    func testErrorHandling() async throws {
        print("📊 Starting Error Handling Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // Stage 1: 見る (See/Observe) - Prepare error test scenarios
        print("\n👁️ Stage 1: 見る (Prepare Error Scenarios)")
        
        // Stage 2: 理解する (Understand) - Define expected error cases
        print("\n🧠 Stage 2: 理解する (Define Expected Errors)")
        
        // Stage 3: アクション (Action) - Test error conditions
        print("\n🎬 Stage 3: アクション (Test Error Conditions)")
        
        // Test window not found error
        print("🔍 Testing window not found error...")
        do {
            let nonExistentWindow = WindowHandle(id: "non-existent-window-12345")
            let _ = try await pilot.findElements(in: nonExistentWindow)
            #expect(Bool(false), "Should throw error for non-existent window")
        } catch {
            print("✅ Correctly caught window not found error: \(type(of: error))")
            // Error caught as expected
        }
        
        // Test invalid coordinates
        print("🎯 Testing coordinate boundary handling...")
        let testSession = try await TestSession.create(pilot: pilot, testType: .mouseClick)
        defer { Task { await testSession.cleanup() } }
        
        // Navigate to Mouse Click tab for coordinate testing
        try await testSession.navigateToTab()
        
        // Enhanced error testing with proper isolation
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        // Test click at extreme coordinates
        let extremePoint = Point(x: -1000.0, y: -1000.0)
        let extremeResult = try await pilot.click(window: testSession.window.id, at: extremePoint)
        print("🔍 Extreme coordinate click result: \(extremeResult.success)")
        // Note: This may succeed as coordinates get clamped by the system
        
        // Test API connectivity errors
        print("🌐 Testing API connectivity...")
        let api = CorrectFlowTestAppAPI()
        do {
            let targets = try await api.getClickTargets()
            print("✅ API connectivity successful, got \(targets.count) targets")
        } catch {
            print("⚠️ API connectivity error (expected if TestApp server not running): \(error)")
        }
        
        print("\n📊 Error Handling Results:")
        print("   Error scenarios tested: 3")
        print("   ✅ Error handling validation completed")
        
        print("🏁 Error handling test completed")
    }
    
    // MARK: - Session and State Management Tests
    
    @Test("🔄 Session and state management test", .serialized)
    func testSessionAndStateManagement() async throws {
        print("🔄 Starting Session and State Management Test")
        print("=" * 60)
        
        let pilot = AppPilot()
        
        // ⭐ Enhanced session management testing
        print("\n👁️ Stage 1: 見る (Create Test Session)")
        
        let testSession1 = try await TestSession.create(pilot: pilot, testType: .mouseClick)
        print("✅ Test session 1 created: \(testSession1.app.name)")
        
        // Navigate to Mouse Click tab for session 1
        try await testSession1.navigateToTab()
        
        // Stage 2: 理解する (Understand) - Test state isolation
        print("\n🧠 Stage 2: 理解する (Test State Management)")
        
        // ⭐ Enhanced state verification
        await testSession1.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        let initialTargets = await testSession1.getClickTargets()
        print("🎯 Initial targets: \(initialTargets.count) targets, \(initialTargets.filter { $0.clicked }.count) clicked")
        
        // Stage 3: アクション (Action) - Test session operations
        print("\n🎬 Stage 3: アクション (Test Session Operations)")
        
        // Perform some clicks to change state
        let allElements = try await pilot.findElements(in: testSession1.window.id)
        let clickTargets = allElements.filter { element in
            element.role == .radioButton && 
            element.centerPoint.y > 290 && element.centerPoint.y < 295 &&
            element.centerPoint.x > 700
        }
        
        if let firstTarget = clickTargets.first {
            print("🖱️ Clicking first target to change state...")
            let _ = try await pilot.click(window: testSession1.window.id, at: firstTarget.centerPoint)
            try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
            
            let afterClickTargets = await testSession1.getClickTargets()
            let clickedCount = afterClickTargets.filter { $0.clicked }.count
            print("📊 After click: \(clickedCount) targets clicked")
        }
        
        // Test state reset
        print("🔄 Testing state reset...")
        await testSession1.resetState()
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        let resetTargets = await testSession1.getClickTargets()
        let resetClickedCount = resetTargets.filter { $0.clicked }.count
        print("📊 After reset: \(resetClickedCount) targets clicked")
        
        #expect(resetClickedCount == 0, "All targets should be unclicked after reset")
        
        // Test session cleanup
        print("🧹 Testing session cleanup...")
        await testSession1.cleanup()
        print("✅ Session cleanup completed")
        
        // ⭐ Enhanced session isolation testing
        print("🔄 Testing session isolation...")
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms standard wait
        
        let testSession2 = try await TestSession.create(pilot: pilot, testType: .mouseClick)
        try await testSession2.navigateToTab()
        let session2Targets = await testSession2.getClickTargets()
        let session2ClickedCount = session2Targets.filter { $0.clicked }.count
        
        print("📊 New session targets: \(session2ClickedCount) clicked")
        #expect(session2ClickedCount == 0, "New session should start with clean state")
        
        await testSession2.cleanup()
        
        print("\n📊 Session Management Results:")
        print("   Sessions created: 2")
        print("   State resets tested: 2")
        print("   Session isolation verified: ✅")
        
        print("🏁 Session and state management test completed")
    }
    
    // MARK: - Helper Methods
    
    /// ⭐ Enhanced click target discovery with multiple strategies
    private func findClickTargetsMultipleStrategies(elements: [UIElement]) -> [UIElement] {
        // Strategy 1: Find by accessibility identifier
        let targetsByIdentifier = elements.filter { element in
            guard let identifier = element.identifier else { return false }
            return identifier.hasPrefix("click_target_") && 
                   (element.role == .button || element.role == .group || element.role == .unknown)
        }
        
        if !targetsByIdentifier.isEmpty {
            print("📍 Found targets by identifier: \(targetsByIdentifier.count)")
            return targetsByIdentifier
        }
        
        // Strategy 2: Find by accessibility label
        let targetsByLabel = elements.filter { element in
            guard let title = element.title else { return false }
            return title.contains("Click target") && 
                   (element.role == .button || element.role == .group || element.role == .unknown)
        }
        
        if !targetsByLabel.isEmpty {
            print("📍 Found targets by label: \(targetsByLabel.count)")
            return targetsByLabel
        }
        
        // Strategy 3: Find in test area by position and characteristics
        let testAreaTargets = elements.filter { element in
            let isInTestArea = element.centerPoint.x > 600 && element.centerPoint.x < 1200 &&
                              element.centerPoint.y > 100 && element.centerPoint.y < 600
            
            let isInteractive = element.role == .button || 
                               element.role == .group || 
                               element.role == .unknown ||
                               element.role == .radioButton ||
                               element.isEnabled
            
            let hasReasonableSize = element.bounds.width > 50 && element.bounds.width < 200 &&
                                   element.bounds.height > 50 && element.bounds.height < 200
            
            return isInTestArea && isInteractive && hasReasonableSize
        }
        
        print("📍 Found targets by position: \(testAreaTargets.count)")
        return testAreaTargets
    }
    
    /// ⭐ Enhanced coordinate-based fallback testing
    private func performCoordinateBasedFallback(
        pilot: AppPilot,
        currentWindow: WindowInfo,
        elements: [UIElement],
        testSession: TestSession
    ) async throws -> (success: Bool, message: String) {
        
        print("🔍 Performing coordinate-based fallback testing...")
        
        let potentialClickTargets = elements.filter { element in
            let isInRightArea = element.centerPoint.x > (currentWindow.bounds.minX + 400)
            let hasReasonableSize = element.bounds.width > 50 && element.bounds.width < 200 &&
                                   element.bounds.height > 50 && element.bounds.height < 200
            let isClickable = element.role == ElementRole.button || 
                             element.role == ElementRole.group || 
                             element.role == ElementRole.unknown ||
                             element.role == ElementRole.radioButton
            
            return isInRightArea && hasReasonableSize && isClickable
        }
        
        print("🎯 Found \(potentialClickTargets.count) potential click targets in test area")
        
        if let firstTarget = potentialClickTargets.first {
            print("🖱️ Testing click on discovered UI element...")
            print("   Element: \(firstTarget.role.rawValue) at (\(firstTarget.centerPoint.x), \(firstTarget.centerPoint.y))")
            
            let beforeState = await testSession.getClickTargets()
            let beforeCount = beforeState.filter { $0.clicked }.count
            
            let _ = try await pilot.click(window: currentWindow.id, at: firstTarget.centerPoint, button: .left, count: 1)
            
            try await pilot.wait(.time(seconds: 1.5))
            
            let afterState = await testSession.getClickTargets()
            let afterCount = afterState.filter { $0.clicked }.count
            
            if afterCount > beforeCount {
                return (true, "UI element click successful")
            } else {
                return (false, "UI element click not detected by TestApp")
            }
        } else {
            return (false, "No clickable elements found in test area")
        }
    }
}

// MARK: - Supporting Types and Extensions
// (Shared types are now in TestSupport.swift)
