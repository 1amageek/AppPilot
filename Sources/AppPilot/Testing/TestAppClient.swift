import Foundation

public actor TestAppClient {
    private let baseURL: String
    private let session: URLSession
    
    public init(baseURL: String = "http://localhost:8765") {
        self.baseURL = baseURL
        
        // カスタムURLSession設定でネットワーク問題を回避
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        config.allowsCellularAccess = false
        config.allowsConstrainedNetworkAccess = false
        config.allowsExpensiveNetworkAccess = false
        config.connectionProxyDictionary = [:]
        
        self.session = URLSession(configuration: config)
        
        print("🔧 TestAppClient初期化: \(baseURL)")
    }
    
    // MARK: - API Client Methods
    
    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> [String: Any] {
        let fullURL = "\(baseURL)\(endpoint)"
        print("🌐 リクエスト作成: \(method) \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ 無効なURL: \(fullURL)")
            throw TestAppError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("TestAppClient/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        if let body = body {
            request.httpBody = body
        }
        
        print("📤 リクエスト送信中...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            print("📥 レスポンス受信: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ HTTPレスポンスではありません")
                throw TestAppError.invalidResponse
            }
            
            print("✅ HTTP \(httpResponse.statusCode)")
            
            if httpResponse.statusCode >= 400 {
                print("❌ HTTPエラー: \(httpResponse.statusCode)")
                throw TestAppError.httpError(httpResponse.statusCode)
            }
            
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                print("❌ JSON解析失敗: \(responseString)")
                throw TestAppError.invalidJSON
            }
            
            print("✅ JSON解析成功")
            return jsonObject
            
        } catch let urlError as URLError {
            print("❌ URLError: \(urlError.code) - \(urlError.localizedDescription)")
            print("   失敗したURL: \(urlError.failureURLString ?? "unknown")")
            throw urlError
        } catch {
            print("❌ その他のエラー: \(error)")
            throw error
        }
    }
    
    private func makeArrayRequest(endpoint: String, method: String = "GET") async throws -> [[String: Any]] {
        let fullURL = "\(baseURL)\(endpoint)"
        print("🌐 配列リクエスト: \(method) \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            throw TestAppError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestAppError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            throw TestAppError.httpError(httpResponse.statusCode)
        }
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw TestAppError.invalidJSON
        }
        
        return jsonArray
    }
    
    // MARK: - Health Check
    
    public func healthCheck() async throws -> Bool {
        print("💚 ヘルスチェック開始...")
        do {
            let response = try await makeRequest(endpoint: "/api/health")
            let isHealthy = (response["status"] as? String) == "healthy"
            print("💚 ヘルスチェック結果: \(isHealthy)")
            return isHealthy
        } catch {
            print("💔 ヘルスチェック失敗: \(error)")
            return false
        }
    }
    
    // MARK: - Session Management
    
    public func startSession() async throws -> String {
        print("🎬 セッション開始...")
        let response = try await makeRequest(endpoint: "/api/session/start", method: "POST")
        guard let sessionId = response["session_id"] as? String else {
            throw TestAppError.missingSessionId
        }
        print("🎬 セッション開始成功: \(sessionId)")
        return sessionId
    }
    
    public func endSession() async throws -> TestSession {
        print("🎬 セッション終了...")
        let response = try await makeRequest(endpoint: "/api/session/end", method: "POST")
        guard let sessionData = response["session"] as? [String: Any] else {
            throw TestAppError.invalidSessionData
        }
        let session = try TestSession.from(dictionary: sessionData)
        print("🎬 セッション終了成功")
        return session
    }
    
    public func resetState() async throws {
        print("🔄 状態リセット...")
        _ = try await makeRequest(endpoint: "/api/reset", method: "POST")
        print("🔄 状態リセット成功")
    }
    
    // MARK: - State Queries
    
    public func getState() async throws -> TestAppState {
        let response = try await makeRequest(endpoint: "/api/state")
        return try TestAppState.from(dictionary: response)
    }
    
    public func getClickTargets() async throws -> [ClickTargetState] {
        let targets = try await makeArrayRequest(endpoint: "/api/targets")
        return try targets.map { try ClickTargetState.from(dictionary: $0) }
    }
    
    public func getKeyboardTests() async throws -> [KeyboardTestResult] {
        let tests = try await makeArrayRequest(endpoint: "/api/keyboard-tests")
        return try tests.map { try KeyboardTestResult.from(dictionary: $0) }
    }
    
    public func getWaitTests() async throws -> [WaitTestResult] {
        let tests = try await makeArrayRequest(endpoint: "/api/wait-tests")
        return try tests.map { try WaitTestResult.from(dictionary: $0) }
    }
    
    // MARK: - Validation Methods
    
    public func validateClickTarget(id: String, expectedClicked: Bool = true) async throws -> Bool {
        let targets = try await getClickTargets()
        guard let target = targets.first(where: { $0.id == id }) else {
            throw TestAppError.targetNotFound(id)
        }
        return target.isClicked == expectedClicked
    }
    
    public func validateKeyboardAccuracy(testName: String, expectedAccuracy: Double) async throws -> Bool {
        let tests = try await getKeyboardTests()
        guard let test = tests.first(where: { $0.testName == testName }) else {
            throw TestAppError.keyboardTestNotFound(testName)
        }
        return test.accuracy >= expectedAccuracy
    }
    
    public func validateWaitAccuracy(condition: String, expectedAccuracy: Double) async throws -> Bool {
        let tests = try await getWaitTests()
        guard let test = tests.last else {
            throw TestAppError.noWaitTests
        }
        return test.accuracy >= expectedAccuracy
    }
    
    public func waitForTargetClick(id: String, timeout: TimeInterval = 5.0) async throws -> Bool {
        let endTime = Date().addingTimeInterval(timeout)
        
        while Date() < endTime {
            if try await validateClickTarget(id: id) {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        return false
    }
    
    public func waitForKeyboardTest(testName: String, timeout: TimeInterval = 5.0) async throws -> KeyboardTestResult? {
        let endTime = Date().addingTimeInterval(timeout)
        var lastCount = 0
        
        while Date() < endTime {
            let tests = try await getKeyboardTests()
            
            if tests.count > lastCount {
                if let newTest = tests.first(where: { $0.testName == testName }) {
                    return newTest
                }
            }
            
            lastCount = tests.count
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        
        return nil
    }
}

// MARK: - Error Types

public enum TestAppError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case httpError(Int)
    case missingSessionId
    case invalidSessionData
    case targetNotFound(String)
    case keyboardTestNotFound(String)
    case noWaitTests
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .invalidJSON: return "Invalid JSON"
        case .httpError(let code): return "HTTP error: \(code)"
        case .missingSessionId: return "Missing session ID"
        case .invalidSessionData: return "Invalid session data"
        case .targetNotFound(let id): return "Target not found: \(id)"
        case .keyboardTestNotFound(let name): return "Keyboard test not found: \(name)"
        case .noWaitTests: return "No wait tests found"
        }
    }
}

// MARK: - Data Models

public struct TestAppState: Sendable {
    public let timestamp: String
    public let session: TestSession?
    public let clickTargets: [ClickTargetState]
    public let keyboardTests: [KeyboardTestResult]
    public let waitTests: [WaitTestResult]
    public let summary: TestSummary
    
    static func from(dictionary: [String: Any]) throws -> TestAppState {
        guard let timestamp = dictionary["timestamp"] as? String else {
            throw TestAppError.invalidJSON
        }
        
        let session: TestSession?
        if let sessionData = dictionary["session"] as? [String: Any] {
            session = try TestSession.from(dictionary: sessionData)
        } else {
            session = nil
        }
        
        let clickTargetsData = dictionary["click_targets"] as? [[String: Any]] ?? []
        let clickTargets = try clickTargetsData.map { try ClickTargetState.from(dictionary: $0) }
        
        let keyboardTestsData = dictionary["keyboard_tests"] as? [[String: Any]] ?? []
        let keyboardTests = try keyboardTestsData.map { try KeyboardTestResult.from(dictionary: $0) }
        
        let waitTestsData = dictionary["wait_tests"] as? [[String: Any]] ?? []
        let waitTests = try waitTestsData.map { try WaitTestResult.from(dictionary: $0) }
        
        let summaryData = dictionary["summary"] as? [String: Any] ?? [:]
        let summary = try TestSummary.from(dictionary: summaryData)
        
        return TestAppState(
            timestamp: timestamp,
            session: session,
            clickTargets: clickTargets,
            keyboardTests: keyboardTests,
            waitTests: waitTests,
            summary: summary
        )
    }
}

public struct TestSession: Sendable {
    public let id: String
    public let startTime: String
    public let endTime: String?
    public let totalTests: Int
    public let successfulTests: Int
    public let failedTests: Int
    public let successRate: Double
    public let durationSeconds: Double
    public let isActive: Bool
    
    static func from(dictionary: [String: Any]) throws -> TestSession {
        guard let id = dictionary["id"] as? String,
              let startTime = dictionary["start_time"] as? String,
              let totalTests = dictionary["total_tests"] as? Int,
              let successfulTests = dictionary["successful_tests"] as? Int,
              let failedTests = dictionary["failed_tests"] as? Int,
              let successRate = dictionary["success_rate"] as? Double,
              let durationSeconds = dictionary["duration_seconds"] as? Double,
              let isActive = dictionary["is_active"] as? Bool else {
            throw TestAppError.invalidJSON
        }
        
        return TestSession(
            id: id,
            startTime: startTime,
            endTime: dictionary["end_time"] as? String,
            totalTests: totalTests,
            successfulTests: successfulTests,
            failedTests: failedTests,
            successRate: successRate,
            durationSeconds: durationSeconds,
            isActive: isActive
        )
    }
}

public struct ClickTargetState: Sendable {
    public let id: String
    public let label: String
    public let position: CGPoint
    public let isClicked: Bool
    public let clickedAt: String?
    
    static func from(dictionary: [String: Any]) throws -> ClickTargetState {
        guard let id = dictionary["id"] as? String,
              let label = dictionary["label"] as? String,
              let positionData = dictionary["position"] as? [String: Any],
              let x = positionData["x"] as? Double,
              let y = positionData["y"] as? Double,
              let isClicked = dictionary["clicked"] as? Bool else {
            throw TestAppError.invalidJSON
        }
        
        return ClickTargetState(
            id: id,
            label: label,
            position: CGPoint(x: x, y: y),
            isClicked: isClicked,
            clickedAt: dictionary["clicked_at"] as? String
        )
    }
}

public struct KeyboardTestResult: Sendable {
    public let id: String
    public let testName: String
    public let expectedText: String
    public let actualText: String
    public let matches: Bool
    public let accuracy: Double
    public let timestamp: String
    public let characterCount: Int
    public let errorPositions: [Int]
    
    static func from(dictionary: [String: Any]) throws -> KeyboardTestResult {
        guard let id = dictionary["id"] as? String,
              let testName = dictionary["test_name"] as? String,
              let expectedText = dictionary["expected_text"] as? String,
              let actualText = dictionary["actual_text"] as? String,
              let matches = dictionary["matches"] as? Bool,
              let accuracy = dictionary["accuracy"] as? Double,
              let timestamp = dictionary["timestamp"] as? String,
              let characterCount = dictionary["character_count"] as? Int,
              let errorPositions = dictionary["error_positions"] as? [Int] else {
            throw TestAppError.invalidJSON
        }
        
        return KeyboardTestResult(
            id: id,
            testName: testName,
            expectedText: expectedText,
            actualText: actualText,
            matches: matches,
            accuracy: accuracy,
            timestamp: timestamp,
            characterCount: characterCount,
            errorPositions: errorPositions
        )
    }
}

public struct WaitTestResult: Sendable {
    public let id: String
    public let condition: String
    public let requestedDuration: TimeInterval
    public let actualDuration: TimeInterval
    public let accuracy: Double
    public let success: Bool
    public let timestamp: String
    
    var accuracyPercentage: Double {
        return accuracy * 100
    }
    
    static func from(dictionary: [String: Any]) throws -> WaitTestResult {
        guard let id = dictionary["id"] as? String,
              let condition = dictionary["condition"] as? String,
              let requestedDurationMs = dictionary["requested_duration_ms"] as? Int,
              let actualDurationMs = dictionary["actual_duration_ms"] as? Int,
              let accuracy = dictionary["accuracy"] as? Double,
              let success = dictionary["success"] as? Bool,
              let timestamp = dictionary["timestamp"] as? String else {
            throw TestAppError.invalidJSON
        }
        
        return WaitTestResult(
            id: id,
            condition: condition,
            requestedDuration: TimeInterval(requestedDurationMs) / 1000.0,
            actualDuration: TimeInterval(actualDurationMs) / 1000.0,
            accuracy: accuracy,
            success: success,
            timestamp: timestamp
        )
    }
}

public struct TestSummary: Sendable {
    public let totalClickTargets: Int
    public let clickedTargets: Int
    public let totalKeyboardTests: Int
    public let successfulKeyboardTests: Int
    public let totalWaitTests: Int
    public let successfulWaitTests: Int
    public let overallSuccessRate: Double
    
    static func from(dictionary: [String: Any]) throws -> TestSummary {
        return TestSummary(
            totalClickTargets: dictionary["total_click_targets"] as? Int ?? 0,
            clickedTargets: dictionary["clicked_targets"] as? Int ?? 0,
            totalKeyboardTests: dictionary["total_keyboard_tests"] as? Int ?? 0,
            successfulKeyboardTests: dictionary["successful_keyboard_tests"] as? Int ?? 0,
            totalWaitTests: dictionary["total_wait_tests"] as? Int ?? 0,
            successfulWaitTests: dictionary["successful_wait_tests"] as? Int ?? 0,
            overallSuccessRate: dictionary["overall_success_rate"] as? Double ?? 0.0
        )
    }
}
