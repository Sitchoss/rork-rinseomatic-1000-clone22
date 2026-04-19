import Foundation

nonisolated struct SitchCredentialLine: Codable, Sendable, Identifiable, Equatable {
    let id: String
    var email: String
    var password: String

    init(id: String = UUID().uuidString, email: String, password: String) {
        self.id = id
        self.email = email
        self.password = password
    }
}

nonisolated struct Sitchomatic1000Entry: Codable, Sendable, Identifiable, Equatable {
    let id: String
    var url: String
    var label: String
    var assignedFlowId: String?
    var assignedFlowName: String?
    var credentialList: [SitchCredentialLine]
    var isActive: Bool
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        url: String,
        label: String = "",
        assignedFlowId: String? = nil,
        assignedFlowName: String? = nil,
        credentialList: [SitchCredentialLine] = [],
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.label = label.isEmpty ? Self.deriveLabel(from: url) : label
        self.assignedFlowId = assignedFlowId
        self.assignedFlowName = assignedFlowName
        self.credentialList = credentialList
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var hasFlow: Bool { assignedFlowId != nil }
    var hasCredentials: Bool { !credentialList.isEmpty }

    var credentialDisplay: String {
        guard !credentialList.isEmpty else { return "No List" }
        return "\(credentialList.count) cred\(credentialList.count == 1 ? "" : "s")"
    }

    private static func deriveLabel(from url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
