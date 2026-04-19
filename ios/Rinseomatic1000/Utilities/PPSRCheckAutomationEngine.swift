import Foundation
import UIKit

/// Shared helpers for PPSR check automation engines (BPointAutomationEngine, PPSRAutomationEngine).
/// Eliminates duplicate `failCheck`, `advanceTo`, `speedDelay`, and `captureScreenshotForCheck` methods.
@MainActor
protocol PPSRCheckAutomationEngine: AnyObject {
    var speedMultiplier: Double { get }
    var screenshotCropRect: CGRect { get }
    var onScreenshot: ((PPSRDebugScreenshot) -> Void)? { get }
}

extension PPSRCheckAutomationEngine {

    func failCheck(_ check: PPSRCheck, message: String) {
        check.status = .failed
        check.errorMessage = message
        check.completedAt = Date()
        check.logs.append(PPSRLogEntry(message: "ERROR: \(message)", level: .error))
    }

    func advanceTo(_ status: PPSRCheckStatus, check: PPSRCheck, message: String) {
        check.status = status
        check.logs.append(PPSRLogEntry(message: message, level: status == .completed ? .success : .info))
    }

    func speedDelay(seconds: Double) async {
        let adjusted = max(0.05, seconds * speedMultiplier)
        try? await Task.sleep(for: .seconds(adjusted))
    }

    func speedDelay(milliseconds: Int) async {
        let adjusted = max(50, Int(Double(milliseconds) * speedMultiplier))
        try? await Task.sleep(for: .milliseconds(adjusted))
    }

    func captureScreenshotForCheck(session: some ScreenshotCapableSession, check: PPSRCheck, step: String, note: String, autoResult: PPSRDebugScreenshot.AutoDetectedResult = .unknown) async {
        let cropRect = screenshotCropRect == .zero ? nil : screenshotCropRect
        let result = await session.captureScreenshotWithCrop(cropRect: cropRect)
        guard let fullImage = result.full else { return }
        check.responseSnapshot = fullImage

        let screenshot = PPSRDebugScreenshot(
            stepName: step, cardDisplayNumber: check.card.displayNumber, cardId: check.card.id,
            vin: check.vin, email: check.email, image: fullImage, croppedImage: result.cropped,
            note: note, autoDetectedResult: autoResult
        )
        check.screenshotIds.append(screenshot.id)
        onScreenshot?(screenshot)
    }
}
