import Foundation
import Testing
@testable import AppPilot
import CoreGraphics
@testable import AXUI

@Suite("UISnapshot Tests")
final class UISnapshotTests {
    
    // Helper function to create AXElement for testing using internal init
    private func createTestAXElement(
        role: AXUI.Role = .button,
        description: String? = "Test Button",
        identifier: String? = nil,
        position: AXUI.Point? = AXUI.Point(x: 0, y: 0),
        size: AXUI.Size? = AXUI.Size(width: 100, height: 30),
        enabled: Bool = true,
        selected: Bool = false,
        focused: Bool = false
    ) -> AXElement {
        // Convert Role to SystemRole for internal init
        let systemRole: SystemRole = role.possibleSystemRoles.first ?? .button
        
        return AXElement(
            systemRole: systemRole,
            description: description,
            identifier: identifier,
            roleDescription: nil,
            help: nil,
            position: position,
            size: size,
            selected: selected,
            enabled: enabled,
            focused: focused,
            children: nil,
            axElementRef: nil
        )
    }
    
    @Test("UISnapshot creation and properties")
    func testUISnapshotCreation() throws {
        // Create test data
        let windowHandle = WindowHandle(id: "test-window-123", bundleID: "com.test.app")
        let windowInfo = WindowInfo(
            id: windowHandle,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            isVisible: true,
            isMain: true,
            appName: "TestApp"
        )
        
        let elements = [
            createTestAXElement(
                role: .button,
                description: "Submit",
                identifier: "btn1",
                position: AXUI.Point(x: 300, y: 400),
                size: AXUI.Size(width: 100, height: 40)
            ),
            createTestAXElement(
                role: .field,
                description: "Hello",
                identifier: "username_field",
                position: AXUI.Point(x: 200, y: 200),
                size: AXUI.Size(width: 200, height: 30)
            ),
            createTestAXElement(
                role: .text,
                description: "Username:",
                identifier: "text1",
                position: AXUI.Point(x: 100, y: 205),
                size: AXUI.Size(width: 80, height: 20)
            )
        ]
        
        // Create dummy PNG data
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        
        // Create snapshot
        let snapshot = UISnapshot(
            windowHandle: windowHandle,
            windowInfo: windowInfo,
            elements: elements,
            imageData: imageData
        )
        
        // Test properties
        #expect(snapshot.windowHandle == windowHandle)
        #expect(snapshot.windowInfo.title == "Test Window")
        #expect(snapshot.elements.count == 3)
        #expect(snapshot.imageData == imageData)
    }
    
    @Test("Element filtering")
    func testElementFiltering() throws {
        let elements = [
            createTestAXElement(
                role: .button,
                description: "Submit",
                identifier: "1"
            ),
            createTestAXElement(
                role: .button,
                description: "Cancel",
                identifier: "2"
            ),
            createTestAXElement(
                role: .button,
                description: "Help",
                identifier: "3",
                enabled: false
            ),
            createTestAXElement(
                role: .field,
                description: "Username",
                identifier: "4",
                size: AXUI.Size(width: 200, height: 30)
            ),
            createTestAXElement(
                role: .text,
                description: "Label",
                identifier: "5",
                size: AXUI.Size(width: 100, height: 20)
            )
        ]
        
        let windowHandle = WindowHandle(id: "test", bundleID: "com.test.app")
        let windowInfo = WindowInfo(
            id: windowHandle,
            title: "Test",
            bounds: CGRect.zero,
            isVisible: true,
            isMain: true,
            appName: "Test"
        )
        
        let snapshot = UISnapshot(
            windowHandle: windowHandle,
            windowInfo: windowInfo,
            elements: elements,
            imageData: Data()
        )
        
        // Test filtering by role
        let buttons = snapshot.elements.filter { $0.role.rawValue == "Button" }
        #expect(buttons.count == 3)
        
        // Test filtering by title
        let submitButton = snapshot.elements.first { 
            $0.role.rawValue == "Button" && $0.description?.contains("Submit") == true 
        }
        #expect(submitButton != nil)
        #expect(submitButton?.description == "Submit")
        
        // Test clickable elements
        let clickableElements = snapshot.clickableElements
        #expect(clickableElements.count == 2) // Only enabled buttons
        
        // Test text input elements
        let textInputElements = snapshot.textInputElements
        #expect(textInputElements.count == 1) // Only the field
    }
    
    @Test("Elements by position sorting")
    func testElementsByPosition() throws {
        let elements = [
            createTestAXElement(
                role: .button,
                description: "Bottom Left",
                identifier: "1",
                position: AXUI.Point(x: 100, y: 100),
                size: AXUI.Size(width: 50, height: 30)
            ),
            createTestAXElement(
                role: .button,
                description: "Bottom Right",
                identifier: "2",
                position: AXUI.Point(x: 200, y: 100),
                size: AXUI.Size(width: 50, height: 30)
            ),
            createTestAXElement(
                role: .button,
                description: "Top Left",
                identifier: "3",
                position: AXUI.Point(x: 50, y: 200),
                size: AXUI.Size(width: 50, height: 30)
            ),
            createTestAXElement(
                role: .button,
                description: "Top Right",
                identifier: "4",
                position: AXUI.Point(x: 150, y: 200),
                size: AXUI.Size(width: 50, height: 30)
            )
        ]
        
        let windowHandle = WindowHandle(id: "test", bundleID: "com.test.app")
        let windowInfo = WindowInfo(
            id: windowHandle,
            title: "Test",
            bounds: CGRect.zero,
            isVisible: true,
            isMain: true,
            appName: "Test"
        )
        
        let snapshot = UISnapshot(
            windowHandle: windowHandle,
            windowInfo: windowInfo,
            elements: elements,
            imageData: Data()
        )
        
        let sortedElements = snapshot.elementsByPosition
        
        // Should be sorted top-left to bottom-right
        #expect(sortedElements[0].description == "Top Left")
        #expect(sortedElements[1].description == "Top Right")
        #expect(sortedElements[2].description == "Bottom Left")
        #expect(sortedElements[3].description == "Bottom Right")
    }
    
    @Test("UISnapshot Codable")
    func testUISnapshotCodable() throws {
        let windowHandle = WindowHandle(id: "test-window", bundleID: "com.test.app")
        let windowInfo = WindowInfo(
            id: windowHandle,
            title: "Test Window",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            isVisible: true,
            isMain: true,
            appName: "TestApp"
        )
        
        let elements = [
            createTestAXElement(
                role: .button,
                description: "Test Button",
                identifier: "test-btn"
            )
        ]
        
        let originalSnapshot = UISnapshot(
            windowHandle: windowHandle,
            windowInfo: windowInfo,
            elements: elements,
            imageData: Data([0x89, 0x50, 0x4E, 0x47])
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSnapshot)
        #expect(data.count > 0)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedSnapshot = try decoder.decode(UISnapshot.self, from: data)
        
        #expect(decodedSnapshot.windowHandle == originalSnapshot.windowHandle)
        #expect(decodedSnapshot.windowInfo.title == originalSnapshot.windowInfo.title)
        #expect(decodedSnapshot.elements.count == originalSnapshot.elements.count)
        #expect(decodedSnapshot.imageData == originalSnapshot.imageData)
    }
}
