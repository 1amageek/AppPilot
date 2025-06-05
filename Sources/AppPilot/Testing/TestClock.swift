import Foundation

/// A test clock that allows controlling time flow for deterministic testing
public actor TestClock: @unchecked Sendable {
    private var currentTime: TimeInterval = 0
    private var tasks: [TaskInfo] = []
    
    public init(startTime: TimeInterval = 0) {
        self.currentTime = startTime
    }
    
    /// Get the current time
    public var time: TimeInterval {
        currentTime
    }
    
    /// Advance time by the specified interval and execute any pending tasks
    public func advance(by interval: TimeInterval) async {
        currentTime += interval
        
        // Execute tasks that should complete
        var completedTasks: [TaskInfo] = []
        
        for task in tasks {
            if task.scheduledTime <= currentTime {
                completedTasks.append(task)
                task.continuation.resume()
            }
        }
        
        // Remove completed tasks
        tasks.removeAll { task in
            completedTasks.contains { $0.id == task.id }
        }
    }
    
    /// Sleep for the specified duration (will be controlled by advance calls)
    public func sleep(for duration: TimeInterval) async {
        let scheduledTime = currentTime + duration
        let taskId = UUID()
        
        await withCheckedContinuation { continuation in
            let taskInfo = TaskInfo(
                id: taskId,
                scheduledTime: scheduledTime,
                continuation: continuation
            )
            tasks.append(taskInfo)
        }
    }
    
    /// Reset the clock to the specified time
    public func reset(to time: TimeInterval = 0) {
        currentTime = time
        
        // Cancel all pending tasks
        for task in tasks {
            task.continuation.resume()
        }
        tasks.removeAll()
    }
    
    /// Get the number of pending tasks
    public var pendingTaskCount: Int {
        tasks.count
    }
}

private struct TaskInfo {
    let id: UUID
    let scheduledTime: TimeInterval
    let continuation: CheckedContinuation<Void, Never>
}

// MARK: - Test Helper Extensions

extension TestClock {
    /// Create a sleep function that uses this test clock
    public func makeSleep() -> (TimeInterval) async -> Void {
        return { [weak self] duration in
            await self?.sleep(for: duration)
        }
    }
    
    /// Advance time in small increments to simulate real-time flow
    public func advanceIncrementally(by totalDuration: TimeInterval, stepSize: TimeInterval = 0.1) async {
        let steps = Int(totalDuration / stepSize)
        let remainder = totalDuration - (Double(steps) * stepSize)
        
        for _ in 0..<steps {
            await advance(by: stepSize)
        }
        
        if remainder > 0 {
            await advance(by: remainder)
        }
    }
}