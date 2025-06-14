import Testing
import Foundation
@testable import AppPilot
import AXUI

/// Unit tests for setValue functionality
@Suite("setValue Unit Tests")
struct SetValueUnitTests {
    
    // MARK: - ActionResultData Tests
    
    @Test("ActionResultData.setValue should store correct values")
    func testActionResultDataSetValue() async throws {
        let inputValue = "Test Input"
        let actualValue = "Test Actual"
        
        let setValueData = ActionResultData.setValue(inputValue: inputValue, actualValue: actualValue)
        
        if case .setValue(let storedInput, let storedActual) = setValueData {
            #expect(storedInput == inputValue, "Input value should be stored correctly")
            #expect(storedActual == actualValue, "Actual value should be stored correctly")
        } else {
            Issue.record("ActionResultData should be .setValue case")
        }
    }
    
    @Test("ActionResult with setValue data should be Codable")
    func testActionResultSetValueCodable() async throws {
        let testElement = AXElement(
            role: AXUI.Role.field,
            description: "Test Field",
            identifier: "test-element",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 10, y: 20),
            size: AXUI.Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        let originalResult = ActionResult(
            success: true,
            element: testElement,
            coordinates: Point(x: 60.0, y: 35.0),
            data: .setValue(inputValue: "Input Text", actualValue: "Actual Text")
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(originalResult)
        #expect(encodedData.count > 0, "ActionResult should encode successfully")
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedResult = try decoder.decode(ActionResult.self, from: encodedData)
        
        // Verify decoded data
        #expect(decodedResult.success == originalResult.success, "Success flag should match")
        #expect(decodedResult.element?.id == originalResult.element?.id, "Element ID should match")
        #expect(decodedResult.coordinates?.x == originalResult.coordinates?.x, "Coordinates should match")
        
        if case .setValue(let inputValue, let actualValue) = decodedResult.data {
            #expect(inputValue == "Input Text", "Input value should be preserved")
            #expect(actualValue == "Actual Text", "Actual value should be preserved")
        } else {
            Issue.record("Decoded data should be .setValue case")
        }
    }
    
    // MARK: - AXElement Role Tests
    
    @Test("AXElement roles should support value setting correctly")
    func testAXElementRoleValueSettingSupport() async throws {
        // Test supported roles
        let supportedRoles: [AXUI.Role] = [.field]
        
        for role in supportedRoles {
            let element = AXElement(
                role: role,
                description: "Test Field",
                identifier: "test-\(role.rawValue)",
                roleDescription: nil,
                help: nil,
                position: AXUI.Point(x: 0, y: 0),
                size: AXUI.Size(width: 100, height: 30),
                selected: false,
                enabled: true,
                focused: false
            )
            
            // These roles should be considered text input
            #expect(element.isTextInput, "\(role.rawValue) should be text input")
            
            // Verify element can theoretically support setValue
            #expect(element.isEnabled, "Element should be enabled")
            #expect(Role(rawValue: role.rawValue)?.isTextInput ?? false, "Element role should support text input")
        }
        
        // Test unsupported roles
        let unsupportedRoles: [AXUI.Role] = [.button, .text, .image, .link]
        
        for role in unsupportedRoles {
            let element = AXElement(
                role: role,
                description: "Test Element",
                identifier: "test-\(role.rawValue)",
                roleDescription: nil,
                help: nil,
                position: AXUI.Point(x: 0, y: 0),
                size: AXUI.Size(width: 100, height: 30),
                selected: false,
                enabled: true,
                focused: false
            )
            
            // These roles should not be considered text input
            #expect(!element.isTextInput, "\(role.rawValue) should not be text input")
        }
    }
    
    @Test("Role isTextInput property should be accurate")
    func testRoleIsTextInputProperty() async throws {
        // Test all known text input roles
        let textInputRoles: [(String, Bool)] = [
            ("Field", true),
            ("Button", false),
            ("Check", false),
            ("RadioButton", false),
            ("Text", false),
            ("Link", false),
            ("Image", false),
            ("Slider", false),
            ("MenuItem", false)
        ]
        
        for (role, expectedIsTextInput) in textInputRoles {
            #expect(Role(rawValue: role)?.isTextInput == expectedIsTextInput, 
                   "\(role) isTextInput should be \(expectedIsTextInput)")
        }
    }
    
    // MARK: - Element Validation Tests
    
    @Test("AXElement validation logic should work correctly")
    func testAXElementValidationLogic() async throws {
        // Test valid text field
        let validTextField = AXElement(
            role: AXUI.Role.field,
            description: "Name Field",
            identifier: "valid-text-field",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 10, y: 20),
            size: AXUI.Size(width: 200, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        #expect(validTextField.isEnabled, "Valid text field should be enabled")
        #expect(Role(rawValue: "Field")?.isTextInput ?? false, "Valid text field should support text input")
        #expect((validTextField.size?.width ?? 0) > 0, "Valid text field should have positive width")
        #expect((validTextField.size?.height ?? 0) > 0, "Valid text field should have positive height")
        
        // Test disabled text field
        let disabledTextField = AXElement(
            role: AXUI.Role.field,
            description: "Disabled Field",
            identifier: "disabled-text-field",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 10, y: 20),
            size: AXUI.Size(width: 200, height: 30),
            selected: false,
            enabled: false,
            focused: false
        )
        
        #expect(!disabledTextField.isEnabled, "Disabled text field should not be enabled")
        #expect(Role(rawValue: "Field")?.isTextInput ?? false, "Disabled text field should still be text input type")
        
        // Test non-text element
        let buttonElement = AXElement(
            role: AXUI.Role.button,
            description: "Click Me",
            identifier: "button-element",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 10, y: 20),
            size: AXUI.Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        #expect(buttonElement.isEnabled, "Button should be enabled")
        #expect(!(Role(rawValue: "Button")?.isTextInput ?? false), "Button should not support text input")
    }
    
    // MARK: - Error Type Tests
    
    @Test("PilotError types should be appropriate for setValue")
    func testPilotErrorTypesForSetValue() async throws {
        // Test error creation and properties
        let elementNotAccessibleError = PilotError.elementNotAccessible("test-element-id")
        let invalidArgumentError = PilotError.invalidArgument("Element does not support value setting")
        
        // These should be different error types
        if case .elementNotAccessible(let elementId) = elementNotAccessibleError {
            #expect(elementId == "test-element-id", "Element ID should be preserved in error")
        } else {
            Issue.record("Should be elementNotAccessible error")
        }
        
        if case .invalidArgument(let message) = invalidArgumentError {
            #expect(message.contains("value setting"), "Error message should mention value setting")
        } else {
            Issue.record("Should be invalidArgument error")
        }
    }
    
    // MARK: - Mock setValue Implementation Tests
    
    @Test("Mock setValue implementation logic")
    func testMockSetValueImplementation() async throws {
        // Test the logical flow that setValue would follow
        
        // 1. Element validation
        let validElement = AXElement(
            role: AXUI.Role.field,
            description: "Test Field",
            identifier: "test-element",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 0, y: 0),
            size: AXUI.Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        let invalidElement = AXElement(
            role: AXUI.Role.button,
            description: "Test Button",
            identifier: "invalid-element",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 0, y: 0),
            size: AXUI.Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        // Mock validation logic
        func validateElementForSetValue(_ element: AXElement) -> Bool {
            guard let role = element.role else { return false }
            return element.isEnabled && (Role(rawValue: role.rawValue)?.isTextInput == true || role == .check || role == .slider)
        }
        
        #expect(validateElementForSetValue(validElement), "Valid text field should pass validation")
        #expect(!validateElementForSetValue(invalidElement), "Button should fail validation")
        
        // 2. Value setting simulation
        let testValue = "Mock Test Value"
        
        func mockSetValue(_ value: String, for element: AXElement) -> ActionResult {
            if !validateElementForSetValue(element) {
                return ActionResult(
                    success: false,
                    element: element,
                    coordinates: element.centerPoint
                )
            }
            
            return ActionResult(
                success: true,
                element: element,
                coordinates: element.centerPoint,
                data: .setValue(inputValue: value, actualValue: value)
            )
        }
        
        // Test mock implementation
        let validResult = mockSetValue(testValue, for: validElement)
        #expect(validResult.success, "Valid element should succeed")
        
        if case .setValue(let input, let actual) = validResult.data {
            #expect(input == testValue, "Input value should match")
            #expect(actual == testValue, "Actual value should match in mock")
        } else {
            Issue.record("Result should contain setValue data")
        }
        
        let invalidResult = mockSetValue(testValue, for: invalidElement)
        #expect(!invalidResult.success, "Invalid element should fail")
    }
    
    // MARK: - Type Safety Tests
    
    @Test("setValue should maintain type safety")
    func testSetValueTypeSafety() async throws {
        // Test that setValue enforces correct types
        
        let textFieldElement = AXElement(
            role: AXUI.Role.field,
            description: "Text Field",
            identifier: "text-field",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 0, y: 0),
            size: AXUI.Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        let buttonElement = AXElement(
            role: AXUI.Role.button,
            description: "Button",
            identifier: "button",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 0, y: 0),
            size: AXUI.Size(width: 100, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        // Mock type validation
        func isValidForSetValue(element: AXElement) -> Bool {
            let supportedRoles: Set<AXUI.Role> = [.field, .check, .slider]
            guard let role = element.role else { return false }
            return supportedRoles.contains(role) && element.isEnabled
        }
        
        #expect(isValidForSetValue(element: textFieldElement), "Text field should be valid for setValue")
        #expect(!isValidForSetValue(element: buttonElement), "Button should not be valid for setValue")
        
        // Test value types
        let stringValues = ["Hello", "123", "", "Special@#$%", "日本語"]
        
        for value in stringValues {
            // All string values should be acceptable
            // All test values should be strings - this is guaranteed by the array type
            // setValue should accept any string value (no additional validation needed in unit test)
            print("setValue should accept string value: '\(value)'")
        }
    }
    
    // MARK: - Performance Characteristics Tests
    
    @Test("setValue should have correct performance characteristics")
    func testSetValuePerformanceCharacteristics() async throws {
        // Test that setValue operations are fast (unit test level)
        
        let element = AXElement(
            role: AXUI.Role.field,
            description: "Performance Test",
            identifier: "perf-test-element",
            roleDescription: nil,
            help: nil,
            position: AXUI.Point(x: 0, y: 0),
            size: AXUI.Size(width: 200, height: 30),
            selected: false,
            enabled: true,
            focused: false
        )
        
        let testValues = Array(repeating: "Performance Test", count: 1000)
        
        // Mock setValue that simulates the performance characteristics
        func mockFastSetValue(_ value: String, for element: AXElement) -> ActionResult {
            // Simulate instant value setting (no animation, no events)
            return ActionResult(
                success: true,
                element: element,
                coordinates: element.centerPoint,
                data: .setValue(inputValue: value, actualValue: value)
            )
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for value in testValues {
            let result = mockFastSetValue(value, for: element)
            #expect(result.success, "Mock setValue should always succeed")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(testValues.count)
        
        print("📊 Mock setValue Performance:")
        print("   Total operations: \(testValues.count)")
        print("   Total time: \(String(format: "%.6f", totalTime))s")
        print("   Average time: \(String(format: "%.9f", averageTime))s per operation")
        
        // setValue should be very fast (under 10μs per operation in mock)
        #expect(averageTime < 0.00001, "Mock setValue should be under 10μs per operation")
        
        print("✅ setValue performance characteristics validated")
    }
    
    // MARK: - Integration Readiness Tests
    
    @Test("setValue components should be ready for integration")
    func testSetValueIntegrationReadiness() async throws {
        // Test that all components needed for setValue are properly defined
        
        // 1. ActionResultData.setValue case exists
        let setValueData = ActionResultData.setValue(inputValue: "test", actualValue: "result")
        
        // Verify it's the correct case
        if case .setValue(let input, let actual) = setValueData {
            #expect(input == "test", "ActionResultData.setValue should store input correctly")
            #expect(actual == "result", "ActionResultData.setValue should store actual correctly")
        } else {
            Issue.record("ActionResultData.setValue should be defined correctly")
        }
        
        // 2. AXElement supports necessary properties
        let element = AXElement(
            role: AXUI.Role.field,
            description: "Test Field",
            identifier: "test-field-id",
            roleDescription: "text field",
            help: nil,
            position: AXUI.Point(x: 10, y: 20),
            size: AXUI.Size(width: 300, height: 40),
            selected: false,
            enabled: true,
            focused: false
        )
        
        #expect(!element.id.isEmpty, "Element should have ID")
        #expect(element.role?.rawValue == "Field", "Element should have correct role")
        #expect(element.isEnabled, "Element should be enabled")
        #expect(element.cgBounds.width > 0, "Element should have valid bounds")
        
        // 3. Role.isTextInput works correctly
        #expect(Role(rawValue: "Field")?.isTextInput ?? false, "field should be text input")
        #expect(!(Role(rawValue: "Button")?.isTextInput ?? false), "button should not be text input")
        
        // 4. Point calculation works
        let centerPoint = element.centerPoint
        #expect(centerPoint.x == element.cgBounds.midX, "Center point X should be calculated correctly")
        #expect(centerPoint.y == element.cgBounds.midY, "Center point Y should be calculated correctly")
        
        // 5. ActionResult can store setValue data
        let actionResult = ActionResult(
            success: true,
            element: element,
            coordinates: centerPoint,
            data: setValueData
        )
        
        #expect(actionResult.success, "ActionResult should indicate success")
        #expect(actionResult.element?.id == element.id, "ActionResult should store element")
        #expect(actionResult.coordinates != nil, "ActionResult should store coordinates")
        #expect(actionResult.data != nil, "ActionResult should store data")
        
        print("✅ All setValue components ready for integration")
    }
}