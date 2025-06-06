import Foundation
import CoreGraphics
@testable import AppPilot

public actor MockScreenDriver: ScreenDriver {
    public var captureWindowCalls: [WindowID] = []
    public var captureScreenCalls: Int = 0
    private var mockApps: [AppInfo] = []
    private var mockWindows: [WindowInfo] = []
    
    public init() {}
    
    public func setMockApps(_ apps: [AppInfo]) {
        mockApps = apps
    }
    
    public func setMockWindows(_ windows: [WindowInfo]) {
        mockWindows = windows
    }
    
    public func captureWindow(_ windowID: WindowID) async throws -> CGImage {
        captureWindowCalls.append(windowID)
        
        // Return a simple 1x1 pixel image for testing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw PilotError.osFailure(api: "CGContext", code: -1)
        }
        
        return image
    }
    
    public func captureScreen() async throws -> CGImage {
        captureScreenCalls += 1
        
        // Return a simple 1x1 pixel image for testing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw PilotError.osFailure(api: "CGContext", code: -1)
        }
        
        return image
    }
    
    public func reset() {
        captureWindowCalls.removeAll()
        captureScreenCalls = 0
        mockApps.removeAll()
        mockWindows.removeAll()
    }
}