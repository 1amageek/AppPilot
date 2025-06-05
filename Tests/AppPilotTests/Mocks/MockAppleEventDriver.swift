import Foundation
@testable import AppPilot

public actor MockAppleEventDriver: AppleEventDriver {
    private var supportedCommands: Set<CommandKind> = []
    private var sentEvents: [(spec: AppleEventSpec, app: AppID)] = []
    private var callHistory: [String] = []
    
    public init() {}
    
    public func setSupportedCommands(_ kinds: Set<CommandKind>) {
        supportedCommands = kinds
    }
    
    public func getSentEvents() -> [(spec: AppleEventSpec, app: AppID)] {
        return sentEvents
    }
    
    public func clearHistory() {
        sentEvents.removeAll()
        callHistory.removeAll()
    }
    
    public func getCallHistory() -> [String] {
        return callHistory
    }
    
    public func send(_ spec: AppleEventSpec, to app: AppID) async throws {
        sentEvents.append((spec, app))
        callHistory.append("send(spec: \(spec), app: \(app.pid))")
    }
    
    public func supports(_ command: Command, for app: AppID) async -> Bool {
        callHistory.append("supports(command: \(command.kind), app: \(app.pid))")
        return supportedCommands.contains(command.kind)
    }
}