import Foundation

public actor SpaceController {
    private let missionControlDriver: MissionControlDriver
    
    private struct SpaceState {
        let windowID: WindowID
        let originalSpace: Int
        let movedToSpace: Int
        let timestamp: Date
    }
    
    private var spaceStates: [WindowID: SpaceState] = [:]
    
    public init(missionControlDriver: MissionControlDriver) {
        self.missionControlDriver = missionControlDriver
    }
    
    public func moveToActiveSpace(_ window: WindowID) async throws -> Int {
        let currentSpace = try await missionControlDriver.getCurrentSpace()
        let windowSpace = try await missionControlDriver.getSpaceForWindow(window)
        
        if windowSpace != currentSpace {
            // Record state for restoration
            spaceStates[window] = SpaceState(
                windowID: window,
                originalSpace: windowSpace,
                movedToSpace: currentSpace,
                timestamp: Date()
            )
            
            // Move window to current space
            try await missionControlDriver.moveWindow(window, toSpace: currentSpace)
        }
        
        return windowSpace
    }
    
    public func restoreOriginalSpace(_ window: WindowID) async throws {
        guard let state = spaceStates[window] else {
            return
        }
        
        defer {
            spaceStates[window] = nil
        }
        
        // Check if user has moved the window manually
        let currentWindowSpace = try await missionControlDriver.getSpaceForWindow(window)
        if currentWindowSpace != state.movedToSpace {
            // User has moved the window, don't restore
            throw PilotError.USER_INTERRUPTED
        }
        
        // Restore to original space
        try await missionControlDriver.moveWindow(window, toSpace: state.originalSpace)
    }
    
    public func getCurrentSpace() async throws -> Int {
        return try await missionControlDriver.getCurrentSpace()
    }
    
    public func listSpaces() async throws -> [Int] {
        return try await missionControlDriver.listSpaces()
    }
    
    public func cleanupStaleStates(olderThan interval: TimeInterval = 300) async {
        let cutoff = Date().addingTimeInterval(-interval)
        spaceStates = spaceStates.filter { _, state in
            state.timestamp > cutoff
        }
    }
}