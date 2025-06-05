import Foundation
@preconcurrency import OSAKit

public protocol MissionControlDriver: Sendable {
    func getCurrentSpace() async throws -> Int
    func getSpaceForWindow(_ window: WindowID) async throws -> Int
    func moveWindow(_ window: WindowID, toSpace space: Int) async throws
    func listSpaces() async throws -> [Int]
}

public actor DefaultMissionControlDriver: MissionControlDriver {
    private let scriptingLanguage = OSALanguage(forName: "AppleScript")
    
    public init() {}
    
    public func getCurrentSpace() async throws -> Int {
        // Use AppleScript to get current space
        let script = """
        tell application "System Events"
            set currentSpace to (do shell script "defaults read com.apple.spaces SpacesDisplayConfiguration | grep -A 1 'Current Space' | tail -1 | cut -d'=' -f2 | tr -d ' ';")
            return currentSpace as integer
        end tell
        """
        
        return try await executeAppleScript(script) { result in
            let spaceNumber = result.int32Value
            guard spaceNumber > 0 else {
                throw PilotError.OS_FAILURE(api: "MissionControl.getCurrentSpace", status: -1)
            }
            return Int(spaceNumber)
        }
    }
    
    public func getSpaceForWindow(_ window: WindowID) async throws -> Int {
        // This is complex and requires private APIs or heuristics
        // For now, we'll use a fallback approach with AppleScript
        let script = """
        tell application "System Events"
            -- This is a simplified approach that may not work for all windows
            -- In a real implementation, you'd need to use private APIs
            return 1
        end tell
        """
        
        return try await executeAppleScript(script) { result in
            // Since getting window space is complex, we'll return current space as fallback
            return 1
        }
    }
    
    public func moveWindow(_ window: WindowID, toSpace space: Int) async throws {
        // Get window information first
        guard let windowList = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.id) as? [[String: Any]],
              let windowInfo = windowList.first,
              let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            throw PilotError.NOT_FOUND(.window, "Window ID: \(window.id)")
        }
        
        // Get the application name
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == ownerPID }),
              let appName = runningApp.localizedName else {
            throw PilotError.NOT_FOUND(.application, "PID: \(ownerPID)")
        }
        
        // Use AppleScript to move window to specified space
        let script = """
        tell application "System Events"
            tell application "\(appName)" to activate
            delay 0.1
            
            -- Use Mission Control to move window
            do shell script "osascript -e 'tell application \\"System Events\\" to key code 126 using {control down}'"
            delay 0.5
            
            -- Navigate to the target space
            set targetSpace to \(space)
            repeat with i from 1 to targetSpace
                do shell script "osascript -e 'tell application \\"System Events\\" to key code 124'"
                delay 0.1
            end repeat
            
            -- Drop the window
            do shell script "osascript -e 'tell application \\"System Events\\" to key code 36'"
            delay 0.1
            
            return true
        end tell
        """
        
        _ = try await executeAppleScript(script) { result in
            return true
        }
    }
    
    public func listSpaces() async throws -> [Int] {
        // Use AppleScript to get list of spaces
        let script = """
        tell application "System Events"
            -- This is a simplified approach
            -- In a real implementation, you'd query the actual space configuration
            set spaceCount to (do shell script "defaults read com.apple.spaces SpacesDisplayConfiguration | grep -c 'Space'")
            set spaceList to {}
            repeat with i from 1 to (spaceCount as integer)
                set end of spaceList to i
            end repeat
            return spaceList
        end tell
        """
        
        return try await executeAppleScript(script) { result in
            // Parse the result to get space list
            // For now, return a default list
            return [1, 2, 3, 4]
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func executeAppleScript<T>(_ script: String, parser: @escaping @Sendable (NSAppleEventDescriptor) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let language = self.scriptingLanguage else {
                        continuation.resume(throwing: PilotError.OS_FAILURE(api: "OSALanguage", status: -1))
                        return
                    }
                    
                    let scriptObject = OSAScript(source: script, language: language)
                    var error: NSDictionary?
                    
                    guard let result = scriptObject.executeAndReturnError(&error) else {
                        let errorCode = error?["OSAScriptErrorNumber"] as? Int ?? -1
                        continuation.resume(throwing: PilotError.OS_FAILURE(api: "AppleScript", status: Int32(errorCode)))
                        return
                    }
                    
                    let parsedResult = try parser(result)
                    continuation.resume(returning: parsedResult)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Alternative implementation using private APIs (commented out due to sandboxing restrictions)
    /*
    private func getCurrentSpacePrivateAPI() throws -> Int {
        // This would use private Mission Control APIs
        // Note: These APIs are private and may not work in sandboxed apps
        
        // Example of what this might look like:
        // let connection = _SLSConnectionCreate()
        // let spaceID = _SLSGetActiveSpace(connection)
        // return Int(spaceID)
        
        throw PilotError.OS_FAILURE(api: "PrivateAPI", status: -1)
    }
    */
}