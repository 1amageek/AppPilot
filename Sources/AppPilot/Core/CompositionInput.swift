import Foundation

// MARK: - Composition Input Types (IME Support)

/// Represents the style/method of composition input
public struct InputMethodStyle: RawRepresentable, Sendable, Hashable, Codable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    // Japanese input styles
    public static let japaneseRomaji = InputMethodStyle(rawValue: "ja-romaji")
    public static let japaneseKana = InputMethodStyle(rawValue: "ja-kana")
    public static let japaneseNicola = InputMethodStyle(rawValue: "ja-nicola")
    
    // Chinese input styles
    public static let chinesePinyin = InputMethodStyle(rawValue: "zh-pinyin")
    public static let chineseZhuyin = InputMethodStyle(rawValue: "zh-zhuyin")
    public static let chineseCangjie = InputMethodStyle(rawValue: "zh-cangjie")
    public static let chineseWubi = InputMethodStyle(rawValue: "zh-wubi")
    
    // Korean input styles
    public static let koreanStandard = InputMethodStyle(rawValue: "ko-standard")
    
    // Vietnamese input styles
    public static let vietnameseTelex = InputMethodStyle(rawValue: "vi-telex")
    
    // Arabic input styles
    public static let arabicStandard = InputMethodStyle(rawValue: "ar-standard")
}

/// Represents a composition input method with language and style
public struct CompositionType: RawRepresentable, Sendable, Hashable, Codable {
    public let rawValue: String
    public let style: InputMethodStyle?
    
    public init(rawValue: String, style: InputMethodStyle? = nil) {
        self.rawValue = rawValue
        self.style = style
    }
    
    // RawRepresentable protocol conformance
    public init?(rawValue: String) {
        self.rawValue = rawValue
        self.style = nil
    }
    
    // Convenience constructors
    public static func japanese(_ style: InputMethodStyle) -> CompositionType {
        return CompositionType(rawValue: "japanese", style: style)
    }
    
    public static func chinese(_ style: InputMethodStyle) -> CompositionType {
        return CompositionType(rawValue: "chinese", style: style)
    }
    
    public static func korean(_ style: InputMethodStyle) -> CompositionType {
        return CompositionType(rawValue: "korean", style: style)
    }
    
    // Predefined common combinations
    public static let japaneseRomaji = CompositionType.japanese(.japaneseRomaji)
    public static let japaneseKana = CompositionType.japanese(.japaneseKana)
    public static let chinesePinyin = CompositionType.chinese(.chinesePinyin)
    public static let korean = CompositionType.korean(.koreanStandard)
}

/// The current state of composition input
public enum CompositionInputState: Sendable, Codable {
    /// Text is being composed but not yet converted
    case composing(text: String, suggestions: [String])
    /// User is selecting from conversion candidates
    case candidateSelection(original: String, candidates: [String], selectedIndex: Int)
    /// Input has been committed/finalized
    case committed(text: String)
}

/// Available actions for composition input
public enum CompositionInputAction: Sendable, Codable {
    case selectCandidate(index: Int)
    case nextCandidate
    case previousCandidate
    case commit
    case cancel
    case continueComposing
    case convertToAlternative  // e.g., hiragana → katakana
}

/// Result data for composition input operations
public struct CompositionInputResult: Sendable, Codable {
    /// Current composition state
    public let state: CompositionInputState
    /// The original input text (e.g., romaji)
    public let inputText: String
    /// Currently displayed text
    public let currentText: String
    /// Whether user decision is needed
    public let needsUserDecision: Bool
    /// Available actions for current state
    public let availableActions: [CompositionInputAction]
    /// The composition type used
    public let compositionType: CompositionType
    
    public init(
        state: CompositionInputState,
        inputText: String,
        currentText: String,
        needsUserDecision: Bool = false,
        availableActions: [CompositionInputAction] = [],
        compositionType: CompositionType
    ) {
        self.state = state
        self.inputText = inputText
        self.currentText = currentText
        self.needsUserDecision = needsUserDecision
        self.availableActions = availableActions
        self.compositionType = compositionType
    }
    
    /// Convenience property: available candidates for selection
    public var candidates: [String]? {
        switch state {
        case .candidateSelection(_, let candidates, _):
            return candidates
        case .composing(_, let suggestions):
            return suggestions.isEmpty ? nil : suggestions
        default:
            return nil
        }
    }
    
    /// Convenience property: currently selected candidate index
    public var selectedCandidateIndex: Int? {
        if case .candidateSelection(_, _, let index) = state {
            return index
        }
        return nil
    }
    
    /// Convenience property: whether composition is completed
    public var isCompleted: Bool {
        if case .committed = state {
            return true
        }
        return false
    }
}