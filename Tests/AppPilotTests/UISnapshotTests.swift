import Foundation
import Testing
@testable import AppPilot
import CoreGraphics
import AXUI

@Suite("UISnapshot Tests")
final class UISnapshotTests {
    
    @Test("UISnapshot creation and properties")
    func testUISnapshotCreation() throws {
        // Create test data
        let windowHandle = WindowHandle(id: "test-window-123")
        let windowInfo = WindowInfo(
            id: windowHandle,
            title: "Test Window",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
            isVisible: true,
            isMain: true,
            appName: "TestApp"
        )
        
        let elements = [
            AIElement(
                id: "btn1",
                role: AXUI.Role.button,
                value: "Submit",
                identifier: nil,
                desc: nil,
                bounds: [300, 400, 100, 40],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "field1",
                role: AXUI.Role.field,
                value: "Hello",
                identifier: "username_field",
                desc: nil,
                bounds: [200, 200, 200, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "text1",
                role: AXUI.Role.text,
                value: "Username:",
                identifier: nil,
                desc: nil,
                bounds: [100, 205, 80, 20],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            )
        ]
        
        // Create dummy PNG data
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        
        let metadata = SnapshotMetadata(
            description: "Test snapshot",
            tags: ["unit-test", "sample"],
            customData: ["testCase": "UISnapshotTests"]
        )
        
        // Create snapshot
        let snapshot = UISnapshot(
            windowHandle: windowHandle,
            windowInfo: windowInfo,
            elements: elements,
            imageData: imageData,
            metadata: metadata
        )
        
        // Test properties
        #expect(snapshot.windowHandle == windowHandle)
        #expect(snapshot.windowInfo.title == "Test Window")
        #expect(snapshot.elements.count == 3)
        #expect(snapshot.imageData == imageData)
        #expect(snapshot.metadata?.description == "Test snapshot")
    }
    
    @Test("UISnapshot element filtering")
    func testElementFiltering() throws {
        let elements = [
            AIElement(
                id: "1",
                role: AXUI.Role.button,
                value: "Submit",
                identifier: "1",
                desc: nil,
                bounds: [0, 0, 100, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "2",
                role: AXUI.Role.button,
                value: "Cancel",
                identifier: "2",
                desc: nil,
                bounds: [0, 0, 100, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "3",
                role: AXUI.Role.button,
                value: "OK",
                identifier: "3",
                desc: nil,
                bounds: [0, 0, 100, 30],
                state: AXUI.AIElementState(selected: false, enabled: false, focused: false)
            ),
            AIElement(
                id: "4",
                role: AXUI.Role.field,
                value: nil,
                identifier: "4",
                desc: nil,
                bounds: [0, 0, 200, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "5",
                role: AXUI.Role.text,
                value: "Label",
                identifier: "5",
                desc: nil,
                bounds: [0, 0, 100, 20],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            )
        ]
        
        let snapshot = UISnapshot(
            windowHandle: WindowHandle(id: "test"),
            windowInfo: WindowInfo(
                id: WindowHandle(id: "test"),
                title: "Test",
                bounds: .zero,
                isVisible: true,
                isMain: true,
                appName: "Test"
            ),
            elements: elements,
            imageData: Data()
        )
        
        // Test clickable elements
        let clickable = snapshot.clickableElements
        #expect(clickable.count == 2) // Only enabled buttons
        #expect(clickable.allSatisfy { element in
            element.role?.rawValue == "Button" && element.isEnabled
        })
        
        // Test text input elements
        let textInputs = snapshot.textInputElements
        #expect(textInputs.count == 1)
        #expect(textInputs.first?.role?.rawValue == "Field")
        
        // Test find element
        let submitButton = snapshot.findElement(role: "Button", title: "Submit")
        #expect(submitButton?.value == "Submit")
        #expect(submitButton?.id == "1")
        
        // Test find elements
        let buttons = snapshot.findElements(role: "Button")
        #expect(buttons.count == 3)
        
        let cancelElements = snapshot.findElements(title: "Cancel")
        #expect(cancelElements.count == 1)
        #expect(cancelElements.first?.value == "Cancel")
    }
    
    @Test("UISnapshot elements by position")
    func testElementsByPosition() throws {
        let elements = [
            AIElement(
                id: "1",
                role: AXUI.Role.button,
                value: nil,
                identifier: "1",
                desc: nil,
                bounds: [100, 100, 50, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "2",
                role: AXUI.Role.button,
                value: nil,
                identifier: "2",
                desc: nil,
                bounds: [200, 100, 50, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "3",
                role: AXUI.Role.button,
                value: nil,
                identifier: "3",
                desc: nil,
                bounds: [50, 200, 50, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            ),
            AIElement(
                id: "4",
                role: AXUI.Role.button,
                value: nil,
                identifier: "4",
                desc: nil,
                bounds: [150, 200, 50, 30],
                state: AXUI.AIElementState(selected: false, enabled: true, focused: false)
            )
        ]
        
        let snapshot = UISnapshot(
            windowHandle: WindowHandle(id: "test"),
            windowInfo: WindowInfo(
                id: WindowHandle(id: "test"),
                title: "Test",
                bounds: .zero,
                isVisible: true,
                isMain: true,
                appName: "Test"
            ),
            elements: elements,
            imageData: Data()
        )
        
        let sorted = snapshot.elementsByPosition
        #expect(sorted.count == 4)
        
        // Elements should be sorted top-to-bottom, left-to-right
        #expect(sorted[0].id == "1") // Top-left
        #expect(sorted[1].id == "2") // Top-right
        #expect(sorted[2].id == "3") // Bottom-left
        #expect(sorted[3].id == "4") // Bottom-right
    }
    
    @Test("SnapshotMetadata initialization")
    func testSnapshotMetadata() throws {
        let metadata = SnapshotMetadata(
            description: "Test description",
            tags: ["tag1", "tag2"],
            customData: ["key": "value"]
        )
        
        #expect(metadata.description == "Test description")
        #expect(metadata.tags == ["tag1", "tag2"])
        #expect(metadata.customData["key"] == "value")
        
        // Test default initialization
        let emptyMetadata = SnapshotMetadata()
        #expect(emptyMetadata.description == nil)
        #expect(emptyMetadata.tags.isEmpty)
        #expect(emptyMetadata.customData.isEmpty)
    }
    
}

@Suite("UISnapshot Integration Tests")
final class UISnapshotIntegrationTests {
    
    @Test("Capture snapshot from TestApp")
    func testCaptureSnapshot() async throws {
        let pilot = AppPilot()
        
        // Try to find TestApp
        do {
            let app = try await pilot.findApplication(name: "TestApp")
            let windows = try await pilot.listWindows(app: app)
            
            guard let window = windows.first else {
                print("No windows found in TestApp - skipping test")
                return
            }
            
            // Capture snapshot
            let snapshot = try await pilot.snapshot(
                window: window.id,
                metadata: SnapshotMetadata(
                    description: "Integration test snapshot",
                    tags: ["test"]
                )
            )
            
            // Verify snapshot
            #expect(snapshot.windowHandle == window.id)
            #expect(snapshot.windowInfo.title == window.title)
            #expect(!snapshot.elements.isEmpty, "Should find some UI elements")
            #expect(!snapshot.imageData.isEmpty, "Should have image data")
            #expect(snapshot.image != nil, "Should be able to reconstruct CGImage")
            
            // Verify we can find common UI elements
            let buttons = snapshot.findElements(role: "Button")
            print("Found \(buttons.count) buttons in snapshot")
            
        } catch PilotError.applicationNotFound {
            print("TestApp not running - skipping integration test")
            return
        }
    }
}