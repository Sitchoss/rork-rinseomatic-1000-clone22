import Foundation

nonisolated enum CredentialBurnPolicy: String, Codable, Sendable, CaseIterable, Identifiable {
    case afterAllAttempts
    case onDisableOnly
    case afterEach

    var id: String { rawValue }

    var title: String {
        switch self {
        case .afterAllAttempts:
            return "After All Attempts"
        case .onDisableOnly:
            return "On Disable Only"
        case .afterEach:
            return "After Each Failure"
        }
    }

    var shortLabel: String {
        switch self {
        case .afterAllAttempts:
            return "Protected"
        case .onDisableOnly:
            return "Disable Only"
        case .afterEach:
            return "Legacy"
        }
    }

    var detail: String {
        switch self {
        case .afterAllAttempts:
            return "Burn only after repeated no-account evidence or explicit disable signals."
        case .onDisableOnly:
            return "Protect no-account results and only burn explicit disabled accounts."
        case .afterEach:
            return "Legacy aggressive mode that allows immediate burn on terminal failures."
        }
    }

    var allowsAutoBlacklistNoAcc: Bool {
        self == .afterEach
    }

    func allowsBurn(
        status: CredentialStatus,
        fullLoginAttemptCount: Int,
        accountConfirmed: Bool
    ) -> Bool {
        switch self {
        case .afterAllAttempts:
            switch status {
            case .permDisabled:
                return true
            case .noAcc:
                return fullLoginAttemptCount >= 2 && !accountConfirmed
            case .tempDisabled:
                return false
            case .untested, .testing, .working:
                return false
            }
        case .onDisableOnly:
            return status == .permDisabled
        case .afterEach:
            switch status {
            case .noAcc, .permDisabled, .tempDisabled:
                return true
            case .untested, .testing, .working:
                return false
            }
        }
    }

    func protectionReason(
        status: CredentialStatus,
        fullLoginAttemptCount: Int,
        accountConfirmed: Bool
    ) -> String? {
        guard !allowsBurn(
            status: status,
            fullLoginAttemptCount: fullLoginAttemptCount,
            accountConfirmed: accountConfirmed
        ) else {
            return nil
        }

        switch self {
        case .afterAllAttempts:
            if status == .tempDisabled {
                return "Temp disabled accounts stay protected because the account is confirmed to exist."
            }
            if status == .noAcc {
                return "No-account credentials stay protected until repeated full attempts confirm the result."
            }
            return "This credential is protected by the current burn policy."
        case .onDisableOnly:
            return "Only permanently disabled accounts can be burned in this mode."
        case .afterEach:
            return "Only untested, testing, and working credentials stay protected in legacy mode."
        }
    }
}
