import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
import UniformTypeIdentifiers
@preconcurrency import ScreenCaptureKit

// MARK: - Screen Driver Protocol

public protocol ScreenDriver: Sendable {
    /// Capture the entire screen
    func captureScreen() async throws -> CGImage
    
    /// Capture all windows of a specific application
    func captureApplication(bundleId: String) async throws -> CGImage
    
    /// Capture a region of the screen
    func captureRegion(_ region: CGRect) async throws -> CGImage
    
    /// Check screen recording permission
    func checkScreenRecordingPermission() async -> Bool
    
    /// Request screen recording permission (opens System Settings)
    func requestScreenRecordingPermission() async throws
}

// MARK: - Screen Capture Utility Functions

public enum ScreenCaptureUtility {
    /// Convert CGImage to PNG data
    public static func convertToPNG(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    /// Convert CGImage to JPEG data with quality setting
    public static func convertToJPEG(_ image: CGImage, quality: CGFloat = 0.8) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    /// Save CGImage to file
    public static func saveToFile(_ image: CGImage, path: String, format: ImageFormat = .png) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        let utType: UTType
        switch format {
        case .png:
            utType = UTType.png
        case .jpeg:
            utType = UTType.jpeg
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    
    public enum ImageFormat {
        case png, jpeg
    }
}

// MARK: - Simple Screen Driver Implementation

public actor DefaultScreenDriver: ScreenDriver {
    
    public init() {}
    
    // MARK: - Public Interface
    
    public func captureScreen() async throws -> CGImage {
        guard await checkScreenRecordingPermission() else {
            throw ScreenCaptureError.permissionDenied
        }
        
        let content = try await getShareableContent()
        
        guard let mainDisplay = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = Int(mainDisplay.frame.width)
        config.height = Int(mainDisplay.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        
        return try await captureWithConfiguration(filter: filter, configuration: config)
    }
    
    public func captureApplication(bundleId: String) async throws -> CGImage {
        guard await checkScreenRecordingPermission() else {
            throw ScreenCaptureError.permissionDenied
        }
        
        let content = try await getShareableContent()
        
        guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw ScreenCaptureError.applicationNotFound(bundleId)
        }
        
        let windows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == bundleId && window.isOnScreen
        }
        
        guard !windows.isEmpty else {
            throw ScreenCaptureError.noWindowsFound(bundleId)
        }
        
        // Find the main display for the application
        guard let mainDisplay = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        // Create content filter for the application
        let filter = SCContentFilter(
            display: mainDisplay,
            including: [app],
            exceptingWindows: []
        )
        
        let config = SCStreamConfiguration()
        
        // Calculate optimal size from application windows
        let maxWindow = windows.max { w1, w2 in
            w1.frame.width * w1.frame.height < w2.frame.width * w2.frame.height
        }
        
        if let maxWindow = maxWindow {
            config.width = max(Int(maxWindow.frame.width), 800)
            config.height = max(Int(maxWindow.frame.height), 600)
        } else {
            config.width = 1920
            config.height = 1080
        }
        
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        
        return try await captureWithConfiguration(filter: filter, configuration: config)
    }
    
    public func captureRegion(_ region: CGRect) async throws -> CGImage {
        guard await checkScreenRecordingPermission() else {
            throw ScreenCaptureError.permissionDenied
        }
        
        let content = try await getShareableContent()
        
        guard let mainDisplay = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        // Validate region bounds
        let displayBounds = mainDisplay.frame
        let clampedRegion = CGRect(
            x: max(0, min(region.origin.x, displayBounds.width)),
            y: max(0, min(region.origin.y, displayBounds.height)),
            width: max(1, min(region.width, displayBounds.width - region.origin.x)),
            height: max(1, min(region.height, displayBounds.height - region.origin.y))
        )
        
        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = Int(clampedRegion.width)
        config.height = Int(clampedRegion.height)
        config.sourceRect = clampedRegion
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        
        return try await captureWithConfiguration(filter: filter, configuration: config)
    }
    
    public func checkScreenRecordingPermission() async -> Bool {
        // Check if ScreenCaptureKit is available (macOS 12.3+)
        guard #available(macOS 12.3, *) else {
            return false
        }
        
        // Try to get shareable content - this will fail if permission is denied
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }
    
    public func requestScreenRecordingPermission() async throws {
        // Open System Settings to Screen Recording section
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
        
        throw ScreenCaptureError.permissionDenied
    }
    
    // MARK: - Private Implementation Methods
    
    private func captureWithConfiguration(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            if let scError = error as? SCStreamError {
                switch scError.code {
                case .userDeclined:
                    throw ScreenCaptureError.permissionDenied
                default:
                    throw ScreenCaptureError.captureFailed
                }
            }
            throw ScreenCaptureError.captureFailed
        }
    }
    
    private func getShareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCaptureError.screenCaptureKitUnavailable
        }
    }
}

// MARK: - Error Types

public enum ScreenCaptureError: Error, LocalizedError, Sendable {
    case applicationNotFound(String)
    case noWindowsFound(String)
    case noDisplayFound
    case captureFailed
    case permissionDenied
    case screenCaptureKitUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let bundleId):
            return "Application with bundle ID '\(bundleId)' not found or not running"
        case .noWindowsFound(let identifier):
            return "No visible windows found for '\(identifier)'"
        case .noDisplayFound:
            return "No display found for capture"
        case .captureFailed:
            return "Failed to capture screen"
        case .permissionDenied:
            return "Screen recording permission denied. Please grant access in System Settings > Privacy & Security > Screen Recording"
        case .screenCaptureKitUnavailable:
            return "ScreenCaptureKit is not available or failed to initialize"
        }
    }
}
