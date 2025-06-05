import Foundation
import SwiftUI

// MARK: - Test Result Models

struct TestResult: Identifiable, Codable {
    let id = UUID()
    let testType: TestType
    let success: Bool
    let timestamp: Date
    let details: String
    let coordinates: CGPoint?
    let expectedValue: String?
    let actualValue: String?
    let duration: TimeInterval?
    
    init(
        testType: TestType,
        success: Bool,
        details: String,
        coordinates: CGPoint? = nil,
        expectedValue: String? = nil,
        actualValue: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.testType = testType
        self.success = success
        self.timestamp = Date()
        self.details = details
        self.coordinates = coordinates
        self.expectedValue = expectedValue
        self.actualValue = actualValue
        self.duration = duration
    }
}

enum TestType: String, CaseIterable, Codable {
    case mouseClick = "Mouse Click"
    case keyboard = "Keyboard"
    case wait = "Wait"
    case resolve = "App/Window Resolve"
    case integration = "Integration"
    
    var icon: String {
        switch self {
        case .mouseClick: return "cursorarrow.click"
        case .keyboard: return "keyboard"
        case .wait: return "clock"
        case .resolve: return "app.badge"
        case .integration: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .mouseClick: return .blue
        case .keyboard: return .green
        case .wait: return .orange
        case .resolve: return .purple
        case .integration: return .red
        }
    }
}

// MARK: - Mouse Click Test Models

enum MouseButton: String, CaseIterable {
    case left = "Left"
    case right = "Right"
    case center = "Center"
    
    var systemImage: String {
        switch self {
        case .left: return "hand.point.up.left"
        case .right: return "hand.point.up.right"
        case .center: return "hand.point.up"
        }
    }
}

struct ClickTarget: Identifiable {
    let id = UUID()
    let position: CGPoint
    let label: String
    var isClicked: Bool = false
    
    init(position: CGPoint, label: String) {
        self.position = position
        self.label = label
    }
}

// MARK: - Keyboard Test Models

struct KeyboardTestCase: Identifiable {
    let id = UUID()
    let name: String
    let input: String
    let description: String
    
    static let presets: [KeyboardTestCase] = [
        KeyboardTestCase(
            name: "Basic Text",
            input: "Hello123",
            description: "Basic alphanumeric characters"
        ),
        KeyboardTestCase(
            name: "Special Characters",
            input: "!@#$%^&*()",
            description: "Special symbols and punctuation"
        ),
        KeyboardTestCase(
            name: "Japanese Text",
            input: "こんにちは世界",
            description: "Unicode characters (Japanese)"
        ),
        KeyboardTestCase(
            name: "Control Characters",
            input: "Line1\nLine2\tTabbed",
            description: "Newline and tab characters"
        ),
        KeyboardTestCase(
            name: "Mixed Content",
            input: "Test123!@# こんにちは\nNew line",
            description: "Mixed alphanumeric, symbols, Unicode, and control chars"
        )
    ]
}

// MARK: - Wait Test Models

struct WaitTestConfig {
    var duration: TimeInterval = 1.0
    var condition: WaitCondition = .time
    
    enum WaitCondition: String, CaseIterable {
        case time = "Time-based"
        case uiChange = "UI Change"
        
        var description: String {
            switch self {
            case .time: return "Wait for specified duration"
            case .uiChange: return "Wait for UI element to change"
            }
        }
    }
}

struct WaitTestResult {
    let requestedDuration: TimeInterval
    let actualDuration: TimeInterval
    let accuracy: Double // Percentage accuracy
    let condition: WaitTestConfig.WaitCondition
    
    var accuracyFormatted: String {
        return String(format: "%.1f%%", accuracy * 100)
    }
    
    var errorMargin: TimeInterval {
        return abs(actualDuration - requestedDuration)
    }
}

// MARK: - App Resolution Models

struct AppInfo: Identifiable {
    let id = UUID()
    let bundleId: String?
    let name: String
    let pid: Int32
    let windowCount: Int
    let isActive: Bool
    
    init(bundleId: String?, name: String, pid: Int32, windowCount: Int, isActive: Bool = false) {
        self.bundleId = bundleId
        self.name = name
        self.pid = pid
        self.windowCount = windowCount
        self.isActive = isActive
    }
}

struct WindowInfo: Identifiable {
    let id = UUID()
    let title: String?
    let index: Int
    let frame: CGRect
    let appName: String
    
    init(title: String?, index: Int, frame: CGRect, appName: String) {
        self.title = title
        self.index = index
        self.frame = frame
        self.appName = appName
    }
}

// MARK: - Integration Test Models

struct IntegrationScenario: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let steps: [IntegrationStep]
    
    static let scenarios: [IntegrationScenario] = [
        IntegrationScenario(
            name: "Basic Click and Type",
            description: "Click on a text field and type text",
            steps: [
                IntegrationStep(action: "Find text field", description: "Locate the input text field"),
                IntegrationStep(action: "Click text field", description: "Click to focus the text field"),
                IntegrationStep(action: "Type text", description: "Enter sample text"),
                IntegrationStep(action: "Verify input", description: "Check that text was entered correctly")
            ]
        ),
        IntegrationScenario(
            name: "Multi-button Sequence",
            description: "Click multiple buttons in sequence",
            steps: [
                IntegrationStep(action: "Click button 1", description: "Click top-left button"),
                IntegrationStep(action: "Wait", description: "Wait for 500ms"),
                IntegrationStep(action: "Click button 2", description: "Click top-right button"),
                IntegrationStep(action: "Wait", description: "Wait for 500ms"),
                IntegrationStep(action: "Click center", description: "Click center button"),
                IntegrationStep(action: "Verify sequence", description: "Check all buttons were clicked")
            ]
        )
    ]
}

struct IntegrationStep: Identifiable {
    let id = UUID()
    let action: String
    let description: String
    var isCompleted: Bool = false
    var success: Bool = false
    var error: String?
    
    init(action: String, description: String) {
        self.action = action
        self.description = description
    }
}