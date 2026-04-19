import Foundation

nonisolated enum FlowPlaceholderToken: String, Codable, Sendable, CaseIterable {
    case userEmail = "userEmail"
    case userPassword = "userPassword"
    case cardNumber = "cardNumber"
    case expMonth = "expMonth"
    case expYear = "expYear"
    case cvv = "cvv"
    case submitButton = "submitButton"
    case depositAmount = "depositAmount"
    case miscTextbox1 = "miscTextbox1"
    case miscTextbox2 = "miscTextbox2"
    case miscTextbox3 = "miscTextbox3"

    var templateKey: String {
        switch self {
        case .userEmail: return "{{USER_EMAIL}}"
        case .userPassword: return "{{USER_PASSWORD}}"
        case .cardNumber: return "{{CARD_NUMBER}}"
        case .expMonth: return "{{EXP_MONTH}}"
        case .expYear: return "{{EXP_YEAR}}"
        case .cvv: return "{{CVV}}"
        case .submitButton: return "{{SUBMIT_BUTTON}}"
        case .depositAmount: return "{{DEPOSIT_AMOUNT}}"
        case .miscTextbox1: return "{{MISC_TEXTBOX1}}"
        case .miscTextbox2: return "{{MISC_TEXTBOX2}}"
        case .miscTextbox3: return "{{MISC_TEXTBOX3}}"
        }
    }

    var displayLabel: String {
        switch self {
        case .userEmail: return "Email"
        case .userPassword: return "Password"
        case .cardNumber: return "Card Number"
        case .expMonth: return "Expiry Month"
        case .expYear: return "Expiry Year"
        case .cvv: return "CVV / CVC"
        case .submitButton: return "Submit Button"
        case .depositAmount: return "Deposit Amount"
        case .miscTextbox1: return "Field 1"
        case .miscTextbox2: return "Field 2"
        case .miscTextbox3: return "Field 3"
        }
    }

    static func detect(
        fromLabel label: String,
        targetType: String?,
        name: String? = nil,
        id: String? = nil,
        placeholder: String? = nil,
        autocomplete: String? = nil,
        labelText: String? = nil
    ) -> FlowPlaceholderToken? {
        let l = label.lowercased()
        let t = targetType?.lowercased() ?? ""
        
        let semanticStrings = [
            l,
            t,
            name?.lowercased() ?? "",
            id?.lowercased() ?? "",
            placeholder?.lowercased() ?? "",
            autocomplete?.lowercased() ?? "",
            labelText?.lowercased() ?? ""
        ]
        
        func matches(_ keywords: [String]) -> Bool {
            for s in semanticStrings {
                for k in keywords {
                    if s.contains(k) { return true }
                }
            }
            return false
        }

        if matches(["email", "e-mail"]) {
            return .userEmail
        }
        if matches(["password"]) {
            return .userPassword
        }
        if matches(["card", "number", "pan"]) {
            return .cardNumber
        }
        if matches(["month", "mm"]) {
            return .expMonth
        }
        if matches(["year", "yy"]) {
            return .expYear
        }
        if matches(["cvv", "cvc", "security"]) {
            return .cvv
        }
        if matches(["submit", "login", "sign in", "log in", "signin"]) {
            return .submitButton
        }
        if matches(["deposit", "amount"]) {
            return .depositAmount
        }
        return nil
    }
}

nonisolated struct RecordedFlow: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    let url: String
    let createdAt: Date
    var actions: [RecordedAction]
    var textboxMappings: [TextboxMapping]
    var totalDurationMs: Double
    var actionCount: Int

    nonisolated struct TextboxMapping: Codable, Sendable, Identifiable {
        let id: String
        let label: String
        let selector: String
        let originalText: String
        var placeholderKey: String
        var assignedToken: FlowPlaceholderToken?

        init(
            id: String = UUID().uuidString,
            label: String,
            selector: String,
            originalText: String,
            placeholderKey: String,
            assignedToken: FlowPlaceholderToken? = nil
        ) {
            self.id = id
            self.label = label
            self.selector = selector
            self.originalText = originalText
            self.placeholderKey = placeholderKey
            self.assignedToken = assignedToken
        }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        url: String,
        createdAt: Date = Date(),
        actions: [RecordedAction] = [],
        textboxMappings: [TextboxMapping] = [],
        totalDurationMs: Double = 0,
        actionCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.createdAt = createdAt
        self.actions = actions
        self.textboxMappings = textboxMappings
        self.totalDurationMs = totalDurationMs
        self.actionCount = actionCount
    }

    var formattedDuration: String {
        let seconds = totalDurationMs / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let remaining = Int(seconds) % 60
        return "\(minutes)m \(remaining)s"
    }

    var summary: String {
        let mouseActions = actions.filter { $0.type == .mouseMove }.count
        let clicks = actions.filter { $0.type == .click || $0.type == .mouseDown }.count
        let keystrokes = actions.filter { $0.type == .keyDown }.count
        let scrolls = actions.filter { $0.type == .scroll }.count
        return "Mouse:\(mouseActions) Clicks:\(clicks) Keys:\(keystrokes) Scrolls:\(scrolls)"
    }
}
