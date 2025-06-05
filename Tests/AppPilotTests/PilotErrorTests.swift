import Testing
import Foundation
@testable import AppPilot

@Suite("PilotError Handling Tests")
struct PilotErrorTests {
    
    // MARK: - Error Creation and Properties
    
    @Test("PilotError creation and basic properties",
          .tags(.unit, .errorHandling))
    func testPilotErrorCreation() throws {
        let errors: [(PilotError, String)] = [
            (.TIMEOUT(ms: 5000), "Operation timed out"),
            (.NOT_FOUND(.window, "123"), "Window not found"),
            (.PERMISSION_DENIED(.accessibility), "Permission denied"),
            (.OS_FAILURE(api: "CGEvent", status: -1), "System API failure"),
            (.ROUTE_UNAVAILABLE("APPLE_EVENT"), "Route unavailable"),
            (.NOT_FOUND(.application, "456"), "Application not found"),
            (.INVALID_ARG("Click failed"), "Invalid argument")
        ]
        
        for (error, expectedPrefix) in errors {
            #expect(error.localizedDescription.contains(expectedPrefix) || 
                    error.localizedDescription.lowercased().contains(expectedPrefix.lowercased()),
                    "Error description should contain expected text: \\(error)")
        }
    }
    
    @Test("PilotError timeout specific handling",
          .tags(.unit, .errorHandling))
    func testTimeoutErrorHandling() throws {
        let timeoutError = PilotError.TIMEOUT(ms: 2500)
        
        if case .TIMEOUT(let ms) = timeoutError {
            #expect(ms == 2500, "Timeout duration should be preserved")
        } else {
            #expect(Bool(false), "Error should be TIMEOUT case")
        }
        
        let description = timeoutError.localizedDescription
        #expect(description.contains("2500") || description.contains("2.5"), 
                "Timeout description should include duration")
    }
    
    @Test("PilotError window ID handling",
          .tags(.unit, .errorHandling))
    func testWindowErrorHandling() throws {
        let windowError = PilotError.NOT_FOUND(.window, "12345")
        
        if case .NOT_FOUND(let entityKind, let details) = windowError {
            #expect(entityKind == .window, "Entity kind should be window")
            #expect(details == "12345", "Window ID should be preserved")
        } else {
            #expect(Bool(false), "Error should be NOT_FOUND case")
        }
        
        let description = windowError.localizedDescription
        #expect(description.contains("12345"), "Window error should include window ID")
    }
    
    @Test("PilotError app ID handling",
          .tags(.unit, .errorHandling))
    func testAppErrorHandling() throws {
        let appError = PilotError.NOT_FOUND(.application, "67890")
        
        if case .NOT_FOUND(let entityKind, let details) = appError {
            #expect(entityKind == .application, "Entity kind should be application")
            #expect(details == "67890", "App PID should be preserved")
        } else {
            #expect(Bool(false), "Error should be NOT_FOUND case")
        }
        
        let description = appError.localizedDescription
        #expect(description.contains("67890"), "App error should include PID")
    }
    
    // MARK: - Error Equality and Comparison
    
    
    // MARK: - Error Context and Recovery Information
    
    @Test("OS failure error context",
          .tags(.unit, .errorHandling))
    func testOSFailureContext() throws {
        let osError = PilotError.OS_FAILURE(api: "CGEventCreateKeyboardEvent", status: -1)
        
        if case .OS_FAILURE(let api, let status) = osError {
            #expect(api == "CGEventCreateKeyboardEvent", "API name should be preserved")
            #expect(status == -1, "Status code should be preserved")
        } else {
            #expect(Bool(false), "Error should be OS_FAILURE case")
        }
        
        let description = osError.localizedDescription
        #expect(description.contains("CGEventCreateKeyboardEvent"), "Should include API name")
        #expect(description.contains("-1"), "Should include status code")
    }
    
    @Test("Permission error context",
          .tags(.unit, .errorHandling))
    func testPermissionErrorContext() throws {
        let permissionError = PilotError.PERMISSION_DENIED(.accessibility)
        
        if case .PERMISSION_DENIED(let kind) = permissionError {
            #expect(kind == .accessibility, "Permission kind should be accessibility")
        } else {
            #expect(Bool(false), "Error should be PERMISSION_DENIED case")
        }
        
        let description = permissionError.localizedDescription
        #expect(description.contains("Accessibility"), "Should include API name")
        #expect(description.lowercased().contains("permission"), "Should mention permission")
    }
    
    @Test("Route error context",
          .tags(.unit, .errorHandling))
    func testRouteErrorContext() throws {
        let routeError = PilotError.ROUTE_UNAVAILABLE("AX_ACTION route failed")
        
        if case .ROUTE_UNAVAILABLE(let reason) = routeError {
            #expect(reason.contains("AX_ACTION"), "Reason should contain route name")
        } else {
            #expect(Bool(false), "Error should be ROUTE_UNAVAILABLE case")
        }
        
        let description = routeError.localizedDescription
        #expect(description.contains("AX_ACTION") || description.contains("route"), 
                "Should reference route or AX_ACTION")
    }
    
    // MARK: - Error Recovery Scenarios
    
    @Test("Error recovery information",
          .tags(.unit, .errorHandling))
    func testErrorRecoveryGuidance() throws {
        // Test that error descriptions provide actionable information
        
        let permissionError = PilotError.PERMISSION_DENIED(.accessibility)
        let permissionDesc = permissionError.localizedDescription.lowercased()
        #expect(permissionDesc.contains("permission") || permissionDesc.contains("access"),
                "Permission error should mention access/permission")
        
        let timeoutError = PilotError.TIMEOUT(ms: 5000)
        let timeoutDesc = timeoutError.localizedDescription.lowercased()
        #expect(timeoutDesc.contains("timeout") || timeoutDesc.contains("time"),
                "Timeout error should mention timing")
        
        let osError = PilotError.OS_FAILURE(api: "CGEvent", status: -1)
        let osDesc = osError.localizedDescription.lowercased()
        #expect(osDesc.contains("system") || osDesc.contains("os") || osDesc.contains("api"),
                "OS error should mention system/OS/API")
    }
    
    // MARK: - Error Throwing and Catching
    
    @Test("Error throwing and catching patterns",
          .tags(.unit, .errorHandling))
    func testErrorThrowingCatching() async throws {
        // Test function that throws different types of errors
        func throwError(_ errorType: String) throws {
            switch errorType {
            case "timeout":
                throw PilotError.TIMEOUT(ms: 1000)
            case "permission":
                throw PilotError.PERMISSION_DENIED(.accessibility)
            case "window":
                throw PilotError.NOT_FOUND(.window, "123")
            default:
                throw PilotError.INVALID_ARG("Unknown error type")
            }
        }
        
        // Test timeout error catching
        do {
            try throwError("timeout")
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as PilotError {
            if case .TIMEOUT(let ms) = error {
                #expect(ms == 1000, "Caught timeout should preserve duration")
            } else {
                #expect(Bool(false), "Should have caught TIMEOUT error")
            }
        }
        
        // Test permission error catching
        do {
            try throwError("permission")
            #expect(Bool(false), "Should have thrown permission error")
        } catch let error as PilotError {
            if case .PERMISSION_DENIED(let kind) = error {
                #expect(kind == .accessibility, "Caught permission error should preserve kind")
            } else {
                #expect(Bool(false), "Should have caught PERMISSION_DENIED error")
            }
        }
        
        // Test window error catching
        do {
            try throwError("window")
            #expect(Bool(false), "Should have thrown window error")
        } catch let error as PilotError {
            if case .NOT_FOUND(let entityKind, let details) = error {
                #expect(entityKind == .window, "Entity kind should be window")
                #expect(details == "123", "Details should contain window ID")
            } else {
                #expect(Bool(false), "Should have caught NOT_FOUND error")
            }
        }
    }
    
    // MARK: - Error Chain and Nesting
    
    @Test("Invalid argument error with details",
          .tags(.unit, .errorHandling))
    func testInvalidArgumentDetails() throws {
        let detailedError = PilotError.INVALID_ARG("Click failed: target element not found at coordinates (100, 200)")
        
        if case .INVALID_ARG(let message) = detailedError {
            #expect(message.contains("Click failed"), "Should preserve error details")
            #expect(message.contains("100, 200"), "Should include coordinate information")
        } else {
            #expect(Bool(false), "Error should be INVALID_ARG case")
        }
        
        let description = detailedError.localizedDescription
        #expect(description.contains("Click failed"), "Description should include details")
    }
    
    // MARK: - Error Performance and Memory
    
    
    // MARK: - Mock Driver Error Integration
    
    @Test("Mock driver error simulation",
          .tags(.integration, .errorHandling, .mocks))
    func testMockDriverErrorSimulation() async throws {
        let mockDriver = MockAccessibilityDriver()
        
        // Test timeout simulation
        await mockDriver.setFailureMode(.timeout(after: 0.1))
        
        do {
            _ = try await mockDriver.getTree(for: WindowID(id: 1), depth: 1)
            #expect(Bool(false), "Should have thrown timeout error")
        } catch let error as PilotError {
            if case .TIMEOUT(let ms) = error {
                #expect(ms == 100, "Mock timeout should match configured duration")
            } else {
                #expect(Bool(false), "Should have thrown TIMEOUT error, got \\(error)")
            }
        }
        
        // Test OS failure simulation
        await mockDriver.setFailureMode(.osFailure(api: "AXUIElement", status: -25201))
        
        do {
            try await mockDriver.performAction(.press, at: AXPath(components: ["0"]), in: WindowID(id: 1))
            #expect(Bool(false), "Should have thrown OS failure error")
        } catch let error as PilotError {
            if case .OS_FAILURE(let api, let status) = error {
                #expect(api == "AXUIElement", "Mock OS failure should preserve API name")
                #expect(status == -25201, "Mock OS failure should preserve status code")
            } else {
                #expect(Bool(false), "Should have thrown OS_FAILURE error, got \\(error)")
            }
        }
        
        // Test permission error simulation
        await mockDriver.setFailureMode(.accessDenied)
        
        do {
            try await mockDriver.setValue("test", at: AXPath(components: ["0"]), in: WindowID(id: 1))
            #expect(Bool(false), "Should have thrown permission error")
        } catch let error as PilotError {
            if case .PERMISSION_DENIED(let kind) = error {
                #expect(kind == .accessibility, "Mock permission error should reference accessibility")
            } else {
                #expect(Bool(false), "Should have thrown PERMISSION_DENIED error, got \\(error)")
            }
        }
    }
}
