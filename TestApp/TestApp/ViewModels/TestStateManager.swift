import Foundation
import SwiftUI

@MainActor
@Observable
class TestStateManager {
    var clickTargets: [ClickTargetState] = []
    var keyboardTestResults: [KeyboardTestResult] = []
    var waitTestResults: [WaitTestResult] = []
    var currentTestSession: TestSession?
    
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
    
    // MARK: - Session Management
    
    func startTestSession() {
        print("🎬 Starting new test session...")
        currentTestSession = TestSession(startTime: Date())
        clearAllResults()
        print("✅ Test session started with ID: \(currentTestSession?.id.uuidString ?? "unknown")")
    }
    
    func endTestSession() {
        print("🎬 Ending test session...")
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
