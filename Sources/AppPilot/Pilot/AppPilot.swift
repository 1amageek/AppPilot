import Foundation

public actor AppPilot {
    private let commandRouter: CommandRouter
    private let visibilityManager: VisibilityManager
    private let spaceController: SpaceController
    private let liveAXHub: LiveAXHub
    private let screenDriver: ScreenDriver
    private let accessibilityDriver: AccessibilityDriver
    private let coordinateConverter: CoordinateConverter
    
    public init(
        appleEventDriver: AppleEventDriver? = nil,
        accessibilityDriver: AccessibilityDriver? = nil,
        uiEventDriver: UIEventDriver? = nil,
        screenDriver: ScreenDriver? = nil,
        missionControlDriver: MissionControlDriver? = nil
    ) {
        let aeDriver = appleEventDriver ?? DefaultAppleEventDriver()
        let axDriver = accessibilityDriver ?? DefaultAccessibilityDriver()
        let uiDriver = uiEventDriver ?? DefaultUIEventDriver()
        let scrDriver = screenDriver ?? DefaultScreenDriver()
        let mcDriver = missionControlDriver ?? DefaultMissionControlDriver()
        
        self.commandRouter = CommandRouter(
            appleEventDriver: aeDriver,
            accessibilityDriver: axDriver,
            uiEventDriver: uiDriver
        )
        self.visibilityManager = VisibilityManager(
            accessibilityDriver: axDriver,
            missionControlDriver: mcDriver
        )
        self.spaceController = SpaceController(
            missionControlDriver: mcDriver
        )
        self.liveAXHub = LiveAXHub(
            accessibilityDriver: axDriver
        )
        self.screenDriver = scrDriver
        self.accessibilityDriver = axDriver
        self.coordinateConverter = CoordinateConverter()
    }
    
    // MARK: - Query Methods
    
    public func listApplications() async throws -> [App] {
        return try await screenDriver.listApplications()
    }
    
    public func listWindows(in app: AppID) async throws -> [Window] {
        let allWindows = try await screenDriver.listWindows()
        return allWindows.filter { $0.app == app }
    }
    
    public func capture(window: WindowID) async throws -> PNGData {
        return try await screenDriver.capture(window: window)
    }
    
    public func accessibilityTree(window: WindowID, depth: Int = 10) async throws -> AXNode {
        return try await accessibilityDriver.getTree(for: window, depth: depth)
    }
    
    public func subscribeAX(window: WindowID, mask: AXMask = .all) async -> AsyncStream<AXEvent> {
        return await liveAXHub.subscribe(to: window, mask: mask)
    }
    
    // MARK: - Command Methods
    
    public func click(
        window: WindowID,
        at point: Point,
        button: MouseButton = .left,
        count: Int = 1,
        policy: Policy = .UNMINIMIZE(),
        route: Route? = nil
    ) async throws -> ActionResult {
        let command = ClickCommand(
            window: window,
            point: point,
            button: button,
            count: count,
            policy: policy,
            route: route
        )
        
        return try await executeCommand(command)
    }
    
    public func type(
        text: String,
        into window: WindowID,
        policy: Policy = .STAY_HIDDEN,
        route: Route? = nil
    ) async throws -> ActionResult {
        let command = TypeCommand(
            text: text,
            window: window,
            policy: policy,
            route: route
        )
        
        return try await executeCommand(command)
    }
    
    public func gesture(
        window: WindowID,
        _ gesture: Gesture,
        policy: Policy = .UNMINIMIZE(),
        durationMs: Int = 150
    ) async throws -> ActionResult {
        let command = GestureCommand(
            window: window,
            gesture: gesture,
            policy: policy,
            durationMs: durationMs
        )
        
        return try await executeCommand(command)
    }
    
    public func performAX(
        window: WindowID,
        path: AXPath,
        action: AXAction
    ) async throws -> ActionResult {
        let command = AXCommand(
            window: window,
            path: path,
            action: action
        )
        
        return try await executeCommand(command)
    }
    
    public func sendAppleEvent(
        app: AppID,
        spec: AppleEventSpec
    ) async throws -> ActionResult {
        let command = AppleEventCommand(
            app: app,
            spec: spec
        )
        
        return try await executeCommand(command)
    }
    
    public func wait(_ spec: WaitSpec) async throws {
        switch spec {
        case .time(let ms):
            try await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            
        case .ui_change(let window, let timeoutMs):
            let stream = await subscribeAX(window: window, mask: .all)
            let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
            
            for await _ in stream {
                if Date() > deadline {
                    throw PilotError.TIMEOUT(ms: timeoutMs)
                }
                // Got a UI change event
                break
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func executeCommand(_ command: Command) async throws -> ActionResult {
        // Determine window and app for the command
        let (window, app) = extractTargets(from: command)
        
        // Select route
        let route = await commandRouter.selectRoute(for: command, app: app, window: window)
        
        // Prepare visibility if needed
        if route == .UI_EVENT {
            if let window = window, let policy = extractPolicy(from: command) {
                try await visibilityManager.prepareWindow(window, policy: policy)
            }
        }
        
        // Execute with fallback
        do {
            return try await commandRouter.execute(command, with: route)
        } catch {
            // Try fallback routes
            let fallbackRoutes = getFallbackRoutes(for: route)
            
            for fallbackRoute in fallbackRoutes {
                do {
                    if fallbackRoute == .UI_EVENT, let window = window, let policy = extractPolicy(from: command) {
                        try await visibilityManager.prepareWindow(window, policy: policy)
                    }
                    return try await commandRouter.execute(command, with: fallbackRoute)
                } catch {
                    continue
                }
            }
            
            throw PilotError.ROUTE_UNAVAILABLE("All routes failed: \(error)")
        }
    }
    
    private func extractTargets(from command: Command) -> (window: WindowID?, app: AppID?) {
        switch command {
        case let cmd as ClickCommand:
            return (cmd.window, nil)
        case let cmd as TypeCommand:
            return (cmd.window, nil)
        case let cmd as GestureCommand:
            return (cmd.window, nil)
        case let cmd as AXCommand:
            return (cmd.window, nil)
        case let cmd as AppleEventCommand:
            return (nil, cmd.app)
        default:
            return (nil, nil)
        }
    }
    
    private func extractPolicy(from command: Command) -> Policy? {
        switch command {
        case let cmd as ClickCommand:
            return cmd.policy
        case let cmd as TypeCommand:
            return cmd.policy
        case let cmd as GestureCommand:
            return cmd.policy
        default:
            return nil
        }
    }
    
    private func getFallbackRoutes(for route: Route) -> [Route] {
        switch route {
        case .APPLE_EVENT:
            return [.AX_ACTION, .UI_EVENT]
        case .AX_ACTION:
            return [.UI_EVENT]
        case .UI_EVENT:
            return []
        }
    }
}