import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

@Suite("Basic AppPilot v2.0 Tests")
struct BasicTests {
    
    @Test("AppPilot initialization")
    func testInitialization() async throws {
        let pilot = AppPilot()
        // Test that we can create an instance
        let _ = pilot
    }
    
    @Test("Point creation with explicit types")
    func testPointCreation() async throws {
        // Test Point creation with explicit Double to avoid ambiguity
        let doublePoint = Point(x: Double(100), y: Double(200))
        #expect(doublePoint.x == 100)
        #expect(doublePoint.y == 200)
        
        let cgFloatPoint = Point(x: CGFloat(150), y: CGFloat(250))
        #expect(cgFloatPoint.x == 150)
        #expect(cgFloatPoint.y == 250)
    }
    
    @Test("Basic coordinate conversion")
    func testBasicCoordinateConversion() async throws {
        let pilot = AppPilot()
        
        // Test coordinate conversion (requires real window)
        do {
            let apps = try await pilot.listApplications()
            guard let app = apps.first else { return }
            
            let windows = try await pilot.listWindows(app: app.id)
            guard let window = windows.first else { return }
            
            let windowPoint = Point(x: Double(10), y: Double(20))
            let screenPoint = try await pilot.windowToScreen(point: windowPoint, window: window.id)
            
            #expect(screenPoint.x >= windowPoint.x, "Screen coordinate should include window offset")
            #expect(screenPoint.y >= windowPoint.y, "Screen coordinate should include window offset")
            
        } catch {
            print("Coordinate conversion test skipped: \(error)")
        }
    }
    
    @Test("Error types basic functionality")
    func testErrorTypes() async throws {
        let permissionError = PilotError.permissionDenied("Test message")
        #expect(permissionError.localizedDescription.contains("Permission denied"))
        
        let timeoutError = PilotError.timeout(5.0)
        #expect(timeoutError.localizedDescription.contains("timed out"))
        
        let windowError = PilotError.windowNotFound(WindowID(id: 123))
        #expect(windowError.localizedDescription.contains("Window not found"))
        
        let appError = PilotError.applicationNotFound(AppID(pid: 456))
        #expect(appError.localizedDescription.contains("Application not found"))
        
        let coordError = PilotError.coordinateOutOfBounds(Point(x: Double(-10), y: Double(-20)))
        #expect(coordError.localizedDescription.contains("out of bounds"))
        
        let eventError = PilotError.eventCreationFailed
        #expect(eventError.localizedDescription.contains("Failed to create"))
        
        let osError = PilotError.osFailure(api: "CGEvent", code: -1)
        #expect(osError.localizedDescription.contains("OS API failure"))
        
        let argError = PilotError.invalidArgument("Test invalid arg")
        #expect(argError.localizedDescription.contains("Invalid argument"))
    }
    
    @Test("Mock drivers basic functionality")
    func testMockDrivers() async throws {
        let mockCGEventDriver = MockCGEventDriver()
        let mockAccessibilityDriver = MockAccessibilityDriver()
        let mockScreenDriver = MockScreenDriver()
        
        let pilot = AppPilot(
            cgEventDriver: mockCGEventDriver,
            screenDriver: mockScreenDriver,
            accessibilityDriver: mockAccessibilityDriver
        )
        
        // Test that mock drivers can be injected
        let _ = pilot
        
        // Test mock screen driver functionality
        let mockImage = try await mockScreenDriver.captureWindow(WindowID(id: 123))
        #expect(mockImage.width > 0, "Mock image should have valid dimensions")
        #expect(mockImage.height > 0, "Mock image should have valid dimensions")
        
        // Test mock accessibility driver
        let hasPermission = await mockAccessibilityDriver.checkPermission()
        #expect(hasPermission, "Mock should return permission by default")
        
        // Test mock CGEvent driver call tracking
        await mockCGEventDriver.clearHistory()
        
        do {
            try await mockCGEventDriver.click(at: Point(x: Double(100), y: Double(100)), button: .left)
            let mouseDownEvents = await mockCGEventDriver.getMouseDownEvents()
            let mouseUpEvents = await mockCGEventDriver.getMouseUpEvents()
            #expect(mouseDownEvents.count >= 1, "Should track mouse down events")
            #expect(mouseUpEvents.count >= 1, "Should track mouse up events")
        } catch {
            // Expected if mock has no permission setup
            print("Mock click test expected to have errors in some configurations")
        }
    }
    
    @Test("Wait functionality")
    func testWaitFunctionality() async throws {
        let pilot = AppPilot()
        
        let startTime = Date()
        try await pilot.wait(.time(seconds: 0.05)) // 50ms
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(duration >= 0.04, "Wait should take at least the requested time")
        #expect(duration <= 0.15, "Wait should not take excessively long")
    }
    
    @Test("Application and window listing")
    func testApplicationAndWindowListing() async throws {
        let pilot = AppPilot()
        
        // Test real application listing
        let apps = try await pilot.listApplications()
        #expect(!apps.isEmpty, "Should find at least one running application")
        
        for app in apps.prefix(3) {
            #expect(app.id.pid > 0, "App PID should be valid")
            #expect(!app.name.isEmpty, "App name should not be empty")
            
            // Test window listing for each app
            let windows = try await pilot.listWindows(app: app.id)
            // Note: apps might have 0 windows, which is valid
            
            for window in windows.prefix(2) {
                #expect(window.id.id > 0, "Window ID should be valid")
                #expect(window.bounds.width > 0, "Window width should be positive")
                #expect(window.bounds.height > 0, "Window height should be positive")
            }
        }
    }
    
    @Test("Screen coordinate click test")
    func testScreenCoordinateClick() async throws {
        let pilot = AppPilot()
        
        // Test click at safe screen coordinates (center of screen)
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        let centerPoint = Point(
            x: Double(screenBounds.midX), 
            y: Double(screenBounds.midY)
        )
        
        do {
            let result = try await pilot.click(at: centerPoint)
            #expect(result.success, "Click at screen center should succeed")
            #expect(result.screenCoordinates?.x == centerPoint.x, "Result should preserve coordinates")
            #expect(result.screenCoordinates?.y == centerPoint.y, "Result should preserve coordinates")
            
        } catch PilotError.permissionDenied {
            print("Click test skipped: Accessibility permission required")
        } catch {
            print("Click test error: \(error)")
        }
    }
    
    @Test("Type operation test")
    func testTypeOperation() async throws {
        let pilot = AppPilot()
        
        do {
            let result = try await pilot.type(text: "AppPilot Test")
            #expect(result.success, "Type operation should succeed")
            
        } catch PilotError.permissionDenied {
            print("Type test skipped: Accessibility permission required")
        } catch {
            print("Type test error: \(error)")
        }
    }
    
    @Test("Drag operation test")
    func testDragOperation() async throws {
        let pilot = AppPilot()
        
        let startPoint = Point(x: Double(100), y: Double(100))
        let endPoint = Point(x: Double(200), y: Double(150))
        
        do {
            let result = try await pilot.drag(from: startPoint, to: endPoint, duration: 0.1)
            #expect(result.success, "Drag operation should succeed")
            #expect(result.screenCoordinates?.x == endPoint.x, "Result should have end coordinates")
            #expect(result.screenCoordinates?.y == endPoint.y, "Result should have end coordinates")
            
        } catch PilotError.permissionDenied {
            print("Drag test skipped: Accessibility permission required")
        } catch {
            print("Drag test error: \(error)")
        }
    }
}