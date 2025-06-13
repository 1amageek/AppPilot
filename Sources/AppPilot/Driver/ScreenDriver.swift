//
//  ScreenDriver.swift
//  AppPilot
//
//  Created by Norikazu Muramoto on 2025-06-09.
//  Revised to fix a CGS_REQUIRE_INIT assertion when using
//  SCContentFilter(desktopIndependentWindow:) from a non-GUI context.
//

import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
import UniformTypeIdentifiers
@preconcurrency import ScreenCaptureKit

// MARK: - Screen Driver Protocol
public protocol ScreenDriver: Sendable {
    func captureScreen()                          async throws -> CGImage
    func captureApplication(bundleId: String)     async throws -> CGImage
    func captureWindow(windowID: UInt32)          async throws -> CGImage
    func findWindowID(title: String?,
                      bundleIdentifier: String?,
                      bounds: CGRect,
                      onScreenOnly: Bool)        async throws -> UInt32?
    func captureRegion(_ region: CGRect)          async throws -> CGImage
    func checkScreenRecordingPermission()         async -> Bool
    func requestScreenRecordingPermission()       async throws
    func getShareableContent(onScreenWindowsOnly: Bool) async throws -> SCShareableContent
}

// MARK: - Utility
public enum ScreenCaptureUtility {
    public enum ImageFormat { case png, jpeg }
    
    public static func convertToPNG(_ image: CGImage) -> Data? {
        convert(image, as: .png)
    }
    
    public static func convertToJPEG(_ image: CGImage,
                                     quality: CGFloat = 0.8) -> Data? {
        convert(image, as: .jpeg,
                options: [kCGImageDestinationLossyCompressionQuality: quality])
    }
    
    public static func saveToFile(_ image: CGImage,
                                  path: String,
                                  format: ImageFormat = .png) -> Bool {
        let url     = URL(fileURLWithPath: path)
        let utType  = format == .png ? UTType.png : UTType.jpeg
        guard
            let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                       utType.identifier as CFString,
                                                       1, nil)
        else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }
    
    // MARK: - Private
    private static func convert(_ image: CGImage,
                                as format: ImageFormat,
                                options: [CFString: Any]? = nil) -> Data? {
        let md = NSMutableData()
        let utType = format == .png ? UTType.png : UTType.jpeg
        guard
            let dest = CGImageDestinationCreateWithData(
                md, utType.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, options as CFDictionary?)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return md as Data
    }
}

// MARK: - Default Implementation
public actor DefaultScreenDriver: ScreenDriver {
    
    // MARK: CGS bootstrap (fixes CGS_REQUIRE_INIT)
    private static var didBootstrapCGS = false
    private static func bootstrapCGSIfNeeded() {
        guard !didBootstrapCGS else { return }
        _ = CGMainDisplayID()              // triggers CGS initialisation
        didBootstrapCGS = true
    }
    
    // MARK: Lifecycle
    public init() {
        Self.bootstrapCGSIfNeeded()
    }
    
    // MARK: Public API
    public func captureScreen() async throws -> CGImage {
        try await ensurePermission()
        let content     = try await getShareableContentInternal(onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        let (resizedWidth, resizedHeight) = calculateResizedDimensions(
            originalWidth: display.frame.width,
            originalHeight: display.frame.height,
            maxSize: 480
        )
        
        let filter      = SCContentFilter(display: display,
                                          excludingWindows: [])
        let config      = SCStreamConfiguration()
        config.width    = resizedWidth
        config.height   = resizedHeight
        config.pixelFormat       = kCVPixelFormatType_32BGRA
        config.showsCursor       = false
        config.capturesAudio     = false
        
        return try await capture(filter: filter, config: config)
    }
    
    public func captureApplication(bundleId: String) async throws -> CGImage {
        try await ensurePermission()
        let content = try await getShareableContentInternal(onScreenWindowsOnly: false)
        
        guard let app = content.applications
            .first(where: { $0.bundleIdentifier == bundleId })
        else { throw ScreenCaptureError.applicationNotFound(bundleId) }
        
        let appWindows = content.windows
            .filter { $0.owningApplication?.bundleIdentifier == bundleId }
        guard !appWindows.isEmpty else {
            throw ScreenCaptureError.noWindowsFound(bundleId)
        }
        
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        let filter   = SCContentFilter(display: display,
                                       including: [app],
                                       exceptingWindows: [])
        
        let (w, h)   = appWindows
            .max { $0.frame.area < $1.frame.area }
            .map { (Int($0.frame.width), Int($0.frame.height)) } ?? (1920, 1080)
        
        let (resizedWidth, resizedHeight) = calculateResizedDimensions(
            originalWidth: CGFloat(w),
            originalHeight: CGFloat(h),
            maxSize: 480
        )
        
        let config   = SCStreamConfiguration()
        config.width            = resizedWidth
        config.height           = resizedHeight
        config.pixelFormat      = kCVPixelFormatType_32BGRA
        config.showsCursor      = false
        config.capturesAudio    = false
        
        return try await capture(filter: filter, config: config)
    }
    
    public func captureWindow(windowID: UInt32) async throws -> CGImage {
        try await ensurePermission()
        let content = try await getShareableContentInternal(onScreenWindowsOnly: false)
        
        guard let targetWindow = content.windows
            .first(where: { $0.windowID == windowID })
        else { throw ScreenCaptureError.noWindowsFound("windowID: \(windowID)") }
        
        // Build SCContentFilter on the main actor to avoid CGS_REQUIRE_INIT
        let filter = await MainActor.run {
            SCContentFilter(desktopIndependentWindow: targetWindow)
        }
        
        let (resizedWidth, resizedHeight) = calculateResizedDimensions(
            originalWidth: targetWindow.frame.width,
            originalHeight: targetWindow.frame.height,
            maxSize: 480
        )
        
        let config  = SCStreamConfiguration()
        config.width            = resizedWidth
        config.height           = resizedHeight
        config.pixelFormat      = kCVPixelFormatType_32BGRA
        config.showsCursor      = false
        config.capturesAudio    = false
        
        return try await capture(filter: filter, config: config)
    }
    
    public func findWindowID(title: String?,
                             bundleIdentifier: String?,
                             bounds: CGRect,
                             onScreenOnly: Bool) async throws -> UInt32? {
        let content = try await getShareableContentInternal(onScreenWindowsOnly: onScreenOnly)
        return content.windows
            .first(where: { w in
                (title == nil  || w.title == title) &&
                (bundleIdentifier == nil ||
                 w.owningApplication?.bundleIdentifier == bundleIdentifier) &&
                w.frame.isAlmostEqual(to: bounds, tolerance: 10)
            })?.windowID
    }
    
    public func captureRegion(_ region: CGRect) async throws -> CGImage {
        try await ensurePermission()
        let content          = try await getShareableContentInternal(onScreenWindowsOnly: false)
        guard let display    = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        let displayBounds    = display.frame
        let r                = region.clamped(to: displayBounds)
        
        let filter           = SCContentFilter(display: display,
                                               excludingWindows: [])
        let config           = SCStreamConfiguration()
        config.width         = Int(r.width)
        config.height        = Int(r.height)
        config.sourceRect    = r
        config.pixelFormat   = kCVPixelFormatType_32BGRA
        config.showsCursor   = false
        config.capturesAudio = false
        
        return try await capture(filter: filter, config: config)
    }
    
    public func checkScreenRecordingPermission() async -> Bool {
        guard #available(macOS 12.3, *) else { return false }
        do {
            _ = try await SCShareableContent
                .excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            return false
        }
    }
    
    public func requestScreenRecordingPermission() async throws {
        let url = URL(
            string:"x-apple.systempreferences:"
            + "com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
        throw ScreenCaptureError.permissionDenied
    }
    
    public func getShareableContent(onScreenWindowsOnly: Bool) async throws -> SCShareableContent {
        try await getShareableContentInternal(onScreenWindowsOnly: onScreenWindowsOnly)
    }
    
    // MARK: - Private Helpers
    private func ensurePermission() async throws {
        guard await checkScreenRecordingPermission() else {
            throw ScreenCaptureError.permissionDenied
        }
    }
    
    private func calculateResizedDimensions(
        originalWidth: CGFloat,
        originalHeight: CGFloat,
        maxSize: Int = 480
    ) -> (width: Int, height: Int) {
        let maxDimension = max(originalWidth, originalHeight)
        if maxDimension <= CGFloat(maxSize) {
            // 既に最大サイズ以下の場合はそのまま
            return (max(Int(originalWidth), 100), max(Int(originalHeight), 100))
        }
        
        let scale = CGFloat(maxSize) / maxDimension
        return (
            width: max(Int(originalWidth * scale), 100),
            height: max(Int(originalHeight * scale), 100)
        )
    }
    
    @MainActor
    private func capture(filter: SCContentFilter,
                         config: SCStreamConfiguration) async throws -> CGImage {
        do {
            return try await SCScreenshotManager
                .captureImage(contentFilter: filter, configuration: config)
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw ScreenCaptureError.permissionDenied
        } catch {
            throw ScreenCaptureError.captureFailed
        }
    }
    
    private func getShareableContentInternal(onScreenWindowsOnly: Bool) async throws -> SCShareableContent {
        do {
            return try await SCShareableContent
                .excludingDesktopWindows(false, onScreenWindowsOnly: onScreenWindowsOnly)
        } catch {
            throw ScreenCaptureError.screenCaptureKitUnavailable
        }
    }
}

// MARK: - Error Definitions
public enum ScreenCaptureError: Error, LocalizedError, Sendable {
    case applicationNotFound(String)
    case noWindowsFound(String)
    case noDisplayFound
    case captureFailed
    case permissionDenied
    case screenCaptureKitUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let id):
            return "Application with bundle ID “\(id)” not found or not running."
        case .noWindowsFound(let id):
            return "No visible windows found for “\(id)”."
        case .noDisplayFound:
            return "No display found for capture."
        case .captureFailed:
            return "Failed to capture screen."
        case .permissionDenied:
            return "Screen recording permission denied. " +
            "Grant access in System Settings › Privacy & Security › Screen Recording."
        case .screenCaptureKitUnavailable:
            return "ScreenCaptureKit is not available or failed to initialise."
        }
    }
}

// MARK: - CGRect helpers (private)
fileprivate extension CGRect {
    var area: CGFloat { width * height }
    
    func clamped(to bounds: CGRect) -> CGRect {
        CGRect(
            x: max(bounds.minX, min(maxX, bounds.maxX - width)),
            y: max(bounds.minY, min(maxY, bounds.maxY - height)),
            width: min(width, bounds.width),
            height: min(height, bounds.height)
        )
    }
    
    func isAlmostEqual(to other: CGRect, tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) < tolerance &&
        abs(minY - other.minY) < tolerance &&
        abs(width - other.width) < tolerance &&
        abs(height - other.height) < tolerance
    }
}
