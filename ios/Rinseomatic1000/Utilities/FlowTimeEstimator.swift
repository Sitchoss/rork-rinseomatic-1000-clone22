import Foundation

struct FlowTimeEstimator {
    static func estimatedDurationMs(for flow: RecordedFlow, settings: AutomationSettings) -> Double {
        var totalMs: Double = flow.totalDurationMs

        let keystrokes = flow.actions.filter { $0.type == .keyDown }
        let totalChars = keystrokes.count
        let avgTypingMs = Double(settings.typingSpeedMinMs + settings.typingSpeedMaxMs) / 2.0
        let typingOverheadMs = Double(totalChars) * avgTypingMs

        let fieldCount = Set(flow.actions.compactMap(\.textboxLabel)).count
        let focusDelayMs = Double(fieldCount) * Double(settings.fieldFocusDelayMs)
        let interFieldMs = Double(max(0, fieldCount - 1)) * Double(settings.interFieldDelayMs)
        let preFillMs = Double(fieldCount) * Double(settings.preFillPauseMinMs + settings.preFillPauseMaxMs) / 2.0

        let clicks = flow.actions.filter { $0.type == .click || $0.type == .mouseDown }.count
        let preActionMs: Double
        if settings.randomPreActionPause {
            preActionMs = Double(clicks) * Double(settings.preActionPauseMinMs + settings.preActionPauseMaxMs) / 2.0
        } else {
            preActionMs = 0
        }

        var strictWaitMs: Double = 0
        if settings.trueDetectionStrictWaits {
            strictWaitMs += Double(settings.trueDetectionHardPauseMs)
            strictWaitMs += Double(settings.trueDetectionPostClickWaitMs)
        }

        let cyclePauseMs = Double(settings.cyclePauseMinMs + settings.cyclePauseMaxMs) / 2.0

        totalMs += typingOverheadMs
        totalMs += focusDelayMs
        totalMs += interFieldMs
        totalMs += preFillMs
        totalMs += preActionMs
        totalMs += strictWaitMs
        totalMs += cyclePauseMs

        return totalMs
    }

    static func formattedEstimate(for flow: RecordedFlow, settings: AutomationSettings) -> String {
        let ms = estimatedDurationMs(for: flow, settings: settings)
        let seconds = ms / 1000.0
        if seconds < 60 {
            return String(format: "~%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let remaining = Int(seconds) % 60
        return "~\(minutes)m \(remaining)s"
    }
}
