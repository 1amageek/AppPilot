import SwiftUI

struct KeyboardTestView: View {
    let testResultsManager: TestResultsManager
    let testStateManager: TestStateManager
    
    @State private var expectedText: String = ""
    @State private var actualText: String = ""
    @State private var isTestActive: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Text("Keyboard Input Test")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter expected text, start the test, then type to verify input accuracy")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Main test area
            VStack(spacing: 24) {
                expectedTextInput
                actualTextInput
                resultDisplay
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            
            // Action buttons
            actionButtons
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 600)
    }
    
    private var expectedTextInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Expected Text", systemImage: "text.quote")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Enter the text you want to test typing...", text: $expectedText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .frame(minHeight: 80)
                .disabled(isTestActive)
        }
    }
    
    private var actualTextInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Actual Input", systemImage: "keyboard")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isTestActive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Test Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            TextField("Type here when test is active...", text: $actualText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(isTestActive ? Color.blue.opacity(0.05) : Color.gray.opacity(0.1))
                .cornerRadius(8)
                .frame(minHeight: 80)
                .disabled(!isTestActive)
                .onChange(of: actualText) { _, newValue in
                    if isTestActive && newValue == expectedText && !expectedText.isEmpty {
                        // Auto-complete when text matches
                        completeTest(success: true)
                    }
                }
        }
    }
    
    private var resultDisplay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Match status
            HStack {
                Label("Status", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if actualText.isEmpty && expectedText.isEmpty {
                    Text("Enter expected text to begin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if actualText.isEmpty {
                    Text("No input yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if actualText == expectedText {
                    Label("Perfect Match!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Label("Mismatch", systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            // Character count comparison
            if !expectedText.isEmpty || !actualText.isEmpty {
                HStack {
                    Label("Characters", systemImage: "character.cursor.ibeam")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(actualText.count) / \(expectedText.count)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(actualText.count == expectedText.count ? .primary : .orange)
                }
            }
            
            // Show first difference if there's a mismatch
            if !actualText.isEmpty && actualText != expectedText && !expectedText.isEmpty {
                let diffPosition = findFirstDifference()
                HStack {
                    Label("First difference", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("Position \(diffPosition + 1)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if isTestActive {
                Button(action: cancelTest) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: { completeTest(success: actualText == expectedText) }) {
                    Label("Complete Test", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: clearAll) {
                    Label("Clear All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(expectedText.isEmpty && actualText.isEmpty)
                
                Button(action: startTest) {
                    Label("Start Test", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(expectedText.isEmpty)
            }
        }
    }
    
    // MARK: - Actions
    
    private func startTest() {
        actualText = ""
        isTestActive = true
    }
    
    private func completeTest(success: Bool) {
        isTestActive = false
        
        // Record in testStateManager for API access
        testStateManager.recordKeyboardTest(
            testName: "Manual Test",
            expected: expectedText,
            actual: actualText
        )
        
        // Record in testResultsManager for UI display
        let result = TestResult(
            testType: .keyboard,
            success: success,
            details: success ? "Perfect match" : "Mismatch at position \(findFirstDifference() + 1)",
            expectedValue: expectedText,
            actualValue: actualText
        )
        
        testResultsManager.addResult(result)
    }
    
    private func cancelTest() {
        isTestActive = false
        // Don't clear actualText to allow user to see what was typed
    }
    
    private func clearAll() {
        expectedText = ""
        actualText = ""
        isTestActive = false
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
