import SwiftUI

struct WaitTestView: View {
    let testResultsManager: TestResultsManager
    let testStateManager: TestStateManager
    
    @State private var waitConfig = WaitTestConfig()
    @State private var isWaiting: Bool = false
    @State private var waitProgress: Double = 0.0
    @State private var currentWaitResult: WaitTestResult?
    @State private var waitStartTime: Date?
    @State private var waitTimer: Timer?
    @State private var uiChangeElement: Bool = false
    @State private var uiChangeCounter: Int = 0
    
    private let maxDuration: TimeInterval = 10.0
    private let minDuration: TimeInterval = 0.1
    
    var body: some View {
        HStack(spacing: 20) {
            // Left panel - Controls
            VStack(alignment: .leading, spacing: 20) {
                controlsSection
                statisticsSection
                recentResultsSection
                Spacer()
            }
            .frame(width: 300)
            .padding()
            
            Divider()
            
            // Right panel - Test area
            VStack(spacing: 20) {
                testAreaHeader
                progressSection
                resultSection
                uiChangeTestSection
                actionButtons
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .onDisappear {
            stopWait()
        }
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wait Configuration")
                .font(.headline)
            
            // Duration slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", waitConfig.duration))s")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Slider(
                    value: $waitConfig.duration,
                    in: minDuration...maxDuration,
                    step: 0.1
                )
                
                HStack {
                    Text("\(String(format: "%.1f", minDuration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", maxDuration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Condition picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Wait Condition")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Condition", selection: $waitConfig.condition) {
                    ForEach(WaitTestConfig.WaitCondition.allCases, id: \.self) { condition in
                        Text(condition.rawValue)
                            .tag(condition)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Text(waitConfig.condition.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Quick duration buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Select")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach([0.5, 1.0, 2.0, 3.0, 5.0, 10.0], id: \.self) { duration in
                        Button("\(String(format: duration == floor(duration) ? "%.0f" : "%.1f", duration))s") {
                            waitConfig.duration = duration
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
            
            let results = testResultsManager.getResults(for: .wait)
            let successRate = testResultsManager.getSuccessRate(for: .wait)
            
            HStack {
                Text("Total Tests:")
                Spacer()
                Text("\(results.count)")
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("Success Rate:")
                Spacer()
                Text("\(Int(successRate * 100))%")
                    .fontWeight(.semibold)
                    .foregroundColor(successRate > 0.8 ? .green : successRate > 0.5 ? .orange : .red)
            }
            
            if let avgAccuracy = calculateAverageAccuracy() {
                HStack {
                    Text("Avg Accuracy:")
                    Spacer()
                    Text("\(String(format: "%.1f", avgAccuracy))%")
                        .fontWeight(.semibold)
                        .foregroundColor(avgAccuracy > 95 ? .green : avgAccuracy > 85 ? .orange : .red)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var recentResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Results")
                .font(.headline)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(testResultsManager.getResults(for: .wait).prefix(5))) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)
                                    .font(.caption)
                                
                                Text(result.details)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            
                            if let duration = result.duration {
                                Text("Duration: \(String(format: "%.3f", duration))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var testAreaHeader: some View {
        HStack {
            Text("Wait Test")
                .font(.title2)
            
            Spacer()
            
            if isWaiting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Waiting...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                
                Spacer()
                
                if isWaiting {
                    Text("\(String(format: "%.1f", waitProgress * waitConfig.duration))/\(String(format: "%.1f", waitConfig.duration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: waitProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(height: 8)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            if let startTime = waitStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                Text("Elapsed: \(String(format: "%.3f", elapsed))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last Test Result")
                .font(.headline)
            
            if let result = currentWaitResult {
                VStack(spacing: 8) {
                    HStack {
                        Text("Requested:")
                        Spacer()
                        Text("\(String(format: "%.3f", result.requestedDuration))s")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Actual:")
                        Spacer()
                        Text("\(String(format: "%.3f", result.actualDuration))s")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Error:")
                        Spacer()
                        Text("\(String(format: "%.3f", result.errorMargin))s")
                            .fontWeight(.medium)
                            .foregroundColor(result.errorMargin < 0.1 ? .green : result.errorMargin < 0.5 ? .orange : .red)
                    }
                    
                    HStack {
                        Text("Accuracy:")
                        Spacer()
                        Text(result.accuracyFormatted)
                            .fontWeight(.medium)
                            .foregroundColor(result.accuracy > 0.95 ? .green : result.accuracy > 0.85 ? .orange : .red)
                    }
                    
                    HStack {
                        Text("Condition:")
                        Spacer()
                        Text(result.condition.rawValue)
                            .fontWeight(.medium)
                    }
                }
            } else {
                Text("No test completed yet")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var uiChangeTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UI Change Simulation")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(uiChangeElement ? Color.green : Color.red)
                    .frame(width: 30, height: 30)
                    .animation(.easeInOut(duration: 0.3), value: uiChangeElement)
                
                VStack(alignment: .leading) {
                    Text("UI Element State")
                        .font(.subheadline)
                    Text("Changes: \(uiChangeCounter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Toggle") {
                    uiChangeElement.toggle()
                    uiChangeCounter += 1
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text("Use this when testing UI change detection")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack {
            if isWaiting {
                Button("Stop Wait") {
                    stopWait()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Start Wait Test") {
                    startWaitTest()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Clear Results") {
                    currentWaitResult = nil
                    testResultsManager.clearResults(for: .wait)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func startWaitTest() {
        waitProgress = 0.0
        waitStartTime = Date()
        isWaiting = true
        
        let updateInterval: TimeInterval = 0.05 // 50ms updates for smooth progress
        
        waitTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            guard let startTime = waitStartTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            waitProgress = min(elapsed / waitConfig.duration, 1.0)
            
            if elapsed >= waitConfig.duration {
                completeWaitTest()
            }
        }
    }
    
    private func stopWait() {
        guard let startTime = waitStartTime else { return }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        waitTimer?.invalidate()
        waitTimer = nil
        isWaiting = false
        
        // Record as cancelled/stopped test
        let result = TestResult(
            testType: .wait,
            success: false,
            details: "Wait test stopped manually",
            duration: actualDuration
        )
        
        testResultsManager.addResult(result)
        
        waitStartTime = nil
    }
    
    private func completeWaitTest() {
        guard let startTime = waitStartTime else { return }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        let errorMargin = abs(actualDuration - waitConfig.duration)
        let accuracy = max(0, 1.0 - (errorMargin / waitConfig.duration))
        
        waitTimer?.invalidate()
        waitTimer = nil
        isWaiting = false
        waitProgress = 1.0
        
        currentWaitResult = WaitTestResult(
            requestedDuration: waitConfig.duration,
            actualDuration: actualDuration,
            accuracy: accuracy,
            condition: waitConfig.condition
        )
        
        // Consider test successful if accuracy is above 85%
        let success = accuracy > 0.85
        
        // Record in testStateManager for API access
        testStateManager.recordWaitTest(
            condition: waitConfig.condition.rawValue,
            requestedDuration: waitConfig.duration,
            actualDuration: actualDuration
        )
        
        // Record in testResultsManager for UI display
        let result = TestResult(
            testType: .wait,
            success: success,
            details: "Wait test completed - \(String(format: "%.1f", accuracy * 100))% accuracy",
            duration: actualDuration
        )
        
        testResultsManager.addResult(result)
        
        waitStartTime = nil
    }
    
    private func calculateAverageAccuracy() -> Double? {
        let results = testResultsManager.getResults(for: .wait).filter { $0.success }
        guard !results.isEmpty else { return nil }
        
        var totalAccuracy = 0.0
        var validResults = 0
        
        for result in results {
            if let duration = result.duration,
               let details = result.details.components(separatedBy: " - ").last,
               let accuracyString = details.components(separatedBy: "%").first,
               let accuracy = Double(accuracyString) {
                totalAccuracy += accuracy
                validResults += 1
            }
        }
        
        return validResults > 0 ? totalAccuracy / Double(validResults) : nil
    }
}

#Preview {
    WaitTestView(
        testResultsManager: TestResultsManager(),
        testStateManager: TestStateManager()
    )
    .frame(width: 800, height: 600)
}