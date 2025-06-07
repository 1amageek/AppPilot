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
                
                GeometryReader { geometry in
                    testArea
                        .frame(width: testAreaSize, height: testAreaSize)
                        .background(Color.gray.opacity(0.1))
                        .border(Color.gray, width: 2)
                        .clipped()
                        .onAppear {
                            // Update test area frame when geometry changes
                            updateTestAreaFrame(geometry: geometry)
                        }
                }
                .frame(width: testAreaSize, height: testAreaSize)
                
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
            // Initialize targets if not already done
            if testStateManager.clickTargets.isEmpty {
                testStateManager.initializeClickTargets()
            }
            // Connect testResultsManager to testStateManager for external click recording
            testStateManager.testResultsManager = testResultsManager
            setupEventMonitoring()
        }
        .onDisappear {
            testStateManager.stopMouseEventMonitoring()
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
            backgroundArea
            targetElements
            if showCoordinates {
                coordinateGrid
            }
        }
    }
    
    private var backgroundArea: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleAreaClick(at: location)
            }
    }
    
    private var targetElements: some View {
        ForEach(testStateManager.clickTargets, id: \.id) { target in
            targetView(for: target)
        }
    }
    
    private func targetView(for target: TestStateManager.ClickTargetState) -> some View {
        ZStack {
            Circle()
                .fill(target.isClicked ? Color.green : Color.red)
                .frame(width: targetSize, height: targetSize)
            
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .frame(width: targetSize, height: targetSize)
            
            Text(target.label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .position(target.position)
        .onTapGesture {
            handleTargetClick(targetId: target.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits([.isButton])
        .accessibilityLabel("Click target \(target.label)")
        .accessibilityIdentifier("click_target_\(target.id)")
        .accessibilityValue(target.isClicked ? "clicked" : "unclicked")
        .accessibilityHint("Tap to register a click on this target")
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
    
    private func updateTestAreaFrame(geometry: GeometryProxy) {
        // Convert the GeometryProxy frame to global coordinates
        let localFrame = geometry.frame(in: .global)
        print("🔄 Updating test area frame: \(localFrame)")
        
        setupEventMonitoring(testAreaGlobalFrame: localFrame)
    }
    
    private func setupEventMonitoring(testAreaGlobalFrame: CGRect? = nil) {
        // Delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            // Try multiple methods to find the window
            var targetWindow: NSWindow?
            
            // Method 1: Find window containing the test app
            if let window = NSApplication.shared.windows.first(where: { window in
                window.isVisible && window.title.contains("TestApp")
            }) {
                targetWindow = window
                print("✅ Found window by title: \(window.title)")
            }
            // Method 2: Find the main window
            else if let window = NSApplication.shared.windows.first(where: { $0.isMainWindow }) {
                targetWindow = window
                print("✅ Found main window")
            }
            // Method 3: Find any visible window
            else if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
                targetWindow = window
                print("✅ Found visible window")
            }
            
            if let window = targetWindow {
                let windowFrame = window.frame
                let testAreaFrame = testAreaGlobalFrame ?? CGRect(x: 0, y: 0, width: testAreaSize, height: testAreaSize)
                
                print("🖱️ Setting up event monitoring for test area")
                print("   Window: \(window.title.isEmpty ? "(untitled)" : window.title)")
                print("   Window frame: \(windowFrame)")
                print("   Test area frame: \(testAreaFrame)")
                print("   Window visible: \(window.isVisible)")
                print("   Window key: \(window.isKeyWindow)")
                print("   Window main: \(window.isMainWindow)")
                
                testStateManager.startMouseEventMonitoring(
                    testAreaFrame: testAreaFrame,
                    windowFrame: windowFrame
                )
            } else {
                print("⚠️ Could not find any window for event monitoring")
                print("   Available windows: \(NSApplication.shared.windows.count)")
                for (index, window) in NSApplication.shared.windows.enumerated() {
                    print("   Window \(index): title='\(window.title)', visible=\(window.isVisible), key=\(window.isKeyWindow)")
                }
            }
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