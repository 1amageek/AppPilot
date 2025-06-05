import Foundation

public struct TestConfiguration: Sendable {
    public let testAppAPIURL: String
    public let testAppBundleID: String
    public let testTimeout: TimeInterval
    public let clickTargetTolerance: Double
    public let keyboardAccuracyThreshold: Double
    public let waitAccuracyThreshold: Double
    public let successRateThreshold: Double
    public let maxRetries: Int
    public let verboseLogging: Bool
    
    public init(
        testAppAPIURL: String = "http://localhost:8765",
        testAppBundleID: String = "com.apppilot.TestApp",
        testTimeout: TimeInterval = 30.0,
        clickTargetTolerance: Double = 50.0,
        keyboardAccuracyThreshold: Double = 0.98,
        waitAccuracyThreshold: Double = 0.85,
        successRateThreshold: Double = 0.95,
        maxRetries: Int = 3,
        verboseLogging: Bool = false
    ) {
        self.testAppAPIURL = testAppAPIURL
        self.testAppBundleID = testAppBundleID
        self.testTimeout = testTimeout
        self.clickTargetTolerance = clickTargetTolerance
        self.keyboardAccuracyThreshold = keyboardAccuracyThreshold
        self.waitAccuracyThreshold = waitAccuracyThreshold
        self.successRateThreshold = successRateThreshold
        self.maxRetries = maxRetries
        self.verboseLogging = verboseLogging
    }
}

public enum TestSuite: String, CaseIterable, Sendable {
    case clickTargets = "click"
    case keyboardInput = "keyboard"
    case waitTiming = "wait"
    case routeSelection = "route"
    case visibilitySpace = "visibility"
    case stress = "stress"
    case full = "full"
    
    public var displayName: String {
        switch self {
        case .clickTargets: return "Click Target Tests"
        case .keyboardInput: return "Keyboard Input Tests"
        case .waitTiming: return "Wait Timing Tests"
        case .routeSelection: return "Route Selection Tests"
        case .visibilitySpace: return "Visibility & Space Tests"
        case .stress: return "Stress Tests"
        case .full: return "Full Test Suite"
        }
    }
}

public struct TestResult: Sendable {
    public let testCase: String
    public let success: Bool
    public let duration: TimeInterval
    public let route: Route?
    public let details: String
    public let timestamp: Date
    public let retryCount: Int
    
    public init(
        testCase: String,
        success: Bool,
        duration: TimeInterval,
        route: Route? = nil,
        details: String,
        retryCount: Int = 0
    ) {
        self.testCase = testCase
        self.success = success
        self.duration = duration
        self.route = route
        self.details = details
        self.timestamp = Date()
        self.retryCount = retryCount
    }
}

public struct TestSuiteResult: Sendable {
    public let suite: TestSuite
    public let results: [TestResult]
    public let startTime: Date
    public let endTime: Date
    public let configuration: TestConfiguration
    
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    public var successCount: Int {
        results.filter { $0.success }.count
    }
    
    public var totalCount: Int {
        results.count
    }
    
    public var successRate: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(successCount) / Double(totalCount)
    }
    
    public var averageResponseTime: TimeInterval {
        guard !results.isEmpty else { return 0.0 }
        return results.map { $0.duration }.reduce(0, +) / Double(results.count)
    }
    
    public init(suite: TestSuite, results: [TestResult], startTime: Date, endTime: Date, configuration: TestConfiguration) {
        self.suite = suite
        self.results = results
        self.startTime = startTime
        self.endTime = endTime
        self.configuration = configuration
    }
}