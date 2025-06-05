import SwiftUI

struct MouseClickTestView: View {
    let testResultsManager: TestResultsManager
    let testStateManager: TestStateManager
    
    @State private var selectedButton: MouseButton = .left
    @State private var clickCount: Int = 1
    @State private var lastClickCoordinate: CGPoint?
    @State private var showCoordinates: Bool = true
    
    private let targetSize: CGFloat = 100
    private let testAreaSize: CGFloat = 400
    
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
            VStack {
                Text("Click Test Area")
                    .font(.title2)
                    .padding(.bottom)
                
                testArea
                    .frame(width: testAreaSize, height: testAreaSize)
                    .background(Color.gray.opacity(0.1))
                    .border(Color.gray, width: 2)
                    .clipped()
                
                if showCoordinates, let coord = lastClickCoordinate {
                    Text("Last click: (\(Int(coord.x)), \(Int(coord.y)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                resetButton
                    .padding(.top)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Targets are initialized by testStateManager
        }
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controls")
                .font(.headline)
            
            // Mouse button selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Mouse Button")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Button", selection: $selectedButton) {
                    ForEach(MouseButton.allCases, id: \.self) { button in
                        Label(button.rawValue, systemImage: button.systemImage)
                            .tag(button)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Click count selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Click Count")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Count", selection: $clickCount) {
                    ForEach(1...3, id: \.self) { count in
                        Text("\(count) click\(count > 1 ? "s" : "")")
                            .tag(count)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Options
            Toggle("Show Coordinates", isOn: $showCoordinates)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Statistics")
                .font(.headline)
            
            let results = testResultsManager.getResults(for: .mouseClick)
            let successRate = testResultsManager.getSuccessRate(for: .mouseClick)
            
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
            
            HStack {
                Text("Targets Hit:")
                Spacer()
                Text("\(testStateManager.clickTargets.filter { $0.isClicked }.count)/\(testStateManager.clickTargets.count)")
                    .fontWeight(.semibold)
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
                    ForEach(Array(testResultsManager.getResults(for: .mouseClick).prefix(5))) { result in
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                                .font(.caption)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.details)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                if let coord = result.coordinates {
                                    Text("(\(Int(coord.x)), \(Int(coord.y)))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var testArea: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleAreaClick(at: location)
                }
            
            // Click targets
            ForEach(testStateManager.clickTargets, id: \.id) { target in
                Circle()
                    .fill(target.isClicked ? Color.green : Color.red)
                    .frame(width: targetSize, height: targetSize)
                    .position(target.position)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .position(target.position)
                    )
                    .overlay(
                        Text(target.label)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .position(target.position)
                    )
                    .onTapGesture {
                        handleTargetClick(targetId: target.id)
                    }
            }
            
            // Coordinate grid (optional)
            if showCoordinates {
                coordinateGrid
            }
        }
    }
    
    private var coordinateGrid: some View {
        ZStack {
            // Vertical lines
            ForEach(0..<5) { i in
                let x = CGFloat(i) * (testAreaSize / 4)
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: testAreaSize))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            }
            
            // Horizontal lines
            ForEach(0..<5) { i in
                let y = CGFloat(i) * (testAreaSize / 4)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: testAreaSize, y: y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
    
    private var resetButton: some View {
        HStack {
            Button("Reset Targets") {
                testStateManager.resetClickTargets()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Clear Results") {
                testResultsManager.clearResults(for: .mouseClick)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func handleTargetClick(targetId: String) {
        // Update target state in testStateManager
        testStateManager.markTargetClicked(id: targetId)
        
        // Get target info for logging
        if let target = testStateManager.getClickTarget(by: targetId) {
            lastClickCoordinate = target.position
            
            // Record successful test result
            let result = TestResult(
                testType: .mouseClick,
                success: true,
                details: "Clicked \(target.label) target with \(selectedButton.rawValue.lowercased()) button (\(clickCount) click\(clickCount > 1 ? "s" : ""))",
                coordinates: target.position
            )
            
            testResultsManager.addResult(result)
        }
    }
    
    private func handleAreaClick(at location: CGPoint) {
        lastClickCoordinate = location
        
        // Check if click was near any target
        if let target = testStateManager.getClickTarget(near: location, tolerance: targetSize / 2) {
            handleTargetClick(targetId: target.id)
        } else {
            // Record missed click
            let result = TestResult(
                testType: .mouseClick,
                success: false,
                details: "Missed click with \(selectedButton.rawValue.lowercased()) button",
                coordinates: location
            )
            
            testResultsManager.addResult(result)
        }
    }
}

#Preview {
    MouseClickTestView(
        testResultsManager: TestResultsManager(),
        testStateManager: TestStateManager()
    )
    .frame(width: 800, height: 600)
}