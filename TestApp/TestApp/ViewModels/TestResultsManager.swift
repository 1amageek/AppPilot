import Foundation
import SwiftUI

@MainActor
@Observable
class TestResultsManager {
    var results: [TestResult] = []
    var isLoggingEnabled: Bool = true
    
    private let maxResults = 1000
    
    func addResult(_ result: TestResult) {
        results.insert(result, at: 0)
        
        // Keep only the most recent results
        if results.count > maxResults {
            results = Array(results.prefix(maxResults))
        }
        
        if isLoggingEnabled {
            logResult(result)
        }
    }
    
    func clearResults() {
        results.removeAll()
    }
    
    func clearResults(for testType: TestType) {
        results.removeAll { $0.testType == testType }
    }
    
    func getResults(for testType: TestType) -> [TestResult] {
        return results.filter { $0.testType == testType }
    }
    
    func getSuccessRate(for testType: TestType) -> Double {
        let typeResults = getResults(for: testType)
        guard !typeResults.isEmpty else { return 0.0 }
        
        let successCount = typeResults.filter { $0.success }.count
        return Double(successCount) / Double(typeResults.count)
    }
    
    func getTotalTests(for testType: TestType) -> Int {
        return getResults(for: testType).count
    }
    
    private func logResult(_ result: TestResult) {
        let timestamp = DateFormatter.logFormatter.string(from: result.timestamp)
        let status = result.success ? "✅" : "❌"
        let typeIcon = result.testType.icon
        
        var logMessage = "\(status) [\(timestamp)] \(result.testType.rawValue): \(result.details)"
        
        if let coordinates = result.coordinates {
            logMessage += " at (\(Int(coordinates.x)), \(Int(coordinates.y)))"
        }
        
        if let expected = result.expectedValue, let actual = result.actualValue {
            logMessage += " - Expected: '\(expected)', Actual: '\(actual)'"
        }
        
        if let duration = result.duration {
            logMessage += " - Duration: \(String(format: "%.3f", duration))s"
        }
        
        print(logMessage)
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}