import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

@Suite("Coordinate Converter Boundary Tests")
struct CoordinateConverterTests {
    private let converter = CoordinateConverter()
    
    // MARK: - Basic Conversion Tests
    
    
    // MARK: - Boundary Value Tests
    
    @Test("Window corners and edges",
          .tags(.unit, .coordinates, .boundaries))
    func testWindowCorners() async throws {
        let window = Window(
            id: WindowID(id: 1),
            title: "Test Window",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 123)
        )
        
        // Test all four corners
        let corners = [
            (Point(x: 0, y: 0), CGPoint(x: 100, y: 200), "top-left"),
            (Point(x: 800, y: 0), CGPoint(x: 900, y: 200), "top-right"),
            (Point(x: 0, y: 600), CGPoint(x: 100, y: 800), "bottom-left"),
            (Point(x: 800, y: 600), CGPoint(x: 900, y: 800), "bottom-right")
        ]
        
        for (windowPoint, expectedScreen, _) in corners {
            let screenPoint = await converter.windowToScreen(windowPoint, in: window)
            #expect(screenPoint.x == expectedScreen.x, "Corner X conversion failed")
            #expect(screenPoint.y == expectedScreen.y, "Corner Y conversion failed")
            
            // Test round-trip conversion
            let backToWindow = await converter.screenToWindow(screenPoint, in: window)
            #expect(abs(backToWindow.x - windowPoint.x) < 0.001, "Round-trip X conversion failed")
            #expect(abs(backToWindow.y - windowPoint.y) < 0.001, "Round-trip Y conversion failed")
        }
    }
    
    @Test("Negative coordinates",
          .tags(.unit, .coordinates, .boundaries))
    func testNegativeCoordinates() async throws {
        let window = Window(
            id: WindowID(id: 1),
            title: "Test Window",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 123)
        )
        
        // Test negative window coordinates (outside window bounds)
        let negativePoint = Point(x: -50, y: -25)
        let screenPoint = await converter.windowToScreen(negativePoint, in: window)
        
        #expect(screenPoint.x == 50, "Negative window X should convert correctly")
        #expect(screenPoint.y == 175, "Negative window Y should convert correctly")
        
        // Test conversion back
        let backToWindow = await converter.screenToWindow(screenPoint, in: window)
        #expect(backToWindow.x == -50, "Negative coordinate round-trip X failed")
        #expect(backToWindow.y == -25, "Negative coordinate round-trip Y failed")
    }
    
    
    // MARK: - Large Value Tests
    
    @Test("Large coordinate values",
          .tags(.unit, .coordinates, .boundaries))
    func testLargeCoordinates() async throws {
        let largeWindow = Window(
            id: WindowID(id: 1),
            title: "Large Window",
            frame: CGRect(x: 10000, y: 20000, width: 5000, height: 3000),
            isMinimized: false,
            app: AppID(pid: 123)
        )
        
        let largePoint = Point(x: 4999, y: 2999) // Near window edge
        let screenPoint = await converter.windowToScreen(largePoint, in: largeWindow)
        
        #expect(screenPoint.x == 14999, "Large X coordinate conversion failed")
        #expect(screenPoint.y == 22999, "Large Y coordinate conversion failed")
        
        // Test round-trip
        let backToWindow = await converter.screenToWindow(screenPoint, in: largeWindow)
        #expect(abs(backToWindow.x - largePoint.x) < 0.001, "Large coordinate round-trip X failed")
        #expect(abs(backToWindow.y - largePoint.y) < 0.001, "Large coordinate round-trip Y failed")
    }
    
    // MARK: - Precision Tests
    
    @Test("Fractional coordinates precision",
          .tags(.unit, .coordinates, .precision))
    func testFractionalPrecision() async throws {
        let window = Window(
            id: WindowID(id: 1),
            title: "Test Window",
            frame: CGRect(x: 100.5, y: 200.7, width: 800.3, height: 600.1),
            isMinimized: false,
            app: AppID(pid: 123)
        )
        
        let fractionalPoint = Point(x: 123.456, y: 789.012)
        let screenPoint = await converter.windowToScreen(fractionalPoint, in: window)
        
        let expectedX = 100.5 + 123.456
        let expectedY = 200.7 + 789.012
        
        #expect(abs(screenPoint.x - expectedX) < 0.001, "Fractional X precision lost")
        #expect(abs(screenPoint.y - expectedY) < 0.001, "Fractional Y precision lost")
        
        // Test round-trip precision
        let backToWindow = await converter.screenToWindow(screenPoint, in: window)
        #expect(abs(backToWindow.x - fractionalPoint.x) < 0.001, "Round-trip fractional X precision lost")
        #expect(abs(backToWindow.y - fractionalPoint.y) < 0.001, "Round-trip fractional Y precision lost")
    }
    
    
    // MARK: - AX Coordinate Normalization Tests
    
    @Test("AX coordinate normalization",
          .tags(.unit, .coordinates, .accessibility))
    func testAXNormalization() async throws {
        let window = Window(
            id: WindowID(id: 1),
            title: "AX Window",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 123)
        )
        
        let point = Point(x: 50, y: 75)
        let axPoint = await converter.normalizeForAX(point, in: window)
        let screenPoint = await converter.windowToScreen(point, in: window)
        
        // Currently, AX normalization is the same as screen conversion
        // This might change in the future with actual AX coordinate handling
        #expect(axPoint.x == screenPoint.x, "AX X coordinate should match screen coordinate")
        #expect(axPoint.y == screenPoint.y, "AX Y coordinate should match screen coordinate")
    }
    
}
