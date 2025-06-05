import Foundation
import CoreGraphics
@testable import AppPilot

public actor MockScreenDriver: ScreenDriver {
    private var mockWindows: [Window] = []
    private var mockApps: [App] = []
    private var captureData = Data()
    
    public init() {}
    
    public func setMockWindows(_ windows: [Window]) {
        mockWindows = windows
    }
    
    public func setMockApps(_ apps: [App]) {
        mockApps = apps
    }
    
    public func setCaptureData(_ data: Data) {
        captureData = data
    }
    
    public func capture(window: WindowID) async throws -> PNGData {
        return captureData
    }
    
    public func listWindows() async throws -> [Window] {
        return mockWindows
    }
    
    public func listApplications() async throws -> [App] {
        return mockApps
    }
    
    public func getWindowInfo(_ windowID: WindowID) async throws -> Window {
        guard let window = mockWindows.first(where: { $0.id == windowID }) else {
            throw PilotError.NOT_FOUND(.window, "Window ID: \(windowID.id)")
        }
        return window
    }
}