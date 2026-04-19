import Foundation
import SwiftUI

nonisolated enum LiveResultReviewOutcome: String, Sendable, CaseIterable, Identifiable {
    case success
    case permDisabled
    case tempDisabled
    case noAcc
    case connectionFailure
    case redBannerError
    case smsDetected
    case noresultyet

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .success: "SUCCESS"
        case .permDisabled: "PERM DISABLED"
        case .tempDisabled: "TEMP DISABLED"
        case .noAcc: "NO ACC"
        case .connectionFailure: "CONN FAILURE"
        case .redBannerError: "RED BANNER"
        case .smsDetected: "SMS DETECTED"
        case .noresultyet: "NO RESULT YET"
        }
    }

    var shortLabel: String {
        switch self {
        case .success: "SUCCESS"
        case .permDisabled: "PERM DIS"
        case .tempDisabled: "TEMP DIS"
        case .noAcc: "NOACC"
        case .connectionFailure: "CONNFAIL"
        case .redBannerError: "REDBANNER"
        case .smsDetected: "SMS"
        case .noresultyet: "NORESULT"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .permDisabled: .red
        case .tempDisabled: .orange
        case .noAcc: .secondary
        case .connectionFailure: .purple
        case .redBannerError: .red
        case .smsDetected: .indigo
        case .noresultyet: .cyan
        }
    }

    var icon: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .permDisabled: "lock.slash.fill"
        case .tempDisabled: "clock.badge.exclamationmark"
        case .noAcc: "xmark.circle.fill"
        case .connectionFailure: "wifi.slash"
        case .redBannerError: "exclamationmark.octagon.fill"
        case .smsDetected: "message.fill"
        case .noresultyet: "hourglass"
        }
    }

    var description: String {
        switch self {
        case .success: "Account logged in — dashboard/balance visible"
        case .permDisabled: "Account permanently disabled/suspended/closed"
        case .tempDisabled: "Temporarily locked (too many attempts)"
        case .noAcc: "Wrong password or account not found"
        case .connectionFailure: "Page didn't load — should've reloaded this session"
        case .redBannerError: "Red/orange error banner visible on page"
        case .smsDetected: "SMS/phone verification prompt detected"
        case .noresultyet: "Login button still depressed/loading — not returned to normal"
        }
    }

    static func fromLoginOutcome(_ outcome: LoginOutcome) -> LiveResultReviewOutcome {
        switch outcome {
        case .success: .success
        case .permDisabled: .permDisabled
        case .tempDisabled: .tempDisabled
        case .noAcc: .noAcc
        case .connectionFailure, .timeout: .connectionFailure
        case .smsDetected: .smsDetected
        }
    }

    static func fromSiteResult(_ result: SiteResult) -> LiveResultReviewOutcome {
        switch result {
        case .success: .success
        case .permDisabled: .permDisabled
        case .tempDisabled: .tempDisabled
        case .noAccount: .noAcc
        case .pending: .noresultyet
        }
    }

    var toLoginOutcome: LoginOutcome {
        switch self {
        case .success: .success
        case .permDisabled: .permDisabled
        case .tempDisabled: .tempDisabled
        case .noAcc: .noAcc
        case .connectionFailure: .connectionFailure
        case .redBannerError: .noAcc
        case .smsDetected: .smsDetected
        case .noresultyet: .timeout
        }
    }

    var toCredentialStatus: CredentialStatus {
        switch self {
        case .success: .working
        case .permDisabled: .permDisabled
        case .tempDisabled: .tempDisabled
        case .noAcc, .connectionFailure, .redBannerError, .smsDetected, .noresultyet: .noAcc
        }
    }
}

nonisolated struct LiveResultReviewItem: Identifiable, Sendable {
    let id: String
    let credentialEmail: String
    let credentialPassword: String
    let sessionId: String
    let joeDetectedOutcome: LiveResultReviewOutcome
    let ignitionDetectedOutcome: LiveResultReviewOutcome
    let joeScreenshotData: Data?
    let ignitionScreenshotData: Data?
    let joeConfidence: Double
    let ignitionConfidence: Double
    let joeOCRText: String
    let ignitionOCRText: String
    let timestamp: Date

    init(
        credentialEmail: String,
        credentialPassword: String,
        sessionId: String,
        joeDetectedOutcome: LiveResultReviewOutcome,
        ignitionDetectedOutcome: LiveResultReviewOutcome,
        joeScreenshotData: Data?,
        ignitionScreenshotData: Data?,
        joeConfidence: Double,
        ignitionConfidence: Double,
        joeOCRText: String = "",
        ignitionOCRText: String = ""
    ) {
        self.id = UUID().uuidString
        self.credentialEmail = credentialEmail
        self.credentialPassword = credentialPassword
        self.sessionId = sessionId
        self.joeDetectedOutcome = joeDetectedOutcome
        self.ignitionDetectedOutcome = ignitionDetectedOutcome
        self.joeScreenshotData = joeScreenshotData
        self.ignitionScreenshotData = ignitionScreenshotData
        self.joeConfidence = joeConfidence
        self.ignitionConfidence = ignitionConfidence
        self.joeOCRText = joeOCRText
        self.ignitionOCRText = ignitionOCRText
        self.timestamp = Date()
    }

    var pairedLabel: String {
        "\(joeDetectedOutcome.shortLabel) / \(ignitionDetectedOutcome.shortLabel)"
    }
}

nonisolated struct ResultCorrectionRecord: Codable, Sendable {
    let id: String
    let credentialEmail: String
    let sessionId: String
    let site: String
    let aiDetectedOutcome: String
    let userCorrectedOutcome: String
    let aiConfidence: Double
    let highlightRegions: [HighlightRegion]
    let ocrTextAtCorrection: String
    let timestamp: Date
    let settingsSnapshotJSON: String?
}

nonisolated struct HighlightRegion: Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let label: String
}

nonisolated struct AIWeightAdjustment: Codable, Sendable {
    let outcome: String
    let keywordAdjustments: [String: Double]
    let confidenceShift: Double
    let appliedAt: Date
    let reason: String
}
