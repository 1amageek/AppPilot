import Foundation
import Network
import SwiftUI

@MainActor
@Observable
class TestStateServer {
    private var listener: NWListener?
    private let testStateManager: TestStateManager
    private let port: UInt16
    
    var isRunning: Bool = false
    var serverURL: String = ""
    
    init(testStateManager: TestStateManager, port: UInt16 = 8765) {
        self.testStateManager = testStateManager
        self.port = port
        self.serverURL = "http://localhost:\(port)"
    }
    
    func start() {
        print("🚀 TestStateServer.start() 開始 - ポート: \(port)")
        
        guard !isRunning else {
            print("⚠️ サーバーは既に実行中です")
            return
        }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            print("📡 NWParameters設定完了")
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            print("🎧 NWListener作成成功")
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("🔗 新しい接続を受信")
                Task { @MainActor in
                    await self?.handleConnection(connection)
                }
            }
            
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerStateChange(state)
                }
            }
            
            listener?.start(queue: .main)
            print("▶️ listener.start() 呼び出し完了")
            
            isRunning = true
            
            print("🌐 TestStateServer started on port \(port)")
            print("📡 API available at: \(serverURL)")
            
        } catch {
            print("❌ Failed to start TestStateServer: \(error)")
            print("🔍 エラー詳細: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        print("🛑 TestStateServer stopping...")
        listener?.cancel()
        listener = nil
        isRunning = false
        print("✅ TestStateServer stopped")
    }
    
    private func handleListenerStateChange(_ state: NWListener.State) {
        print("📊 Listener state changed: \(state)")
        
        switch state {
        case .setup:
            print("🔧 Setting up...")
        case .waiting(let error):
            print("⏳ Waiting - error: \(error)")
        case .ready:
            print("✅ Ready - listening on port \(port)")
        case .failed(let error):
            print("❌ Failed: \(error)")
            isRunning = false
        case .cancelled:
            print("🚫 Cancelled")
            isRunning = false
        @unknown default:
            print("❓ Unknown state: \(state)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) async {
        print("🔌 Handling connection: \(connection.endpoint)")
        
        connection.stateUpdateHandler = { state in
            print("🔄 Connection state: \(state)")
        }
        
        connection.start(queue: .main)
        
        // Read HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Receive error: \(error)")
                    return
                }
                
                guard let self = self, let data = data else {
                    print("❌ No data received")
                    return
                }
                
                let request = String(data: data, encoding: .utf8) ?? ""
                print("📥 Request received: \(request.prefix(200))...")
                
                let response = await self.processHTTPRequest(request)
                
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { sendError in
                    if let sendError = sendError {
                        print("❌ Send error: \(sendError)")
                    } else {
                        print("✅ Response sent successfully")
                    }
                    connection.cancel()
                })
            }
        }
    }
    
    private func processHTTPRequest(_ request: String) async -> String {
        print("🛠️ Processing HTTP request")
        
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            print("❌ Invalid request line")
            return createHTTPResponse(statusCode: 400, body: "Bad Request")
        }
        
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            print("❌ Invalid request format")
            return createHTTPResponse(statusCode: 400, body: "Bad Request")
        }
        
        let method = components[0]
        let path = components[1]
        
        print("📋 \(method) \(path)")
        
        // Handle CORS preflight
        if method == "OPTIONS" {
            print("🌐 CORS preflight request")
            return createCORSResponse()
        }
        
        // Route requests - 全エンドポイントを実装
        switch (method, path) {
        case ("GET", "/api/state"):
            print("📊 Handling GET /api/state")
            return await handleGetState()
            
        case ("GET", "/api/health"):
            print("💚 Handling GET /api/health")
            return handleHealthCheck()
            
        case ("POST", "/api/reset"):
            print("🔄 Handling POST /api/reset")
            return await handleReset()
            
        case ("POST", "/api/session/start"):
            print("🎬 Handling POST /api/session/start")
            return await handleStartSession()
            
        case ("POST", "/api/session/end"):
            print("🎬 Handling POST /api/session/end")
            return await handleEndSession()
            
        case ("GET", "/api/targets"):
            print("🎯 Handling GET /api/targets")
            return await handleGetTargets()
            
        case ("GET", "/api/keyboard-tests"):
            print("⌨️ Handling GET /api/keyboard-tests")
            return await handleGetKeyboardTests()
            
        case ("GET", "/api/wait-tests"):
            print("⏰ Handling GET /api/wait-tests")
            return await handleGetWaitTests()
            
        default:
            print("❌ Unknown endpoint: \(method) \(path)")
            return createHTTPResponse(statusCode: 404, body: "Not Found: \(path)")
        }
    }
    
    // MARK: - API Handlers
    
    private func handleGetState() async -> String {
        print("📊 Getting complete state...")
        let state = testStateManager.getCompleteState()
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: state, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            print("✅ State serialized successfully (\(jsonData.count) bytes)")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize state: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to serialize state")
        }
    }
    
    private func handleHealthCheck() -> String {
        print("💚 Health check requested")
        let health = [
            "status": "healthy",
            "timestamp": Date().iso8601String,
            "server": "TestStateServer",
            "version": "1.0.0"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: health, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            print("✅ Health check response ready")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize health check: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to serialize health check")
        }
    }
    
    private func handleReset() async -> String {
        print("🔄 Resetting test state...")
        testStateManager.clearAllResults()
        testStateManager.resetClickTargets()
        
        let response = [
            "success": true,
            "message": "Test state reset successfully",
            "timestamp": Date().iso8601String
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            print("✅ Reset completed successfully")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize reset response: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to reset")
        }
    }
    
    private func handleStartSession() async -> String {
        print("🎬 Starting test session...")
        testStateManager.startTestSession()
        
        let response: [String: Any] = [
            "success": true,
            "message": "Test session started",
            "session_id": testStateManager.currentTestSession?.id.uuidString ?? "",
            "timestamp": Date().iso8601String
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            print("✅ Session started successfully")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize session start response: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to start session")
        }
    }
    
    private func handleEndSession() async -> String {
        print("🎬 Ending test session...")
        testStateManager.endTestSession()
        
        let session = testStateManager.currentTestSession?.toDictionary() ?? [:]
        let response: [String: Any] = [
            "success": true,
            "message": "Test session ended",
            "session": session
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            print("✅ Session ended successfully")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize session end response: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to end session")
        }
    }
    
    private func handleGetTargets() async -> String {
        print("🎯 Getting click targets...")
        let targets = testStateManager.clickTargets.map { $0.toDictionary() }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: targets, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            print("✅ Targets retrieved successfully (\(targets.count) targets)")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize targets: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to get targets")
        }
    }
    
    private func handleGetKeyboardTests() async -> String {
        print("⌨️ Getting keyboard test results...")
        let tests = testStateManager.keyboardTestResults.map { $0.toDictionary() }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tests, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            print("✅ Keyboard tests retrieved successfully (\(tests.count) tests)")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize keyboard tests: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to get keyboard tests")
        }
    }
    
    private func handleGetWaitTests() async -> String {
        print("⏰ Getting wait test results...")
        let tests = testStateManager.waitTestResults.map { $0.toDictionary() }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tests, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
            print("✅ Wait tests retrieved successfully (\(tests.count) tests)")
            return createHTTPResponse(statusCode: 200, body: jsonString, contentType: "application/json")
        } catch {
            print("❌ Failed to serialize wait tests: \(error)")
            return createHTTPResponse(statusCode: 500, body: "Failed to get wait tests")
        }
    }
    
    // MARK: - HTTP Response Helpers
    
    private func createHTTPResponse(statusCode: Int, body: String, contentType: String = "text/plain") -> String {
        let statusText = HTTPStatusText.text(for: statusCode)
        let headers = [
            "HTTP/1.1 \(statusCode) \(statusText)",
            "Content-Type: \(contentType); charset=utf-8",
            "Content-Length: \(body.utf8.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Connection: close",
            "",
            body
        ]
        
        return headers.joined(separator: "\r\n")
    }
    
    private func createCORSResponse() -> String {
        return createHTTPResponse(statusCode: 200, body: "")
    }
}

// MARK: - HTTP Status Text Helper

struct HTTPStatusText {
    static func text(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
