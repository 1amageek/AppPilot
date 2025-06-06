import Testing
import Foundation
import CoreGraphics
@testable import AppPilot

@Suite("Enhanced Gesture Tests")
struct EnhancedGestureTests {
    
    @Test("Pinch gesture test")
    func testPinchGesture() async throws {
        let pilot = AppPilot()
        let center = Point(x: Double(400), y: Double(300))
        
        do {
            // Test zoom in
            let zoomInResult = try await pilot.pinch(center: center, scale: 2.0, duration: 0.5)
            #expect(zoomInResult.success, "Zoom in should succeed")
            #expect(zoomInResult.screenCoordinates?.x == center.x, "Should preserve center coordinates")
            
            // Test zoom out
            let zoomOutResult = try await pilot.pinch(center: center, scale: 0.5, duration: 0.5)
            #expect(zoomOutResult.success, "Zoom out should succeed")
            
        } catch PilotError.permissionDenied {
            print("Pinch test skipped: Accessibility permission required")
        }
    }
    
    @Test("Rotation gesture test")
    func testRotationGesture() async throws {
        let pilot = AppPilot()
        let center = Point(x: Double(400), y: Double(300))
        
        do {
            // Test clockwise rotation
            let clockwiseResult = try await pilot.rotate(center: center, degrees: 45.0, duration: 0.5)
            #expect(clockwiseResult.success, "Clockwise rotation should succeed")
            
            // Test counter-clockwise rotation
            let counterClockwiseResult = try await pilot.rotate(center: center, degrees: -30.0, duration: 0.5)
            #expect(counterClockwiseResult.success, "Counter-clockwise rotation should succeed")
            
        } catch PilotError.permissionDenied {
            print("Rotation test skipped: Accessibility permission required")
        }
    }
    
    @Test("Swipe gesture test")
    func testSwipeGesture() async throws {
        let pilot = AppPilot()
        let startPoint = Point(x: Double(200), y: Double(200))
        
        do {
            // Test all swipe directions
            let directions: [SwipeDirection] = [.up, .down, .left, .right, .upLeft, .upRight, .downLeft, .downRight]
            
            for direction in directions {
                let result = try await pilot.swipe(from: startPoint, direction: direction, distance: 100, duration: 0.3)
                #expect(result.success, "Swipe \(direction) should succeed")
                
                // Verify end point calculation
                let vector = direction.vector
                let expectedEndX = startPoint.x + vector.x * 100
                let expectedEndY = startPoint.y + vector.y * 100
                
                #expect(abs(result.screenCoordinates!.x - expectedEndX) < 1.0, "End X coordinate should be calculated correctly")
                #expect(abs(result.screenCoordinates!.y - expectedEndY) < 1.0, "End Y coordinate should be calculated correctly")
            }
            
        } catch PilotError.permissionDenied {
            print("Swipe test skipped: Accessibility permission required")
        }
    }
    
    @Test("Scroll gesture test")
    func testScrollGesture() async throws {
        let pilot = AppPilot()
        let scrollPoint = Point(x: Double(400), y: Double(300))
        
        do {
            // Test vertical scroll
            let verticalResult = try await pilot.scroll(at: scrollPoint, deltaX: 0, deltaY: -100)
            #expect(verticalResult.success, "Vertical scroll should succeed")
            
            // Test horizontal scroll
            let horizontalResult = try await pilot.scroll(at: scrollPoint, deltaX: 50, deltaY: 0)
            #expect(horizontalResult.success, "Horizontal scroll should succeed")
            
            // Test diagonal scroll
            let diagonalResult = try await pilot.scroll(at: scrollPoint, deltaX: 30, deltaY: -50)
            #expect(diagonalResult.success, "Diagonal scroll should succeed")
            
        } catch PilotError.permissionDenied {
            print("Scroll test skipped: Accessibility permission required")
        }
    }
    
    @Test("Double-tap and drag test")
    func testDoubleTapAndDrag() async throws {
        let pilot = AppPilot()
        let tapPoint = Point(x: Double(300), y: Double(200))
        let endPoint = Point(x: Double(500), y: Double(400))
        
        do {
            let result = try await pilot.doubleTapAndDrag(tapPoint: tapPoint, dragTo: endPoint, duration: 1.0)
            #expect(result.success, "Double-tap and drag should succeed")
            #expect(result.screenCoordinates?.x == endPoint.x, "Should end at drag target")
            #expect(result.screenCoordinates?.y == endPoint.y, "Should end at drag target")
            
        } catch PilotError.permissionDenied {
            print("Double-tap and drag test skipped: Accessibility permission required")
        }
    }
    
    @Test("Enhanced drag with different buttons")
    func testEnhancedDrag() async throws {
        let pilot = AppPilot()
        let startPoint = Point(x: Double(100), y: Double(100))
        let endPoint = Point(x: Double(200), y: Double(200))
        
        do {
            // Test left mouse drag
            let leftDragResult = try await pilot.drag(from: startPoint, to: endPoint, duration: 0.5, button: .left)
            #expect(leftDragResult.success, "Left mouse drag should succeed")
            
            // Test right mouse drag
            let rightDragResult = try await pilot.drag(from: startPoint, to: endPoint, duration: 0.5, button: .right)
            #expect(rightDragResult.success, "Right mouse drag should succeed")
            
            // Test center mouse drag
            let centerDragResult = try await pilot.drag(from: startPoint, to: endPoint, duration: 0.5, button: .center)
            #expect(centerDragResult.success, "Center mouse drag should succeed")
            
        } catch PilotError.permissionDenied {
            print("Enhanced drag test skipped: Accessibility permission required")
        }
    }
    
    @Test("Key press with modifiers test")
    func testKeyPressWithModifiers() async throws {
        let pilot = AppPilot()
        
        do {
            // Test simple key press
            let simpleResult = try await pilot.keyPress(key: .a, modifiers: [], duration: 0.1)
            #expect(simpleResult.success, "Simple key press should succeed")
            
            // Test key with Command modifier
            let cmdResult = try await pilot.keyPress(key: .c, modifiers: [.command], duration: 0.1)
            #expect(cmdResult.success, "Cmd+C should succeed")
            
            // Test key with multiple modifiers
            let multiResult = try await pilot.keyPress(key: .z, modifiers: [.command, .shift], duration: 0.1)
            #expect(multiResult.success, "Cmd+Shift+Z should succeed")
            
        } catch PilotError.permissionDenied {
            print("Key press test skipped: Accessibility permission required")
        }
    }
    
    @Test("Key combination test")
    func testKeyCombination() async throws {
        let pilot = AppPilot()
        
        do {
            // Test copy (Cmd+C)
            let copyResult = try await pilot.keyCombination([.c], modifiers: [.command])
            #expect(copyResult.success, "Copy (Cmd+C) should succeed")
            
            // Test paste (Cmd+V)
            let pasteResult = try await pilot.keyCombination([.v], modifiers: [.command])
            #expect(pasteResult.success, "Paste (Cmd+V) should succeed")
            
            // Test undo (Cmd+Z)
            let undoResult = try await pilot.keyCombination([.z], modifiers: [.command])
            #expect(undoResult.success, "Undo (Cmd+Z) should succeed")
            
            // Test select all (Cmd+A)
            let selectAllResult = try await pilot.keyCombination([.a], modifiers: [.command])
            #expect(selectAllResult.success, "Select All (Cmd+A) should succeed")
            
        } catch PilotError.permissionDenied {
            print("Key combination test skipped: Accessibility permission required")
        }
    }
    
    @Test("Virtual key enumeration test")
    func testVirtualKeyEnumeration() async throws {
        // Test that virtual keys have correct raw values
        #expect(VirtualKey.a.rawValue == 0, "Key A should have raw value 0")
        #expect(VirtualKey.space.rawValue == 49, "Space key should have raw value 49")
        #expect(VirtualKey.returnKey.rawValue == 36, "Return key should have raw value 36")
        #expect(VirtualKey.escape.rawValue == 53, "Escape key should have raw value 53")
        
        // Test modifier key flags
        #expect(ModifierKey.command.cgEventFlag == .maskCommand, "Command modifier should map correctly")
        #expect(ModifierKey.shift.cgEventFlag == .maskShift, "Shift modifier should map correctly")
        #expect(ModifierKey.option.cgEventFlag == .maskAlternate, "Option modifier should map correctly")
        #expect(ModifierKey.control.cgEventFlag == .maskControl, "Control modifier should map correctly")
    }
    
    @Test("Swipe direction vector test")
    func testSwipeDirectionVectors() async throws {
        // Test cardinal directions
        #expect(SwipeDirection.up.vector.x == 0 && SwipeDirection.up.vector.y == -1, "Up should be (0, -1)")
        #expect(SwipeDirection.down.vector.x == 0 && SwipeDirection.down.vector.y == 1, "Down should be (0, 1)")
        #expect(SwipeDirection.left.vector.x == -1 && SwipeDirection.left.vector.y == 0, "Left should be (-1, 0)")
        #expect(SwipeDirection.right.vector.x == 1 && SwipeDirection.right.vector.y == 0, "Right should be (1, 0)")
        
        // Test diagonal directions (normalized to ~0.707)
        let diagonal = 0.707
        let tolerance = 0.01
        
        let upLeft = SwipeDirection.upLeft.vector
        #expect(abs(upLeft.x - (-diagonal)) < tolerance && abs(upLeft.y - (-diagonal)) < tolerance, "UpLeft should be normalized diagonal")
        
        let downRight = SwipeDirection.downRight.vector
        #expect(abs(downRight.x - diagonal) < tolerance && abs(downRight.y - diagonal) < tolerance, "DownRight should be normalized diagonal")
    }
}