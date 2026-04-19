import Foundation

nonisolated enum ActiveAppMode: String, Sendable {
    case unifiedSession
    case credentialHub
    case ppsr
    case toolsAndTesting
    case settings
    case customSitch
    case superTest
    case debugLog
    case flowRecorder
    case nordConfig
    case vault
    case ipScoreTest
    case dualFind
    case proxyManager
    case testDebug
    case sitchomatic1000
}
