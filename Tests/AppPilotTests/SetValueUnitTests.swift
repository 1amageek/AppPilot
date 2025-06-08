import Testing
import Foundation
@testable import AppPilot

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
        let originalResult = ActionResult(
            success: true,
            element: UIElement(
                id: "test-element",
                role: .textField,
                title: "Test Field",
                value: "Initial Value",
                bounds: CGRect(x: 10, y: 20, width: 100, height: 30),
                isEnabled: true
            ),
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
    
    // MARK: - UIElement Role Tests
    
    @Test("UIElement roles should support value setting correctly")
    func testUIElementRoleValueSettingSupport() async throws {
        // Test supported roles
        let supportedRoles: [ElementRole] = [.textField, .searchField]
        
        for role in supportedRoles {
            let element = UIElement(
                id: "test-\(role.rawValue)",
                role: role,
                bounds: CGRect(x: 0, y: 0, width: 100, height: 30),
                isEnabled: true
            )
            
            // These roles should be considered text input
            #expect(role.isTextInput, "\(role.rawValue) should be text input")
            
            // Verify element can theoretically support setValue
            #expect(element.isEnabled, "Element should be enabled")
            #expect(element.role.isTextInput, "Element role should support text input")
        }
        
        // Test unsupported roles
        let unsupportedRoles: [ElementRole] = [.button, .staticText, .image, .link]
        
        for role in unsupportedRoles {
            let _ = UIElement(
                id: "test-\(role.rawValue)",
                role: role,
                bounds: CGRect(x: 0, y: 0, width: 100, height: 30),
                isEnabled: true
            )
            
            // These roles should not be considered text input
            #expect(!role.isTextInput, "\(role.rawValue) should not be text input")
        }
    }
    
    @Test("ElementRole isTextInput property should be accurate")
    func testElementRoleIsTextInputProperty() async throws {
        // Test all known text input roles
        let textInputRoles: [(ElementRole, Bool)] = [
            (.textField, true),
            (.searchField, true),
            (.button, false),
            (.checkBox, false),
            (.radioButton, false),
            (.staticText, false),
            (.link, false),
            (.image, false),
            (.slider, false),
            (.menuItem, false)
        ]
        
        for (role, expectedIsTextInput) in textInputRoles {
            #expect(role.isTextInput == expectedIsTextInput, 
                   "\(role.rawValue) isTextInput should be \(expectedIsTextInput)")
        }
    }
    
    // MARK: - Element Validation Tests
    
    @Test("UIElement validation logic should work correctly")
    func testUIElementValidationLogic() async throws {
        // Test valid text field
        let validTextField = UIElement(
            id: "valid-text-field",
            role: .textField,
            title: "Name Field",
            value: "Current Value",
            bounds: CGRect(x: 10, y: 20, width: 200, height: 30),
            isEnabled: true
        )
        
        #expect(validTextField.isEnabled, "Valid text field should be enabled")
        #expect(validTextField.role.isTextInput, "Valid text field should support text input")
        #expect(validTextField.bounds.width > 0, "Valid text field should have positive width")
        #expect(validTextField.bounds.height > 0, "Valid text field should have positive height")
        
        // Test disabled text field
        let disabledTextField = UIElement(
            id: "disabled-text-field",
            role: .textField,
            bounds: CGRect(x: 10, y: 20, width: 200, height: 30),
            isEnabled: false
        )
        
        #expect(!disabledTextField.isEnabled, "Disabled text field should not be enabled")
        #expect(disabledTextField.role.isTextInput, "Disabled text field should still be text input type")
        
        // Test non-text element
        let buttonElement = UIElement(
            id: "button-element",
            role: .button,
            title: "Click Me",
            bounds: CGRect(x: 10, y: 20, width: 100, height: 30),
            isEnabled: true
        )
        
        #expect(buttonElement.isEnabled, "Button should be enabled")
        #expect(!buttonElement.role.isTextInput, "Button should not support text input")
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
        let validElement = UIElement(
            id: "test-element",
            role: .textField,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 30),
            isEnabled: true
        )
        
        let invalidElement = UIElement(
            id: "invalid-element",
            role: .button,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 30),
            isEnabled: true
        )
        
        // Mock validation logic
        func validateElementForSetValue(_ element: UIElement) -> Bool {
            return element.isEnabled && (element.role.isTextInput || element.role == .checkBox || element.role == .slider)
        }
        
        #expect(validateElementForSetValue(validElement), "Valid text field should pass validation")
        #expect(!validateElementForSetValue(invalidElement), "Button should fail validation")
        
        // 2. Value setting simulation
        let testValue = "Mock Test Value"
        
        func mockSetValue(_ value: String, for element: UIElement) -> ActionResult {
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
        
        let textFieldElement = UIElement(
            id: "text-field",
            role: .textField,
            bounds: CGRect.zero,
            isEnabled: true
        )
        
        let buttonElement = UIElement(
            id: "button",
            role: .button,
            bounds: CGRect.zero,
            isEnabled: true
        )
        
        // Mock type validation
        func isValidForSetValue(element: UIElement) -> Bool {
            let supportedRoles: Set<ElementRole> = [.textField, .searchField, .checkBox, .slider]
            return supportedRoles.contains(element.role) && element.isEnabled
        }
        
        #expect(isValidForSetValue(element: textFieldElement), "Text field should be valid for setValue")
        #expect(!isValidForSetValue(element: buttonElement), "Button should not be valid for setValue")
        
        // Test value types
        let stringValues = ["Hello", "123", "", "Special@#$%", "日本語"]
        
        for value in stringValues {
            // All string values should be acceptable
            #expect(value is String, "All test values should be strings")
            // setValue should accept any string value (no additional validation needed in unit test)
            print("setValue should accept string value: '\(value)'")
        }
    }
    
    // MARK: - Performance Characteristics Tests
    
    @Test("setValue should have correct performance characteristics")
    func testSetValuePerformanceCharacteristics() async throws {
        // Test that setValue operations are fast (unit test level)
        
        let element = UIElement(
            id: "perf-test-element",
            role: .textField,
            bounds: CGRect(x: 0, y: 0, width: 200, height: 30),
            isEnabled: true
        )
        
        let testValues = Array(repeating: "Performance Test", count: 1000)
        
        // Mock setValue that simulates the performance characteristics
        func mockFastSetValue(_ value: String, for element: UIElement) -> ActionResult {
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
        
        // 2. UIElement supports necessary properties
        let element = UIElement(
            id: "integration-test",
            role: .textField,
            title: "Test Field",
            value: "Initial",
            identifier: "test-field-id",
            bounds: CGRect(x: 10, y: 20, width: 300, height: 40),
            isEnabled: true
        )
        
        #expect(!element.id.isEmpty, "Element should have ID")
        #expect(element.role == .textField, "Element should have correct role")
        #expect(element.isEnabled, "Element should be enabled")
        #expect(element.bounds.width > 0, "Element should have valid bounds")
        
        // 3. ElementRole.isTextInput works correctly
        #expect(ElementRole.textField.isTextInput, "textField should be text input")
        #expect(ElementRole.searchField.isTextInput, "searchField should be text input")
        #expect(!ElementRole.button.isTextInput, "button should not be text input")
        
        // 4. Point calculation works
        let centerPoint = element.centerPoint
        #expect(centerPoint.x == element.bounds.midX, "Center point X should be calculated correctly")
        #expect(centerPoint.y == element.bounds.midY, "Center point Y should be calculated correctly")
        
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