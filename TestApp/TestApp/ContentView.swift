import SwiftUI

struct ContentView: View {
    @State private var testResultsManager = TestResultsManager()
    @State private var testStateManager = TestStateManager()
    @State private var testStateServer: TestStateServer
    @State private var selectedTab: TestType = .mouseClick
    
    init() {
        let stateManager = TestStateManager()
        let server = TestStateServer(testStateManager: stateManager)
        _testStateManager = State(wrappedValue: stateManager)
        _testStateServer = State(wrappedValue: server)
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack {
                TestSidebar(selectedTab: $selectedTab, testResultsManager: testResultsManager)
                
                Divider()
                
                // API Server Status
                APIStatusView(testStateServer: testStateServer)
                    .padding()
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            // Main content area
            Group {
                switch selectedTab {
                case .mouseClick:
                    MouseClickTestView(
                        testResultsManager: testResultsManager,
                        testStateManager: testStateManager
                    )
                case .keyboard:
                    KeyboardTestView(
                        testResultsManager: testResultsManager,
                        testStateManager: testStateManager
                    )
                case .wait:
                    WaitTestView(
                        testResultsManager: testResultsManager,
                        testStateManager: testStateManager
                    )
                case .resolve:
                    ResolveTestView(testResultsManager: testResultsManager)
                case .integration:
                    IntegrationTestView(testResultsManager: testResultsManager)
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Start Session") {
                        testStateManager.startTestSession()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("End Session") {
                        testStateManager.endTestSession()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Reset State") {
                        testStateManager.clearAllResults()
                        testStateManager.resetClickTargets()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear Results") {
                        testResultsManager.clearResults(for: selectedTab)
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            print("🚀 ContentView.onAppear() 実行開始")
            print("   初期化: testStateManager.initializeClickTargets()")
            testStateManager.initializeClickTargets()
            print("   ✅ testStateManager.initializeClickTargets() 完了")
            
            print("   起動: testStateServer.start()")
            testStateServer.start()
            print("   ✅ testStateServer.start() 完了")
            
            // 初期化確認のため少し待ってから状態をログ出力
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let targetCount = testStateManager.clickTargets.count
                print("🔍 1秒後の確認:")
                print("   クリックターゲット数: \(targetCount)")
                print("   サーバー稼働状況: \(testStateServer.isRunning)")
                
                if targetCount > 0 {
                    print("   ターゲット詳細:")
                    for target in testStateManager.clickTargets {
                        print("     - \(target.id): \(target.label) at (\(target.position.x), \(target.position.y))")
                    }
                } else {
                    print("   ❌ ターゲットが初期化されていません")
                }
            }
        }
        .onDisappear {
            print("🛑 ContentView.onDisappear() 実行")
            testStateServer.stop()
        }
    }
}

struct TestSidebar: View {
    @Binding var selectedTab: TestType
    let testResultsManager: TestResultsManager
    
    var body: some View {
        List(TestType.allCases, id: \.self) { testType in
            TestSidebarRow(
                testType: testType,
                isSelected: selectedTab == testType,
                testResultsManager: testResultsManager
            )
            .onTapGesture {
                selectedTab = testType
            }
        }
        .navigationTitle("AppMCP Test App")
        .listStyle(SidebarListStyle())
    }
}

struct TestSidebarRow: View {
    let testType: TestType
    let isSelected: Bool
    let testResultsManager: TestResultsManager
    
    var body: some View {
        HStack {
            Image(systemName: testType.icon)
                .foregroundColor(testType.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(testType.rawValue)
                    .font(.headline)
                
                HStack {
                    Text("\(testResultsManager.getTotalTests(for: testType)) tests")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let successRate = testResultsManager.getSuccessRate(for: testType)
                    if testResultsManager.getTotalTests(for: testType) > 0 {
                        Text("\(Int(successRate * 100))%")
                            .font(.caption)
                            .foregroundColor(successRate > 0.8 ? .green : successRate > 0.5 ? .orange : .red)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isSelected ? testType.color.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}

struct ResolveTestView: View {
    let testResultsManager: TestResultsManager
    
    var body: some View {
        VStack {
            Text("Resolve Test View")
                .font(.title)
            Text("App and Window resolution testing will be implemented here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct IntegrationTestView: View {
    let testResultsManager: TestResultsManager
    
    var body: some View {
        VStack {
            Text("Integration Test View")
                .font(.title)
            Text("End-to-end integration testing will be implemented here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ContentView()
}
