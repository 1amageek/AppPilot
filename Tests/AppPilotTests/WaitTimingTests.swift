import Testing
import Foundation
@testable import AppPilot

@Suite("Wait Timing Tests (WT)")
struct WaitTimingTests {
    private let config = TestConfiguration(verboseLogging: true)
    private let client = TestAppClient()
    private let discovery = TestAppDiscovery(config: TestConfiguration())
    
    @Test("WT-01: Time-based wait precision - 1500ms with ±50ms tolerance",
          .tags(.integration, .timing))
    func testTimeBasedWaitPrecision() async throws {
        let pilot = AppPilot()
        let requestedDuration = 1500 // milliseconds
        let toleranceMs = 50
        
        print("Testing time-based wait for \(requestedDuration)ms")
        
        let startTime = Date()
        
        try await pilot.wait(.time(ms: requestedDuration))
        
        let actualDuration = Date().timeIntervalSince(startTime)
        let actualDurationMs = Int(actualDuration * 1000)
        let errorMs = abs(actualDurationMs - requestedDuration)
        
        print("Requested: \(requestedDuration)ms")
        print("Actual: \(actualDurationMs)ms")
        print("Error: \(errorMs)ms")
        print("Tolerance: ±\(toleranceMs)ms")
        
        // Verify timing precision according to specification
        #expect(errorMs <= toleranceMs, "Wait timing error (\(errorMs)ms) should be within ±\(toleranceMs)ms")
        
        // Record result in TestApp for integration testing
        try await client.resetState()
        let sessionId = try await client.startSession()
        
        // Simulate recording the wait test (TestApp would normally do this automatically)
        // In real implementation, the pilot.wait() would trigger TestApp to record this
        
        let _ = try await client.endSession()
        print("Wait test recorded in session: \(sessionId)")
    }
    
    
    @Test("WT-Performance: Multiple wait operations timing consistency",
          .tags(.performance, .timing))
    func testWaitTimingConsistency() async throws {
        let pilot = AppPilot()
        let requestedDuration = 500 // ms
        let iterations = 10
        var timingResults: [TimeInterval] = []
        
        print("Testing wait timing consistency over \(iterations) iterations")
        
        for i in 0..<iterations {
            let startTime = Date()
            
            try await pilot.wait(.time(ms: requestedDuration))
            
            let actualDuration = Date().timeIntervalSince(startTime)
            timingResults.append(actualDuration)
            
            let actualMs = Int(actualDuration * 1000)
            let errorMs = abs(actualMs - requestedDuration)
            
            print("Iteration \(i+1): \(actualMs)ms (error: \(errorMs)ms)")
        }
        
        // Calculate statistics
        let averageDuration = timingResults.reduce(0, +) / Double(timingResults.count)
        let averageMs = Int(averageDuration * 1000)
        let averageError = abs(averageMs - requestedDuration)
        
        let maxDuration = timingResults.max() ?? 0
        let minDuration = timingResults.min() ?? 0
        let variance = Int((maxDuration - minDuration) * 1000)
        
        print("\nTiming Statistics:")
        print("Average: \(averageMs)ms (error: \(averageError)ms)")
        print("Min: \(Int(minDuration * 1000))ms")
        print("Max: \(Int(maxDuration * 1000))ms")
        print("Variance: \(variance)ms")
        
        // Verify consistency requirements
        #expect(averageError <= 25, "Average timing error should be <= 25ms")
        #expect(variance <= 100, "Timing variance should be <= 100ms")
        
        // All individual measurements should be within tolerance
        for (index, duration) in timingResults.enumerated() {
            let errorMs = abs(Int(duration * 1000) - requestedDuration)
            #expect(errorMs <= 50, "Iteration \(index+1) error (\(errorMs)ms) should be <= 50ms")
        }
    }
    
    @Test("WT-Edge: Wait with very short duration",
          .tags(.integration, .timing, .edgeCases))
    func testVeryShortWaitDuration() async throws {
        let pilot = AppPilot()
        let shortDurations = [10, 50, 100] // milliseconds
        
        for duration in shortDurations {
            print("Testing very short wait: \(duration)ms")
            
            let startTime = Date()
            try await pilot.wait(.time(ms: duration))
            let actualDuration = Date().timeIntervalSince(startTime)
            let actualMs = Int(actualDuration * 1000)
            let errorMs = abs(actualMs - duration)
            
            print("  Requested: \(duration)ms, Actual: \(actualMs)ms, Error: \(errorMs)ms")
            
            // For very short durations, allow larger relative error but smaller absolute error
            let maxError = max(duration / 2, 20) // 50% of duration or 20ms, whichever is larger
            #expect(errorMs <= maxError, "Short wait error should be reasonable for \(duration)ms")
        }
    }
    
    
}
