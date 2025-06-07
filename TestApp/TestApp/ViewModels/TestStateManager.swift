import Foundation
import SwiftUI
import AppKit

@MainActor
@Observable
class TestStateManager {
    var clickTargets: [ClickTargetState] = []
    var keyboardTestResults: [KeyboardTestResult] = []
    var waitTestResults: [WaitTestResult] = []
    var currentTestSession: TestSession?
    
    private var mouseEventMonitor: Any?
    private var testAreaFrame: CGRect = .zero
    private var testAreaWindowFrame: CGRect = .zero
    private var isMonitoringEnabled: Bool = false
    
    // External dependencies for result recording
    weak var testResultsManager: TestResultsManager?
    
    // MARK: - Data Structures for API
    
    struct ClickTargetState: Identifiable, Codable {
        let id: String
        let label: String
        let position: CGPoint
        var isClicked: Bool
        let clickedAt: Date?
        
        func toDictionary() -> [String: Any] {
            return [
                "id": id,
                "label": label,
                "position": ["x": position.x, "y": position.y],
                "clicked": isClicked,
                "clicked_at": clickedAt?.iso8601String ?? NSNull()
            ]
        }
    }
    
    struct KeyboardTestResult: Identifiable, Codable {
        let id = UUID()
        let testName: String
        let expectedText: String
        let actualText: String
        let matches: Bool
        let accuracy: Double
        let timestamp: Date
        let characterCount: Int
        let errorPositions: [Int]
        
        func toDictionary() -> [String: Any] {
            return [
                "id": id.uuidString,
                "test_name": testName,
                "expected_text": expectedText,
                "actual_text": actualText,
                "matches": matches,
                "accuracy": accuracy,
                "timestamp": timestamp.iso8601String,
                "character_count": characterCount,
                "error_positions": errorPositions
            ]
        }
    }
    
    struct WaitTestResult: Identifiable, Codable {
        let id = UUID()
        let condition: String
        let requestedDuration: TimeInterval
        let actualDuration: TimeInterval
        let accuracy: Double
        let success: Bool
        let timestamp: Date
        
        var accuracyPercentage: Double {
            return accuracy * 100
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "id": id.uuidString,
                "condition": condition,
                "requested_duration_ms": Int(requestedDuration * 1000),
                "actual_duration_ms": Int(actualDuration * 1000),
                "accuracy": accuracy,
                "accuracy_percentage": accuracyPercentage,
                "success": success,
                "timestamp": timestamp.iso8601String
            ]
        }
    }
    
    struct TestSession: Codable {
        let id = UUID()
        let startTime: Date
        var endTime: Date?
        var totalTests: Int = 0
        var successfulTests: Int = 0
        var failedTests: Int = 0
        
        var isActive: Bool {
            return endTime == nil
        }
        
        var successRate: Double {
            guard totalTests > 0 else { return 0.0 }
            return Double(successfulTests) / Double(totalTests)
        }
        
        var duration: TimeInterval {
            let end = endTime ?? Date()
            return end.timeIntervalSince(startTime)
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "id": id.uuidString,
                "start_time": startTime.iso8601String,
                "end_time": endTime?.iso8601String ?? NSNull(),
                "total_tests": totalTests,
                "successful_tests": successfulTests,
                "failed_tests": failedTests,
                "success_rate": successRate,
                "duration_seconds": duration,
                "is_active": isActive
            ]
        }
    }
    
    // MARK: - Mouse Event Monitoring
    
    func startMouseEventMonitoring(testAreaFrame: CGRect, windowFrame: CGRect) {
        print("🖱️ Starting mouse event monitoring...")
        self.testAreaFrame = testAreaFrame
        self.testAreaWindowFrame = windowFrame
        self.isMonitoringEnabled = true
        
        stopMouseEventMonitoring() // Stop any existing monitor
        
        // Monitor mouse clicks using NSEvent - both global and local monitors
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleGlobalMouseClick(event: event)
        }
        
        // Also add local monitor for events within our app
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleGlobalMouseClick(event: event)
            return event
        }
        
        print("✅ Mouse event monitoring started")
        print("   Test area frame: \(testAreaFrame)")
        print("   Window frame: \(windowFrame)")
        print("   Monitor ID: \(String(describing: mouseEventMonitor))")
    }
    
    func stopMouseEventMonitoring() {
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
            isMonitoringEnabled = false
            print("🛑 Mouse event monitoring stopped")
        }
    }
    
    private func handleGlobalMouseClick(event: NSEvent) {
        guard isMonitoringEnabled else { return }
        
        let screenLocation = NSEvent.mouseLocation
        
        print("🖱️ Global mouse click detected:")
        print("   Screen location: (\(screenLocation.x), \(screenLocation.y))")
        print("   Event type: \(event.type.rawValue)")
        
        // Convert screen coordinates to test area coordinates
        if let testAreaLocation = convertScreenToTestArea(screenLocation: screenLocation) {
            // Create bounds for test area with some tolerance
            let testAreaBounds = CGRect(
                x: -10, // Allow slight negative coordinates
                y: -10,
                width: 420, // testAreaSize (400) + tolerance
                height: 420
            )
            
            print("   Test area bounds: \(testAreaBounds)")
            print("   Click in bounds: \(testAreaBounds.contains(testAreaLocation))")
            
            // Check if click is within our test area (with tolerance)
            if testAreaBounds.contains(testAreaLocation) {
                print("✅ Click is within test area bounds, processing...")
                handleExternalClick(at: testAreaLocation, button: getMouseButton(from: event))
            } else {
                print("ℹ️ Click is outside test area bounds")
                print("   Distance from center: \(distanceFromTestAreaCenter(testAreaLocation))")
            }
        } else {
            print("❌ Failed to convert screen coordinates to test area coordinates")
        }
    }
    
    private func convertScreenToTestArea(screenLocation: CGPoint) -> CGPoint? {
        // macOS screen coordinates: origin at bottom-left
        // SwiftUI coordinates: origin at top-left
        // Need to account for window frame and test area offset
        
        // Get screen height for Y coordinate flipping
        guard let screen = NSScreen.main else { return nil }
        let screenHeight = screen.frame.height
        
        // Convert screen coordinates (bottom-left origin) to window coordinates (top-left origin)
        let windowX = screenLocation.x - testAreaWindowFrame.minX
        let windowY = screenHeight - screenLocation.y - testAreaWindowFrame.minY
        
        // Convert window coordinates to test area coordinates
        let testAreaX = windowX - testAreaFrame.minX
        let testAreaY = windowY - testAreaFrame.minY
        
        print("🔄 Coordinate conversion:")
        print("   Screen: (\(String(format: "%.1f", screenLocation.x)), \(String(format: "%.1f", screenLocation.y)))")
        print("   Screen height: \(String(format: "%.1f", screenHeight))")
        print("   Window frame: \(testAreaWindowFrame)")
        print("   Test area frame: \(testAreaFrame)")
        print("   Window coords: (\(String(format: "%.1f", windowX)), \(String(format: "%.1f", windowY)))")
        print("   Test area coords: (\(String(format: "%.1f", testAreaX)), \(String(format: "%.1f", testAreaY)))")
        
        return CGPoint(x: testAreaX, y: testAreaY)
    }
    
    private func distanceFromTestAreaCenter(_ point: CGPoint) -> Double {
        let centerX = 200.0 // testAreaSize / 2
        let centerY = 200.0
        let deltaX = point.x - centerX
        let deltaY = point.y - centerY
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    private func getMouseButton(from event: NSEvent) -> MouseButton {
        switch event.type {
        case .leftMouseDown:
            return .left
        case .rightMouseDown:
            return .right
        case .otherMouseDown:
            return .center
        default:
            return .left
        }
    }
    
    private func handleExternalClick(at location: CGPoint, button: MouseButton) {
        print("🎯 Processing external click at (\(location.x), \(location.y)) with \(button.rawValue) button")
        
        // List all targets and their distances for debugging
        print("📍 Available targets:")
        for target in clickTargets {
            let distance = sqrt(pow(target.position.x - location.x, 2) + pow(target.position.y - location.y, 2))
            print("   \(target.id) (\(target.label)): (\(target.position.x), \(target.position.y)) - distance: \(String(format: "%.1f", distance))")
        }
        
        // Check if click hits any target with multiple tolerance levels
        let tolerances: [CGFloat] = [25.0, 50.0, 75.0, 100.0]
        var foundTarget: ClickTargetState?
        var usedTolerance: CGFloat = 0
        
        for tolerance in tolerances {
            if let target = getClickTarget(near: location, tolerance: tolerance) {
                foundTarget = target
                usedTolerance = tolerance
                break
            }
        }
        
        if let target = foundTarget {
            print("✅ External click hit target: \(target.id) with tolerance \(usedTolerance)")
            markTargetClicked(id: target.id)
            
            // Record successful external click if TestResultsManager is available
            Task { @MainActor in
                if let resultsManager = testResultsManager {
                    let result = TestResult(
                        testType: .mouseClick,
                        success: true,
                        details: "External click hit \(target.label) target with \(button.rawValue.lowercased()) button (tolerance: \(usedTolerance))",
                        coordinates: location
                    )
                    resultsManager.addResult(result)
                    print("📝 Recorded successful external click result")
                }
            }
        } else {
            print("❌ External click missed all targets (tried tolerances: \(tolerances))")
            
            // Show closest target for debugging
            if let closestTarget = clickTargets.min(by: { target1, target2 in
                let dist1 = sqrt(pow(target1.position.x - location.x, 2) + pow(target1.position.y - location.y, 2))
                let dist2 = sqrt(pow(target2.position.x - location.x, 2) + pow(target2.position.y - location.y, 2))
                return dist1 < dist2
            }) {
                let closestDistance = sqrt(pow(closestTarget.position.x - location.x, 2) + pow(closestTarget.position.y - location.y, 2))
                print("   Closest target: \(closestTarget.id) at distance \(String(format: "%.1f", closestDistance))")
            }
            
            // Record missed external click
            Task { @MainActor in
                if let resultsManager = testResultsManager {
                    let result = TestResult(
                        testType: .mouseClick,
                        success: false,
                        details: "External click missed all targets with \(button.rawValue.lowercased()) button",
                        coordinates: location
                    )
                    resultsManager.addResult(result)
                    print("📝 Recorded missed external click result")
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    func startTestSession() {
        print("🎬 Starting new test session...")
        currentTestSession = TestSession(startTime: Date())
        clearAllResults()
        print("✅ Test session started with ID: \(currentTestSession?.id.uuidString ?? "unknown")")
    }
    
    func endTestSession() {
        print("🎬 Ending test session...")
        stopMouseEventMonitoring() // Stop monitoring when session ends
        currentTestSession?.endTime = Date()
        if let session = currentTestSession {
            print("✅ Test session ended:")
            print("   Duration: \(String(format: "%.2f", session.duration))s")
            print("   Total tests: \(session.totalTests)")
            print("   Success rate: \(String(format: "%.1f", session.successRate * 100))%")
        }
    }
    
    func clearAllResults() {
        print("🧹 Clearing all test results...")
        keyboardTestResults.removeAll()
        waitTestResults.removeAll()
        print("✅ All results cleared")
    }
    
    // MARK: - Click Target Management
    
    func initializeClickTargets() {
        print("🎯 Initializing click targets...")
        
        let targetSize: CGFloat = 100
        let testAreaSize: CGFloat = 400
        let margin: CGFloat = targetSize / 2
        
        clickTargets = [
            ClickTargetState(
                id: "top_left",
                label: "TL",
                position: CGPoint(x: margin, y: margin),
                isClicked: false,
                clickedAt: nil
            ),
            ClickTargetState(
                id: "top_right",
                label: "TR",
                position: CGPoint(x: testAreaSize - margin, y: margin),
                isClicked: false,
                clickedAt: nil
            ),
            ClickTargetState(
                id: "center",
                label: "C",
                position: CGPoint(x: testAreaSize / 2, y: testAreaSize / 2),
                isClicked: false,
                clickedAt: nil
            ),
            ClickTargetState(
                id: "bottom_left",
                label: "BL",
                position: CGPoint(x: margin, y: testAreaSize - margin),
                isClicked: false,
                clickedAt: nil
            ),
            ClickTargetState(
                id: "bottom_right",
                label: "BR",
                position: CGPoint(x: testAreaSize - margin, y: testAreaSize - margin),
                isClicked: false,
                clickedAt: nil
            )
        ]
        
        print("✅ Initialized \(clickTargets.count) click targets:")
        for target in clickTargets {
            print("   🎯 \(target.id): \(target.label) at (\(target.position.x), \(target.position.y))")
        }
    }
    
    func markTargetClicked(id: String) {
        print("🎯 Marking target \(id) as clicked...")
        
        if let index = clickTargets.firstIndex(where: { $0.id == id }) {
            let originalTarget = clickTargets[index]
            let updatedTarget = ClickTargetState(
                id: originalTarget.id,
                label: originalTarget.label,
                position: originalTarget.position,
                isClicked: true,
                clickedAt: Date()
            )
            clickTargets[index] = updatedTarget
            
            print("✅ Target \(id) marked as clicked")
            recordTestResult(success: true)
        } else {
            print("❌ Target \(id) not found")
        }
    }
    
    func resetClickTargets() {
        print("🔄 Resetting click targets...")
        
        for index in clickTargets.indices {
            let target = clickTargets[index]
            clickTargets[index] = ClickTargetState(
                id: target.id,
                label: target.label,
                position: target.position,
                isClicked: false,
                clickedAt: nil
            )
        }
        
        print("✅ All click targets reset (\(clickTargets.count) targets)")
    }
    
    // MARK: - Keyboard Test Management
    
    func recordKeyboardTest(
        testName: String,
        expected: String,
        actual: String
    ) {
        print("⌨️ Recording keyboard test: \(testName)")
        print("   Expected: \"\(expected)\"")
        print("   Actual: \"\(actual)\"")
        
        let matches = expected == actual
        let accuracy = calculateTextAccuracy(expected: expected, actual: actual)
        let errorPositions = findErrorPositions(expected: expected, actual: actual)
        
        let result = KeyboardTestResult(
            testName: testName,
            expectedText: expected,
            actualText: actual,
            matches: matches,
            accuracy: accuracy,
            timestamp: Date(),
            characterCount: expected.count,
            errorPositions: errorPositions
        )
        
        keyboardTestResults.append(result)
        recordTestResult(success: matches)
        
        print("✅ Keyboard test recorded - matches: \(matches), accuracy: \(String(format: "%.1f", accuracy * 100))%")
    }
    
    private func calculateTextAccuracy(expected: String, actual: String) -> Double {
        guard !expected.isEmpty else { return actual.isEmpty ? 1.0 : 0.0 }
        
        let maxLength = max(expected.count, actual.count)
        var matchingChars = 0
        
        for i in 0..<maxLength {
            let expectedIndex = expected.index(expected.startIndex, offsetBy: min(i, expected.count - 1))
            let actualIndex = actual.index(actual.startIndex, offsetBy: min(i, actual.count - 1))
            
            if i < expected.count && i < actual.count {
                if expected[expectedIndex] == actual[actualIndex] {
                    matchingChars += 1
                }
            }
        }
        
        return Double(matchingChars) / Double(maxLength)
    }
    
    private func findErrorPositions(expected: String, actual: String) -> [Int] {
        var errorPositions: [Int] = []
        let maxLength = max(expected.count, actual.count)
        
        for i in 0..<maxLength {
            if i >= expected.count || i >= actual.count {
                errorPositions.append(i)
                continue
            }
            
            let expectedIndex = expected.index(expected.startIndex, offsetBy: i)
            let actualIndex = actual.index(actual.startIndex, offsetBy: i)
            
            if expected[expectedIndex] != actual[actualIndex] {
                errorPositions.append(i)
            }
        }
        
        return errorPositions
    }
    
    // MARK: - Wait Test Management
    
    func recordWaitTest(
        condition: String,
        requestedDuration: TimeInterval,
        actualDuration: TimeInterval
    ) {
        print("⏰ Recording wait test:")
        print("   Condition: \(condition)")
        print("   Requested: \(String(format: "%.3f", requestedDuration))s")
        print("   Actual: \(String(format: "%.3f", actualDuration))s")
        
        let accuracy = calculateWaitAccuracy(requested: requestedDuration, actual: actualDuration)
        let success = accuracy > 0.85 // 85%以上で成功とみなす
        
        let result = WaitTestResult(
            condition: condition,
            requestedDuration: requestedDuration,
            actualDuration: actualDuration,
            accuracy: accuracy,
            success: success,
            timestamp: Date()
        )
        
        waitTestResults.append(result)
        recordTestResult(success: success)
        
        print("✅ Wait test recorded - success: \(success), accuracy: \(String(format: "%.1f", accuracy * 100))%")
    }
    
    private func calculateWaitAccuracy(requested: TimeInterval, actual: TimeInterval) -> Double {
        let error = abs(actual - requested)
        let errorPercentage = error / requested
        return max(0.0, 1.0 - errorPercentage)
    }
    
    // MARK: - Test Session Tracking
    
    private func recordTestResult(success: Bool) {
        guard currentTestSession != nil else {
            print("⚠️ No active test session")
            return
        }
        
        currentTestSession?.totalTests += 1
        if success {
            currentTestSession?.successfulTests += 1
        } else {
            currentTestSession?.failedTests += 1
        }
        
        if let session = currentTestSession {
            print("📊 Session stats: \(session.successfulTests)/\(session.totalTests) (\(String(format: "%.1f", session.successRate * 100))%)")
        }
    }
    
    // MARK: - State API
    
    func getCompleteState() -> [String: Any] {
        print("📊 Getting complete state...")
        print("   Click targets: \(clickTargets.count)")
        print("   Keyboard tests: \(keyboardTestResults.count)")
        print("   Wait tests: \(waitTestResults.count)")
        print("   Session active: \(currentTestSession?.isActive ?? false)")
        
        let state = [
            "timestamp": Date().iso8601String,
            "session": currentTestSession?.toDictionary() ?? NSNull(),
            "click_targets": clickTargets.map { $0.toDictionary() },
            "keyboard_tests": keyboardTestResults.map { $0.toDictionary() },
            "wait_tests": waitTestResults.map { $0.toDictionary() },
            "summary": [
                "total_click_targets": clickTargets.count,
                "clicked_targets": clickTargets.filter { $0.isClicked }.count,
                "total_keyboard_tests": keyboardTestResults.count,
                "successful_keyboard_tests": keyboardTestResults.filter { $0.matches }.count,
                "total_wait_tests": waitTestResults.count,
                "successful_wait_tests": waitTestResults.filter { $0.success }.count,
                "overall_success_rate": currentTestSession?.successRate ?? 0.0
            ]
        ] as [String: Any]
        
        print("✅ Complete state prepared")
        return state
    }
    
    // MARK: - Helper Methods
    
    func getClickTarget(by id: String) -> ClickTargetState? {
        return clickTargets.first { $0.id == id }
    }
    
    func getClickTarget(near position: CGPoint, tolerance: CGFloat = 50.0) -> ClickTargetState? {
        return clickTargets.first { target in
            let distance = sqrt(pow(target.position.x - position.x, 2) + pow(target.position.y - position.y, 2))
            return distance <= tolerance
        }
    }
}

// MARK: - Date Extension

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
