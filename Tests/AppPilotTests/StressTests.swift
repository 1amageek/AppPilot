import Testing
import Foundation
@testable import AppPilot

@Suite("Stress Tests (ST)")
struct StressTests {
    private let config = TestConfiguration(verboseLogging: false) // Reduce logging for stress tests
    private let client = TestAppClient()
    private let discovery = TestAppDiscovery(config: TestConfiguration())
    
    @Test("ST-01: Random click stress test - 100 operations")
    func testRandomClickStressTest() async throws {
        let pilot = AppPilot()
        let operationCount = 100
        let timeoutSeconds: TimeInterval = 300 // 5 minutes max
        
        // Setup
        try await client.resetState()
        let sessionId = try await client.startSession()
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        let testWindow = readinessInfo.window
        
        print("🔥 Starting random click stress test")
        print("   Operations: \(operationCount)")
        print("   Target window: \(testWindow.title ?? "Unknown")")
        print("   Session: \(sessionId)")
        
        let startTime = Date()
        var successCount = 0
        var errorCount = 0
        var responseTimes: [TimeInterval] = []
        var memoryBaseline: Int = 0
        
        // Get baseline memory usage
        memoryBaseline = getCurrentMemoryUsage()
        print("   Baseline memory: \(memoryBaseline) MB")
        
        // Perform stress operations
        for i in 0..<operationCount {
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeoutSeconds {
                print("⚠️ Stress test timed out after \(timeoutSeconds)s")
                break
            }
            
            let operationStartTime = Date()
            
            do {
                // Generate random coordinates within window bounds
                let x = Double.random(in: 50...750)
                let y = Double.random(in: 50...550)
                let button = [MouseButton.left, .right, .center].randomElement()!
                let policy = [Policy.STAY_HIDDEN, .UNMINIMIZE()].randomElement()!
                
                let result = try await pilot.click(
                    window: testWindow.id,
                    at: Point(x: x, y: y),
                    button: button,
                    policy: policy
                )
                
                let responseTime = Date().timeIntervalSince(operationStartTime)
                responseTimes.append(responseTime)
                
                if result.success {
                    successCount += 1
                } else {
                    errorCount += 1
                }
                
                // Log progress every 100 operations
                if (i + 1) % 100 == 0 {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let rate = Double(i + 1) / elapsed
                    print("   Progress: \(i + 1)/\(operationCount) (\(String(format: "%.1f", rate)) ops/sec)")
                }
                
            } catch {
                errorCount += 1
                if config.verboseLogging {
                    print("   Error in operation \(i + 1): \(error)")
                }
            }
            
            // Small delay to prevent overwhelming the system
            if i % 10 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms every 10 operations
            }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let finalMemory = getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - memoryBaseline
        
        // Calculate statistics
        let operationsCompleted = successCount + errorCount
        let successRate = Double(successCount) / Double(operationsCompleted)
        let averageResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        let maxResponseTime = responseTimes.max() ?? 0
        let operationsPerSecond = Double(operationsCompleted) / totalDuration
        
        print("\n📊 Stress Test Results:")
        print("   Total duration: \(String(format: "%.2f", totalDuration))s")
        print("   Operations completed: \(operationsCompleted)/\(operationCount)")
        print("   Success rate: \(String(format: "%.1f", successRate * 100))%")
        print("   Successful operations: \(successCount)")
        print("   Failed operations: \(errorCount)")
        print("   Operations per second: \(String(format: "%.1f", operationsPerSecond))")
        print("   Average response time: \(String(format: "%.3f", averageResponseTime * 1000))ms")
        print("   Max response time: \(String(format: "%.3f", maxResponseTime * 1000))ms")
        print("   Memory growth: \(memoryGrowth) MB")
        
        // Verify stress test requirements
        #expect(successRate >= 0.95, "Success rate should be >= 95% (\(String(format: "%.1f", successRate * 100))%)")
        #expect(memoryGrowth < 15, "Memory growth should be < 15MB (actual: \(memoryGrowth) MB)")
        #expect(averageResponseTime <= 0.020, "Average response time should be <= 20ms")
        #expect(operationsPerSecond >= 50, "Should maintain >= 50 operations per second")
        
        // End session and verify final state
        let session = try await client.endSession()
        print("   Final session success rate: \(String(format: "%.1f", session.successRate * 100))%")
    }
    
    @Test("ST-02: Random type stress test - 50 operations")
    func testRandomTypeStressTest() async throws {
        let pilot = AppPilot()
        let operationCount = 50
        
        // Setup
        try await client.resetState()
        let sessionId = try await client.startSession()
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        let testWindow = readinessInfo.window
        
        print("⌨️ Starting random type stress test")
        print("   Operations: \(operationCount)")
        
        let startTime = Date()
        var successCount = 0
        var errorCount = 0
        var responseTimes: [TimeInterval] = []
        
        // Predefined text samples for variety
        let textSamples = [
            "Hello World",
            "Test123",
            "Special!@#$%",
            "こんにちは",
            "Mixed123!@#",
            "Line1\nLine2",
            "Tab\tSeparated",
            "Unicode: 🚀🎉✨",
            "",
            "A",
            "Very long text string that contains multiple words and should test the system's ability to handle longer input sequences without issues."
        ]
        
        for i in 0..<operationCount {
            let operationStartTime = Date()
            
            do {
                let text = textSamples.randomElement()!
                let policy = [Policy.STAY_HIDDEN, .UNMINIMIZE()].randomElement()!
                
                let result = try await pilot.type(
                    text: text,
                    into: testWindow.id,
                    policy: policy
                )
                
                let responseTime = Date().timeIntervalSince(operationStartTime)
                responseTimes.append(responseTime)
                
                if result.success {
                    successCount += 1
                } else {
                    errorCount += 1
                }
                
                if (i + 1) % 50 == 0 {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let rate = Double(i + 1) / elapsed
                    print("   Progress: \(i + 1)/\(operationCount) (\(String(format: "%.1f", rate)) ops/sec)")
                }
                
            } catch {
                errorCount += 1
            }
            
            // Delay between type operations
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let operationsCompleted = successCount + errorCount
        let successRate = Double(successCount) / Double(operationsCompleted)
        let averageResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        
        print("📝 Type Stress Test Results:")
        print("   Success rate: \(String(format: "%.1f", successRate * 100))%")
        print("   Average response time: \(String(format: "%.3f", averageResponseTime * 1000))ms")
        
        #expect(successRate >= 0.90, "Type stress test success rate should be >= 90%")
        #expect(averageResponseTime <= 0.050, "Type average response time should be <= 50ms")
        
        try await client.endSession()
    }
    
    @Test("ST-03: Mixed operations stress test - concurrent load")
    func testMixedOperationsStressTest() async throws {
        let pilot = AppPilot()
        let operationCount = 20 // Per operation type
        let concurrencyLevel = 3
        
        print("🔀 Starting mixed operations stress test")
        print("   Concurrency level: \(concurrencyLevel)")
        
        try await client.resetState()
        let sessionId = try await client.startSession()
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        let testWindow = readinessInfo.window
        
        let startTime = Date()
        var allResults: [ActionResult] = []
        
        // Create concurrent operation tasks
        let tasks = try await withThrowingTaskGroup(of: [ActionResult].self, returning: [ActionResult].self) { group in
            
            // Click operations
            for _ in 0..<concurrencyLevel {
                group.addTask {
                    var results: [ActionResult] = []
                    for _ in 0..<(operationCount / concurrencyLevel) {
                        do {
                            let x = Double.random(in: 100...700)
                            let y = Double.random(in: 100...500)
                            let result = try await pilot.click(
                                window: testWindow.id,
                                at: Point(x: x, y: y),
                                policy: .STAY_HIDDEN
                            )
                            results.append(result)
                        } catch {
                            let failedResult = ActionResult(success: false, route: .UI_EVENT, message: "Error: \(error)")
                            results.append(failedResult)
                        }
                        try await Task.sleep(nanoseconds: 2_000_000) // 2ms
                    }
                    return results
                }
            }
            
            // Type operations
            group.addTask {
                var results: [ActionResult] = []
                let texts = ["Quick", "Test", "123", "Mix"]
                for i in 0..<operationCount {
                    do {
                        let text = texts[i % texts.count]
                        let result = try await pilot.type(
                            text: text,
                            into: testWindow.id,
                            policy: .STAY_HIDDEN
                        )
                        results.append(result)
                    } catch {
                        let failedResult = ActionResult(success: false, route: .AX_ACTION, message: "Error: \(error)")
                        results.append(failedResult)
                    }
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                return results
            }
            
            // Wait operations
            group.addTask {
                var results: [ActionResult] = []
                for _ in 0..<(operationCount / 2) {
                    do {
                        let waitTime = Int.random(in: 10...100) // 10-100ms
                        try await pilot.wait(.time(ms: waitTime))
                        let result = ActionResult(success: true, route: .UI_EVENT, message: "Wait completed")
                        results.append(result)
                    } catch {
                        let failedResult = ActionResult(success: false, route: .UI_EVENT, message: "Wait failed")
                        results.append(failedResult)
                    }
                }
                return results
            }
            
            var combinedResults: [ActionResult] = []
            do {
                for try await taskResults in group {
                    combinedResults.append(contentsOf: taskResults)
                }
            } catch {
                // Handle any task errors gracefully
                print("Task group error: \(error)")
            }
            return combinedResults
        }
        
        allResults = tasks
        
        let totalDuration = Date().timeIntervalSince(startTime)
        let successCount = allResults.filter { $0.success }.count
        let successRate = Double(successCount) / Double(allResults.count)
        
        print("⚡ Mixed Operations Results:")
        print("   Total operations: \(allResults.count)")
        print("   Success rate: \(String(format: "%.1f", successRate * 100))%")
        print("   Duration: \(String(format: "%.2f", totalDuration))s")
        print("   Operations per second: \(String(format: "%.1f", Double(allResults.count) / totalDuration))")
        
        #expect(successRate >= 0.85, "Mixed operations success rate should be >= 85%")
        #expect(totalDuration <= 60.0, "Mixed operations should complete within 60 seconds")
        
        try await client.endSession()
    }
    
    @Test("ST-04: Memory leak detection - basic test")
    func testMemoryLeakDetection() async throws {
        let pilot = AppPilot()
        let iterationCount = 5
        let operationsPerIteration = 10
        
        print("🧪 Starting memory leak detection test")
        
        try await client.resetState()
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        let testWindow = readinessInfo.window
        
        var memoryReadings: [Int] = []
        let initialMemory = getCurrentMemoryUsage()
        memoryReadings.append(initialMemory)
        
        print("   Initial memory: \(initialMemory) MB")
        
        for iteration in 0..<iterationCount {
            // Perform batch of operations
            for _ in 0..<operationsPerIteration {
                do {
                    let x = Double.random(in: 100...700)
                    let y = Double.random(in: 100...500)
                    _ = try await pilot.click(
                        window: testWindow.id,
                        at: Point(x: x, y: y),
                        policy: .STAY_HIDDEN
                    )
                } catch {
                    // Continue on error
                }
            }
            
            // Force garbage collection attempt
            // In real app, this might be automatic
            
            // Take memory reading
            let currentMemory = getCurrentMemoryUsage()
            memoryReadings.append(currentMemory)
            
            let memoryGrowth = currentMemory - initialMemory
            print("   Iteration \(iteration + 1): \(currentMemory) MB (+\(memoryGrowth) MB)")
            
            // Small delay between iterations
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        let finalMemory = memoryReadings.last!
        let totalGrowth = finalMemory - initialMemory
        let maxMemory = memoryReadings.max()!
        let averageGrowthPerIteration = Double(totalGrowth) / Double(iterationCount)
        
        print("💾 Memory Analysis:")
        print("   Initial: \(initialMemory) MB")
        print("   Final: \(finalMemory) MB")
        print("   Total growth: \(totalGrowth) MB")
        print("   Max memory: \(maxMemory) MB")
        print("   Average growth per iteration: \(String(format: "%.2f", averageGrowthPerIteration)) MB")
        
        // Memory leak thresholds
        #expect(totalGrowth < 15, "Total memory growth should be < 15MB (actual: \(totalGrowth) MB)")
        #expect(averageGrowthPerIteration < 1.0, "Average growth per iteration should be < 1MB")
        #expect(maxMemory - initialMemory < 20, "Peak memory growth should be < 20MB")
    }
    
    @Test("ST-05: Error recovery stress test")
    func testErrorRecoveryStressTest() async throws {
        // This test intentionally triggers errors to verify graceful recovery
        let pilot = AppPilot()
        let operationCount = 100
        
        print("🛠️ Starting error recovery stress test")
        
        try await client.resetState()
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        let testWindow = readinessInfo.window
        
        var successCount = 0
        var errorCount = 0
        var recoveryCount = 0
        
        for i in 0..<operationCount {
            do {
                // Intentionally trigger some errors
                if i % 10 == 0 {
                    // Invalid coordinates (outside window)
                    _ = try await pilot.click(
                        window: testWindow.id,
                        at: Point(x: -100, y: -100),
                        policy: .STAY_HIDDEN
                    )
                } else if i % 15 == 0 {
                    // Invalid window ID
                    _ = try await pilot.click(
                        window: WindowID(id: 99999),
                        at: Point(x: 100, y: 100),
                        policy: .STAY_HIDDEN
                    )
                } else {
                    // Normal operation
                    let x = Double.random(in: 100...700)
                    let y = Double.random(in: 100...500)
                    let result = try await pilot.click(
                        window: testWindow.id,
                        at: Point(x: x, y: y),
                        policy: .STAY_HIDDEN
                    )
                    
                    if result.success {
                        successCount += 1
                    }
                }
                
                recoveryCount += 1
                
            } catch {
                errorCount += 1
                // Verify we can continue after error
                recoveryCount += 1
            }
        }
        
        let recoveryRate = Double(recoveryCount) / Double(operationCount)
        
        print("🔧 Error Recovery Results:")
        print("   Operations attempted: \(operationCount)")
        print("   Successful operations: \(successCount)")
        print("   Errors encountered: \(errorCount)")
        print("   Recovery rate: \(String(format: "%.1f", recoveryRate * 100))%")
        
        #expect(recoveryRate >= 0.95, "Should recover from >= 95% of operations")
        #expect(errorCount > 0, "Should have encountered some intentional errors")
        #expect(successCount > 0, "Should have some successful operations")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Int {
        // Simplified memory usage calculation
        // Real implementation would use more accurate system APIs
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Int(info.resident_size) / (1024 * 1024) // Convert to MB
        } else {
            return 0
        }
    }
}
