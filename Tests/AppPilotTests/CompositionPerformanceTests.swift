import Testing
import Foundation
@testable import AppPilot

/// Performance tests for composition input functionality
@Suite("Composition Input Performance Tests")
struct CompositionPerformanceTests {
    
    @Test("⚡ Composition type creation performance")
    func testCompositionTypeCreationPerformance() async throws {
        print("⚡ Testing Composition Type Creation Performance")
        print("=" * 50)
        
        let iterations = 10000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test rapid creation of composition types
        for i in 0..<iterations {
            let style = InputMethodStyle(rawValue: "test-style-\(i)")
            let composition = CompositionType.japanese(style)
            
            // Verify creation worked
            #expect(composition.rawValue == "japanese")
            #expect(composition.style?.rawValue == "test-style-\(i)")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations) * 1000 // ms
        
        print("📊 Performance Results:")
        print("   Total iterations: \(iterations)")
        print("   Total time: \(String(format: "%.3f", totalTime))s")
        print("   Average time per creation: \(String(format: "%.6f", averageTime))ms")
        
        // Performance assertion - should be very fast
        #expect(averageTime < 0.1, "Composition type creation should be under 0.1ms per operation")
        
        print("✅ Composition type creation performance test passed")
    }
    
    @Test("⚡ Composition result processing performance")
    func testCompositionResultProcessingPerformance() async throws {
        print("⚡ Testing Composition Result Processing Performance")
        print("=" * 50)
        
        let iterations = 1000
        let candidateCount = 10
        
        // Create test data
        let testCandidates = (0..<candidateCount).map { "候補\($0)" }
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            // Create composition result
            let result = CompositionInputResult(
                state: .candidateSelection(
                    original: "test\(i)",
                    candidates: testCandidates,
                    selectedIndex: i % candidateCount
                ),
                inputText: "test\(i)",
                currentText: "テスト\(i)",
                needsUserDecision: true,
                availableActions: [.selectCandidate(index: 0), .nextCandidate, .commit],
                compositionType: .japaneseRomaji
            )
            
            // Test convenience property access
            let _ = result.candidates
            let _ = result.selectedCandidateIndex
            let _ = result.isCompleted
            let _ = result.needsUserDecision
            
            // Verify data integrity
            #expect(result.candidates?.count == candidateCount)
            #expect(result.selectedCandidateIndex == i % candidateCount)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations) * 1000 // ms
        
        print("📊 Performance Results:")
        print("   Total iterations: \(iterations)")
        print("   Candidates per result: \(candidateCount)")
        print("   Total time: \(String(format: "%.3f", totalTime))s")
        print("   Average time per result: \(String(format: "%.3f", averageTime))ms")
        
        // Performance assertion
        #expect(averageTime < 10, "Composition result processing should be under 10ms per operation")
        
        print("✅ Composition result processing performance test passed")
    }
    
    @Test("⚡ ActionResult composition integration performance")
    func testActionResultCompositionIntegrationPerformance() async throws {
        print("⚡ Testing ActionResult Composition Integration Performance")
        print("=" * 55)
        
        let iterations = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<iterations {
            // Create composition result
            let compositionResult = CompositionInputResult(
                state: .committed(text: "結果\(i)"),
                inputText: "kekka\(i)",
                currentText: "結果\(i)",
                needsUserDecision: false,
                availableActions: [],
                compositionType: .japaneseRomaji
            )
            
            // Create ActionResult with composition
            let actionResult = ActionResult(
                success: true,
                element: nil,
                coordinates: nil,
                data: .type(
                    inputText: "kekka\(i)",
                    actualText: "結果\(i)",
                    inputSource: .japaneseHiragana,
                    composition: compositionResult
                )
            )
            
            // Test convenience property access
            let _ = actionResult.isCompositionInput
            let _ = actionResult.isDirectInput
            let _ = actionResult.needsUserDecision
            let _ = actionResult.isCompositionCompleted
            let _ = actionResult.compositionCandidates
            let _ = actionResult.selectedCandidateIndex
            let _ = actionResult.typeData
            let _ = actionResult.compositionData
            
            // Verify data integrity
            #expect(actionResult.isCompositionInput)
            #expect(!actionResult.isDirectInput)
            #expect(actionResult.isCompositionCompleted)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations) * 1000 // ms
        
        print("📊 Performance Results:")
        print("   Total iterations: \(iterations)")
        print("   Total time: \(String(format: "%.3f", totalTime))s")
        print("   Average time per ActionResult: \(String(format: "%.3f", averageTime))ms")
        
        // Performance assertion
        #expect(averageTime < 5, "ActionResult composition integration should be under 5ms per operation")
        
        print("✅ ActionResult composition integration performance test passed")
    }
    
    @Test("⚡ String system UI filtering performance")
    func testStringSystemUIFilteringPerformance() async throws {
        print("⚡ Testing String System UI Filtering Performance")
        print("=" * 50)
        
        let testStrings = [
            "OK", "Cancel", "確定", "キャンセル", "変換", "無変換",
            "こんにちは", "Hello", "test123", "日本語", "中文", "한글",
            "ありがとう", "thank you", "merci", "gracias",
            "←", "→", "↑", "↓", "▲", "▼", "◀", "▶"
        ]
        
        let iterations = 10000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var systemUICount = 0
        var normalTextCount = 0
        
        for _ in 0..<iterations {
            for text in testStrings {
                if text.isSystemUIText() {
                    systemUICount += 1
                } else {
                    normalTextCount += 1
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let totalChecks = iterations * testStrings.count
        let averageTime = totalTime / Double(totalChecks) * 1_000_000 // μs
        
        print("📊 Performance Results:")
        print("   Total iterations: \(iterations)")
        print("   Strings per iteration: \(testStrings.count)")
        print("   Total checks: \(totalChecks)")
        print("   Total time: \(String(format: "%.3f", totalTime))s")
        print("   Average time per check: \(String(format: "%.3f", averageTime))μs")
        print("   System UI detections: \(systemUICount)")
        print("   Normal text detections: \(normalTextCount)")
        
        // Performance assertion
        #expect(averageTime < 50, "String system UI filtering should be under 50μs per check")
        
        print("✅ String system UI filtering performance test passed")
    }
    
    @Test("⚡ Memory usage during composition operations")
    func testMemoryUsageDuringCompositionOperations() async throws {
        print("⚡ Testing Memory Usage During Composition Operations")
        print("=" * 50)
        
        let iterations = 100
        var memoryUsages: [Int] = []
        
        func getMemoryUsage() -> Int {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            
            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                             task_flavor_t(MACH_TASK_BASIC_INFO),
                             $0,
                             &count)
                }
            }
            
            if kerr == KERN_SUCCESS {
                return Int(info.resident_size)
            } else {
                return 0
            }
        }
        
        let initialMemory = getMemoryUsage()
        memoryUsages.append(initialMemory)
        
        // Perform composition operations
        for i in 0..<iterations {
            let compositionResult = CompositionInputResult(
                state: .candidateSelection(
                    original: "test\(i)",
                    candidates: Array(0..<10).map { "候補\($0)" },
                    selectedIndex: i % 10
                ),
                inputText: "test\(i)",
                currentText: "テスト\(i)",
                needsUserDecision: true,
                availableActions: [.selectCandidate(index: 0), .nextCandidate, .commit],
                compositionType: .japaneseRomaji
            )
            
            let actionResult = ActionResult(
                success: true,
                data: .type(
                    inputText: "test\(i)",
                    actualText: "テスト\(i)",
                    inputSource: .japaneseHiragana,
                    composition: compositionResult
                )
            )
            
            // Test operations
            let _ = actionResult.isCompositionInput
            let _ = actionResult.compositionCandidates
            let _ = actionResult.typeData
            
            // Sample memory usage periodically
            if i % 10 == 0 {
                memoryUsages.append(getMemoryUsage())
            }
        }
        
        let finalMemory = getMemoryUsage()
        memoryUsages.append(finalMemory)
        
        let memoryIncrease = finalMemory - initialMemory
        let memoryIncreaseKB = memoryIncrease / 1024
        let memoryIncreasePerOp = memoryIncrease / iterations
        
        print("📊 Memory Usage Results:")
        print("   Initial memory: \(initialMemory / 1024)KB")
        print("   Final memory: \(finalMemory / 1024)KB")
        print("   Memory increase: \(memoryIncreaseKB)KB")
        print("   Memory per operation: \(memoryIncreasePerOp) bytes")
        print("   Total operations: \(iterations)")
        
        // Memory assertion - should not use excessive memory
        #expect(memoryIncreaseKB < 1024, "Memory increase should be less than 1MB for \(iterations) operations")
        
        print("✅ Memory usage test completed")
    }
}