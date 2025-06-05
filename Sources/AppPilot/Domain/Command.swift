import Foundation

public protocol Command: Sendable {
    var kind: CommandKind { get }
}

public enum CommandKind: Sendable {
    case click
    case type
    case gesture
    case axAction
    case appleEvent
}

public struct ClickCommand: Command {
    public let kind = CommandKind.click
    public let window: WindowID
    public let point: Point
    public let button: MouseButton
    public let count: Int
    public let policy: Policy
    public let route: Route?
    
    public init(window: WindowID, point: Point, button: MouseButton = .left, 
                count: Int = 1, policy: Policy = .UNMINIMIZE(), route: Route? = nil) {
        self.window = window
        self.point = point
        self.button = button
        self.count = count
        self.policy = policy
        self.route = route
    }
}

public struct TypeCommand: Command {
    public let kind = CommandKind.type
    public let text: String
    public let window: WindowID
    public let policy: Policy
    public let route: Route?
    
    public init(text: String, window: WindowID, policy: Policy = .STAY_HIDDEN, route: Route? = nil) {
        self.text = text
        self.window = window
        self.policy = policy
        self.route = route
    }
}

public struct GestureCommand: Command {
    public let kind = CommandKind.gesture
    public let window: WindowID
    public let gesture: Gesture
    public let policy: Policy
    public let durationMs: Int
    
    public init(window: WindowID, gesture: Gesture, policy: Policy = .UNMINIMIZE(), durationMs: Int = 150) {
        self.window = window
        self.gesture = gesture
        self.policy = policy
        self.durationMs = durationMs
    }
}

public struct AXCommand: Command {
    public let kind = CommandKind.axAction
    public let window: WindowID
    public let path: AXPath
    public let action: AXAction
    
    public init(window: WindowID, path: AXPath, action: AXAction) {
        self.window = window
        self.path = path
        self.action = action
    }
}

public struct AppleEventCommand: Command {
    public let kind = CommandKind.appleEvent
    public let app: AppID
    public let spec: AppleEventSpec
    
    public init(app: AppID, spec: AppleEventSpec) {
        self.app = app
        self.spec = spec
    }
}