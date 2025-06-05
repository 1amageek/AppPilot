import Foundation
import ApplicationServices
import AppKit
@preconcurrency import OSAKit

public protocol AppleEventDriver: Sendable {
    func send(_ spec: AppleEventSpec, to app: AppID) async throws
    func supports(_ command: Command, for app: AppID) async -> Bool
}

public actor DefaultAppleEventDriver: AppleEventDriver {
    private let knownScriptableApps: Set<String>
    
    public init() {
        // Initialize known scriptable applications
        self.knownScriptableApps = Set([
            "com.apple.finder",
            "com.apple.mail",
            "com.apple.Safari",
            "com.apple.TextEdit",
            "com.apple.systempreferences",
            "com.apple.Music",
            "com.apple.Photos",
            "com.apple.Calendar",
            "com.apple.Contacts",
            "com.microsoft.Word",
            "com.microsoft.Excel",
            "com.microsoft.PowerPoint",
            "com.adobe.Photoshop",
            "com.adobe.Illustrator",
            "com.sublimetext.4",
            "com.microsoft.VSCode",
            "com.panic.Coda2",
            "com.barebones.bbedit",
            "com.omnigroup.OmniGraffle7",
            "com.omnigroup.OmniFocus3",
            "com.1password.1password7",
            "com.flexibits.fantastical2.mac"
        ])
    }
    
    public func send(_ spec: AppleEventSpec, to app: AppID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create the Apple Event descriptor
                let eventClass = FourCharCode(spec.eventClass.fourCharCodeValue)
                let eventID = FourCharCode(spec.eventID.fourCharCodeValue)
                
                let event = NSAppleEventDescriptor(
                    eventClass: AEEventClass(eventClass),
                    eventID: AEEventID(eventID),
                    targetDescriptor: NSAppleEventDescriptor(processIdentifier: app.pid),
                    returnID: AEReturnID(kAutoGenerateReturnID),
                    transactionID: AETransactionID(kAnyTransactionID)
                )
                
                // Add parameters if provided
                if let parameters = spec.parameters {
                    parameters.forEach { key, value in
                        // Convert parameter key to proper AE keyword
                        let keyword = Self.convertToAEKeyword(key)
                        let valueDesc = NSAppleEventDescriptor(string: value)
                        event.setDescriptor(valueDesc, forKeyword: keyword)
                    }
                }
                
                // Send the event with timeout
                do {
                    let reply = try event.sendEvent(
                        options: NSAppleEventDescriptor.SendOptions.waitForReply,
                        timeout: 30
                    )
                    
                    // Check for errors in the reply
                    if let errorNumber = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value,
                       errorNumber != 0 {
                        continuation.resume(throwing: PilotError.OS_FAILURE(api: "AppleEvent", status: errorNumber))
                        return
                    }
                    
                    // Success
                    continuation.resume(returning: ())
                    
                } catch let nsError as NSError {
                    // Handle NSError from sendEvent
                    continuation.resume(throwing: PilotError.OS_FAILURE(api: "AppleEvent.send", status: Int32(nsError.code)))
                }
            }
        }
    }
    
    public func supports(_ command: Command, for app: AppID) async -> Bool {
        // Check if the command type is supported by AppleEvents
        switch command.kind {
        case .appleEvent:
            return true
        case .click, .type:
            // Some apps support click/type via AppleEvents, but it's limited
            return await checkAppleScriptSupport(for: app)
        case .gesture, .axAction:
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func checkAppleScriptSupport(for app: AppID) async -> Bool {
        // First check if app is in known scriptable apps list
        if await isKnownScriptableApp(app) {
            return true
        }
        
        // Then check for scripting dictionary
        if await hasScriptingDictionary(for: app) {
            return true
        }
        
        // Finally, try a simple test AppleEvent (with timeout)
        return await testAppleEventSupport(for: app)
    }
    
    private func isKnownScriptableApp(_ app: AppID) async -> Bool {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.pid }),
              let bundleIdentifier = runningApp.bundleIdentifier else {
            return false
        }
        
        return knownScriptableApps.contains(bundleIdentifier)
    }
    
    private func hasScriptingDictionary(for app: AppID) async -> Bool {
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == app.pid }),
              let appURL = runningApp.bundleURL else {
            return false
        }
        
        // Look for scripting dictionary in the app bundle
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources")
        let appName = appURL.deletingPathExtension().lastPathComponent
        
        // Common scripting dictionary file names
        let dictionaryNames = [
            "Scripting.sdef",
            "Dictionary.sdef",
            "\(appName).sdef",
            "\(appName)Scripting.sdef"
        ]
        
        for dictionaryName in dictionaryNames {
            let dictionaryURL = resourcesURL.appendingPathComponent(dictionaryName)
            if FileManager.default.fileExists(atPath: dictionaryURL.path) {
                return true
            }
        }
        
        // Also check for legacy .scriptSuite files
        let scriptSuiteURL = resourcesURL.appendingPathComponent("\(appName).scriptSuite")
        return FileManager.default.fileExists(atPath: scriptSuiteURL.path)
    }
    
    private func testAppleEventSupport(for app: AppID) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create a simple "get data" event to test responsiveness
                let event = NSAppleEventDescriptor(
                    eventClass: AEEventClass(kCoreEventClass),
                    eventID: AEEventID(kAEGetData),
                    targetDescriptor: NSAppleEventDescriptor(processIdentifier: app.pid),
                    returnID: AEReturnID(kAutoGenerateReturnID),
                    transactionID: AETransactionID(kAnyTransactionID)
                )
                
                do {
                    // Send with very short timeout for testing
                    let _ = try event.sendEvent(
                        options: NSAppleEventDescriptor.SendOptions.waitForReply,
                        timeout: 2 // Short timeout for testing
                    )
                    continuation.resume(returning: true)
                } catch {
                    // If it fails, the app likely doesn't support AppleEvents
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private static func convertToAEKeyword(_ key: String) -> AEKeyword {
        // Convert common parameter names to AE keywords
        switch key.lowercased() {
        case "direct", "----":
            return AEKeyword(keyDirectObject)
        case "data":
            return AEKeyword(keyAEData)
        case "to", "target":
            return AEKeyword(keyAETarget)
        case "with", "properties":
            return AEKeyword(keyAEProperties)
        case "saving", "savein":
            return AEKeyword(keyAESaveOptions)
        default:
            // For custom keys, try to convert string to fourCharCode
            return AEKeyword(key.fourCharCodeValue)
        }
    }
}

// MARK: - Extensions

// Extension to convert string to FourCharCode
private extension String {
    var fourCharCodeValue: UInt32 {
        let chars = Array(self.prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0))
        return chars.reduce(0) { result, char in
            (result << 8) + UInt32(char.asciiValue ?? 32) // Use space (32) as default
        }
    }
}

// Standard AppleEvent constants
private let kCoreEventClass: FourCharCode = 0x636F7265 // 'core'
private let kAEGetData: FourCharCode = 0x67657464     // 'getd'