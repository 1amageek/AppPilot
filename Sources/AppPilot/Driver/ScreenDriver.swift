import Foundation
import CoreGraphics
import AppKit
#if canImport(ScreenCaptureKit)
@preconcurrency import ScreenCaptureKit
#endif

public protocol ScreenDriver: Sendable {
    func capture(window: WindowID) async throws -> PNGData
    func listWindows() async throws -> [Window]
    func listApplications() async throws -> [App]
    func getWindowInfo(_ windowID: WindowID) async throws -> Window
}

public actor DefaultScreenDriver: ScreenDriver {
    public init() {}
    
    public func capture(window: WindowID) async throws -> PNGData {
        // Capture window screenshot using appropriate API based on macOS version
        let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.id) as? [[String: Any]] ?? []
        
        guard !windowList.isEmpty else {
            throw PilotError.NOT_FOUND(.window, "Window ID: \(window.id)")
        }
        
        // Use ScreenCaptureKit for all versions since CGWindowListCreateImage is deprecated
        return try await captureWithScreenCaptureKit(window: window)
    }
    
    @available(macOS 12.3, *)
    private func captureWithScreenCaptureKit(window: WindowID) async throws -> PNGData {
        #if canImport(ScreenCaptureKit)
        do {
            // Get shareable content
            let content = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SCShareableContent, Error>) in
                SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let content = content {
                        continuation.resume(returning: content)
                    } else {
                        continuation.resume(throwing: PilotError.OS_FAILURE(api: "ScreenCaptureKit", status: -1))
                    }
                }
            }
            
            // Find the window in the shareable content
            guard let scWindow = content.windows.first(where: { $0.windowID == window.id }) else {
                throw PilotError.NOT_FOUND(.window, "Window not found in shareable content")
            }
            
            // Create content filter with just this window
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            
            // Configure capture settings
            let config = SCStreamConfiguration()
            config.width = Int(scWindow.frame.width)
            config.height = Int(scWindow.frame.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.capturesAudio = false
            config.sampleRate = 0
            config.channelCount = 0
            
            // Capture the image
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            
            // Convert CGImage to PNG data
            guard let pngData = convertCGImageToPNG(image) else {
                throw PilotError.OS_FAILURE(api: "PNG_Conversion", status: -1)
            }
            
            return pngData
            
        } catch {
            throw PilotError.OS_FAILURE(api: "ScreenCaptureKit", status: -1)
        }
        #else
        throw PilotError.OS_FAILURE(api: "ScreenCaptureKit_NotAvailable", status: -1)
        #endif
    }
    
    private func convertCGImageToPNG(_ cgImage: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
    
    public func listWindows() async throws -> [Window] {
        // Get all windows using CGWindowListCopyWindowInfo
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw PilotError.OS_FAILURE(api: "CGWindowListCopyWindowInfo", status: -1)
        }
        
        var windows: [Window] = []
        
        for windowInfo in windowList {
            // Extract window properties
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }
            
            // Skip windows with layer != 0 (menu bars, dock, etc.)
            if let layer = windowInfo[kCGWindowLayer as String] as? Int, layer != 0 {
                continue
            }
            
            // Get window bounds
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Get window title (may be nil)
            let title = windowInfo[kCGWindowName as String] as? String
            
            // Check if minimized (not on screen but still in list)
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
            let isMinimized = !isOnScreen
            
            let window = Window(
                id: WindowID(id: windowID),
                title: title,
                frame: frame,
                isMinimized: isMinimized,
                app: AppID(pid: ownerPID)
            )
            
            windows.append(window)
        }
        
        return windows
    }
    
    public func listApplications() async throws -> [App] {
        // Use NSWorkspace to get running applications
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        var apps: [App] = []
        
        for runningApp in runningApps {
            // Skip background-only apps and agents
            if runningApp.activationPolicy == .prohibited {
                continue
            }
            
            let app = App(
                id: AppID(pid: runningApp.processIdentifier),
                name: runningApp.localizedName ?? "Unknown",
                bundleIdentifier: runningApp.bundleIdentifier
            )
            
            apps.append(app)
        }
        
        return apps
    }
    
    public func getWindowInfo(_ windowID: WindowID) async throws -> Window {
        // Get specific window info
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID.id) as? [[String: Any]],
              let windowInfo = windowList.first else {
            throw PilotError.NOT_FOUND(.window, "Window ID: \(windowID.id)")
        }
        
        // Extract window properties
        guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            throw PilotError.OS_FAILURE(api: "CGWindowListCopyWindowInfo", status: -1)
        }
        
        // Get window bounds
        guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            throw PilotError.OS_FAILURE(api: "CGWindowListCopyWindowInfo", status: -1)
        }
        
        let frame = CGRect(x: x, y: y, width: width, height: height)
        let title = windowInfo[kCGWindowName as String] as? String
        let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? true
        let isMinimized = !isOnScreen
        
        return Window(
            id: windowID,
            title: title,
            frame: frame,
            isMinimized: isMinimized,
            app: AppID(pid: ownerPID)
        )
    }
}