import SwiftUI

struct KeyboardTestView: View {
    let testResultsManager: TestResultsManager
    let testStateManager: TestStateManager
    
    @State private var selectedTestCase: KeyboardTestCase?
    @State private var expectedText: String = ""
    @State private var actualText: String = ""
    @State private var isTestActive: Bool = false
    @State private var customInput: String = ""
    @State private var useCustomInput: Bool = false
    
    var body: some View {
        HStack(spacing: 20) {
            // Left panel - Controls and presets
            VStack(alignment: .leading, spacing: 20) {
                controlsSection
                presetsSection
                statisticsSection
                Spacer()
            }
            .frame(width: 300)
            .padding()
            
            Divider()
            
            // Right panel - Test area
            VStack(alignment: .leading, spacing: 20) {
                testAreaHeader
                expectedTextSection
                actualTextSection
                comparisonSection
                actionButtons
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Controls")
                .font(.headline)
            
            Toggle("Use Custom Input", isOn: $useCustomInput)
                .accessibilityIdentifier("use_custom_input_toggle")
            
            if useCustomInput {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter text to test", text: $customInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: customInput) { _, newValue in
                            if useCustomInput {
                                expectedText = newValue
                                selectedTestCase = nil
                            }
                        }
                }
            }
            
            HStack {
                Button("Start Test") {
                    startTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(expectedText.isEmpty)
                
                Button("Clear") {
                    clearTest()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Presets")
                .font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(KeyboardTestCase.presets) { testCase in
                        presetRow(testCase)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func presetRow(_ testCase: KeyboardTestCase) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(testCase.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(testCase.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedTestCase?.id == testCase.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            Text("Input: \"\(testCase.input.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\t", with: "\\t"))\"")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding()
        .background(selectedTestCase?.id == testCase.id ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onTapGesture {
            selectPreset(testCase)
        }
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
            
            let results = testResultsManager.getResults(for: .keyboard)
            let successRate = testResultsManager.getSuccessRate(for: .keyboard)
            
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
            
            if let lastResult = results.first {
                HStack {
                    Text("Last Test:")
                    Spacer()
                    Image(systemName: lastResult.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(lastResult.success ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var testAreaHeader: some View {
        HStack {
            Text("Keyboard Input Test")
                .font(.title2)
            
            Spacer()
            
            if isTestActive {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Test Active - Type in the field below")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var expectedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expected Text")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(expectedText.isEmpty ? "No test selected" : expectedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 80)
        }
    }
    
    private var actualTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actual Input (Type here when test is active)")
                .font(.headline)
            
            TextField("", text: $actualText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(isTestActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
                .border(isTestActive ? Color.blue : Color.clear, width: 2)
                .frame(height: 80)
                .disabled(!isTestActive)
                .onChange(of: actualText) { _, newValue in
                    if isTestActive && newValue == expectedText {
                        completeTest(success: true)
                    }
                }
        }
    }
    
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparison")
                .font(.headline)
            
            if !expectedText.isEmpty || !actualText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Length:")
                        Spacer()
                        Text("Expected: \(expectedText.count), Actual: \(actualText.count)")
                            .foregroundColor(expectedText.count == actualText.count ? .green : .red)
                    }
                    
                    HStack {
                        Text("Match:")
                        Spacer()
                        if actualText == expectedText {
                            Label("Perfect Match", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if actualText.isEmpty {
                            Text("No input yet")
                                .foregroundColor(.secondary)
                        } else {
                            Label("Mismatch", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !actualText.isEmpty && actualText != expectedText {
                        Text("First difference at position: \(findFirstDifference())")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                Text("No comparison data")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack {
            if isTestActive {
                Button("Complete Test") {
                    completeTest(success: actualText == expectedText)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel Test") {
                    cancelTest()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Verify Match") {
                    verifyMatch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(expectedText.isEmpty || actualText.isEmpty)
                
                Button("Reset") {
                    resetTest()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func selectPreset(_ testCase: KeyboardTestCase) {
        selectedTestCase = testCase
        expectedText = testCase.input
        useCustomInput = false
        customInput = ""
        actualText = ""
        isTestActive = false
    }
    
    private func startTest() {
        actualText = ""
        isTestActive = true
    }
    
    private func completeTest(success: Bool) {
        isTestActive = false
        
        let testName = selectedTestCase?.name ?? "Custom Input"
        
        // Record in testStateManager for API access
        testStateManager.recordKeyboardTest(
            testName: testName,
            expected: expectedText,
            actual: actualText
        )
        
        // Record in testResultsManager for UI display
        let result = TestResult(
            testType: .keyboard,
            success: success,
            details: "\(testName) - \(success ? "Perfect match" : "Mismatch")",
            expectedValue: expectedText,
            actualValue: actualText
        )
        
        testResultsManager.addResult(result)
    }
    
    private func cancelTest() {
        isTestActive = false
        actualText = ""
    }
    
    private func clearTest() {
        expectedText = ""
        actualText = ""
        selectedTestCase = nil
        isTestActive = false
        useCustomInput = false
        customInput = ""
    }
    
    private func resetTest() {
        actualText = ""
        isTestActive = false
    }
    
    private func verifyMatch() {
        let success = actualText == expectedText
        completeTest(success: success)
    }
    
    private func findFirstDifference() -> Int {
        let minLength = min(expectedText.count, actualText.count)
        
        for i in 0..<minLength {
            let expectedIndex = expectedText.index(expectedText.startIndex, offsetBy: i)
            let actualIndex = actualText.index(actualText.startIndex, offsetBy: i)
            
            if expectedText[expectedIndex] != actualText[actualIndex] {
                return i
            }
        }
        
        return minLength
    }
}

#Preview {
    KeyboardTestView(
        testResultsManager: TestResultsManager(),
        testStateManager: TestStateManager()
    )
    .frame(width: 800, height: 600)
}