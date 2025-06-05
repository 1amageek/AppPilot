import Foundation
@testable import AppPilot

public actor MockMissionControlDriver: MissionControlDriver {
    private var currentSpace = 1
    private var windowSpaces: [WindowID: Int] = [:]
    private var spaces = [1, 2, 3]
    
    public init() {}
    
    public func setCurrentSpace(_ space: Int) {
        currentSpace = space
    }
    
    public func setWindowSpace(_ window: WindowID, space: Int) {
        windowSpaces[window] = space
    }
    
    public func getCurrentSpace() async throws -> Int {
        return currentSpace
    }
    
    public func getSpaceForWindow(_ window: WindowID) async throws -> Int {
        return windowSpaces[window] ?? currentSpace
    }
    
    public func moveWindow(_ window: WindowID, toSpace space: Int) async throws {
        windowSpaces[window] = space
    }
    
    public func listSpaces() async throws -> [Int] {
        return spaces
    }
}