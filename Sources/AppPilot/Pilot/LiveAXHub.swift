import Foundation

public actor LiveAXHub {
    private let accessibilityDriver: AccessibilityDriver
    private let bufferSize = 256
    
    private struct StreamInfo {
        let window: WindowID
        let mask: AXMask
        let continuation: AsyncStream<AXEvent>.Continuation
        var eventCount: Int = 0
    }
    
    private var activeStreams: [UUID: StreamInfo] = [:]
    private var windowObservers: [WindowID: Set<UUID>] = [:]
    
    public init(accessibilityDriver: AccessibilityDriver) {
        self.accessibilityDriver = accessibilityDriver
    }
    
    public func subscribe(to window: WindowID, mask: AXMask = .all) -> AsyncStream<AXEvent> {
        let streamID = UUID()
        
        return AsyncStream(bufferingPolicy: .bufferingNewest(bufferSize)) { continuation in
            Task {
                self.registerStream(streamID, window: window, mask: mask, continuation: continuation)
                
                continuation.onTermination = { _ in
                    Task {
                        await self.unregisterStream(streamID)
                    }
                }
                
                // Start observing if this is the first subscriber for this window
                if self.isFirstSubscriber(for: window) {
                    self.startObserving(window: window)
                }
            }
        }
    }
    
    private func registerStream(
        _ id: UUID,
        window: WindowID,
        mask: AXMask,
        continuation: AsyncStream<AXEvent>.Continuation
    ) {
        let info = StreamInfo(window: window, mask: mask, continuation: continuation)
        activeStreams[id] = info
        
        var observers = windowObservers[window] ?? Set<UUID>()
        observers.insert(id)
        windowObservers[window] = observers
    }
    
    private func unregisterStream(_ id: UUID) {
        guard let info = activeStreams[id] else { return }
        
        activeStreams[id] = nil
        
        if var observers = windowObservers[info.window] {
            observers.remove(id)
            if observers.isEmpty {
                windowObservers[info.window] = nil
                // Stop observing if no more subscribers
                Task {
                    self.stopObserving(window: info.window)
                }
            } else {
                windowObservers[info.window] = observers
            }
        }
    }
    
    private func isFirstSubscriber(for window: WindowID) -> Bool {
        return (windowObservers[window]?.count ?? 0) == 1
    }
    
    private func startObserving(window: WindowID) {
        // Create a stream from the driver
        Task {
            let driverStream = await accessibilityDriver.observeEvents(for: window, mask: .all)
            for await event in driverStream {
                self.distributeEvent(event)
            }
        }
    }
    
    private func stopObserving(window: WindowID) {
        // Driver will handle cleanup when stream is cancelled
    }
    
    private func distributeEvent(_ event: AXEvent) {
        let window = event.window
        guard let observerIDs = windowObservers[window] else { return }
        
        for id in observerIDs {
            guard var info = activeStreams[id] else { continue }
            
            // Check if this stream is interested in this event type
            if shouldSendEvent(event, mask: info.mask) {
                info.eventCount += 1
                
                // Send event or overflow if buffer is full
                let result = info.continuation.yield(event)
                
                if case .terminated = result {
                    // Stream was terminated
                    activeStreams[id] = nil
                } else if info.eventCount > bufferSize {
                    // Send overflow event
                    let overflowEvent = AXEvent(
                        type: .overflow,
                        window: window,
                        timestamp: Date()
                    )
                    info.continuation.yield(overflowEvent)
                    info.eventCount = 0
                }
                
                activeStreams[id] = info
            }
        }
    }
    
    private func shouldSendEvent(_ event: AXEvent, mask: AXMask) -> Bool {
        switch event.type {
        case .created:
            return mask.contains(.created)
        case .moved:
            return mask.contains(.moved)
        case .resized:
            return mask.contains(.resized)
        case .titleChanged:
            return mask.contains(.titleChanged)
        case .focusChanged:
            return mask.contains(.focusChanged)
        case .valueChanged:
            return mask.contains(.valueChanged)
        case .overflow:
            return true // Always send overflow events
        }
    }
}
