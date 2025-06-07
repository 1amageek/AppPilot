import SwiftUI

struct APIStatusView: View {
    let testStateServer: TestStateServer
    @State private var showAPIInfo: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(testStateServer.isRunning ? .green : .red)
                
                Text("API Server")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(testStateServer.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            if testStateServer.isRunning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status: Running")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text(testStateServer.serverURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            copyToClipboard(testStateServer.serverURL)
                        }
                    
                    // Hide API Info button during automated testing to prevent modal interference
                    if !isAutomatedTestingMode() {
                        Button("API Info") {
                            showAPIInfo.toggle()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
            } else {
                Text("Status: Stopped")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .sheet(isPresented: $showAPIInfo) {
            APIInfoView(serverURL: testStateServer.serverURL)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func isAutomatedTestingMode() -> Bool {
        // Check if we're running in automated testing mode
        // This can be detected by checking if external automation tools are accessing the app
        return ProcessInfo.processInfo.environment["APPPILOT_TESTING"] != nil ||
               ProcessInfo.processInfo.arguments.contains("--automated-testing") ||
               NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode").isEmpty == false
    }
}

struct APIInfoView: View {
    let serverURL: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("TestApp API Endpoints")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Base URL: \(serverURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Group {
                        APIEndpointView(
                            method: "GET",
                            path: "/api/health",
                            description: "Server health check"
                        )
                        
                        APIEndpointView(
                            method: "GET", 
                            path: "/api/state",
                            description: "Complete test state (all data)"
                        )
                        
                        APIEndpointView(
                            method: "GET",
                            path: "/api/targets", 
                            description: "Click target states only"
                        )
                        
                        APIEndpointView(
                            method: "GET",
                            path: "/api/keyboard-tests",
                            description: "Keyboard test results only"
                        )
                        
                        APIEndpointView(
                            method: "GET",
                            path: "/api/wait-tests",
                            description: "Wait test results only"
                        )
                        
                        APIEndpointView(
                            method: "POST",
                            path: "/api/session/start",
                            description: "Start new test session"
                        )
                        
                        APIEndpointView(
                            method: "POST",
                            path: "/api/session/end",
                            description: "End current test session"
                        )
                        
                        APIEndpointView(
                            method: "POST",
                            path: "/api/reset",
                            description: "Reset all test states"
                        )
                    }
                    
                    Divider()
                    
                    Group {
                        Text("Example Usage")
                            .font(.headline)
                        
                        CodeBlockView(
                            title: "Check if top-left button clicked",
                            code: "curl \(serverURL)/api/targets | jq '.[0].clicked'"
                        )
                        
                        CodeBlockView(
                            title: "Get keyboard test accuracy",
                            code: "curl \(serverURL)/api/keyboard-tests | jq '.[].accuracy'"
                        )
                        
                        CodeBlockView(
                            title: "Start automated test session",
                            code: "curl -X POST \(serverURL)/api/session/start"
                        )
                        
                        CodeBlockView(
                            title: "Get success rate",
                            code: "curl \(serverURL)/api/state | jq '.summary.overall_success_rate'"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("API Documentation")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

struct APIEndpointView: View {
    let method: String
    let path: String
    let description: String
    
    var methodColor: Color {
        switch method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            Text(method)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(methodColor)
                .cornerRadius(4)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct CodeBlockView: View {
    let title: String
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                .onTapGesture {
                    copyToClipboard(code)
                }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    APIStatusView(testStateServer: TestStateServer(testStateManager: TestStateManager()))
}