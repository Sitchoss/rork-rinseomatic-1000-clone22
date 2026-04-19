import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

@MainActor
class VisionMLService {
    static let shared = VisionMLService()

    private let logger = DebugLogger.shared
    private let ciContext = CIContext()
    private var cachedSaliencyResults: [Int: [CGRect]] = [:]

    nonisolated struct OCRElement: Sendable {
        let text: String
        let boundingBox: CGRect
        let confidence: Float
        let normalizedCenter: CGPoint

        var pixelCenter: CGPoint {
            CGPoint(x: boundingBox.midX, y: boundingBox.midY)
        }
    }

    nonisolated struct UIElementDetection: Sendable {
        let elements: [OCRElement]
        let inputFields: [OCRElement]
        let buttons: [OCRElement]
        let labels: [OCRElement]
        let imageSize: CGSize
        let processingTimeMs: Int
    }

    nonisolated struct LoginFieldDetection: Sendable {
        let emailField: FieldHit?
        let passwordField: FieldHit?
        let loginButton: FieldHit?
        let allText: [OCRElement]
        let confidence: Double
        let method: String
        let instanceMaskRegions: [MaskedRegion]
        let saliencyHotspots: [CGRect]
        let aiEnhanced: Bool

        init(emailField: FieldHit?, passwordField: FieldHit?, loginButton: FieldHit?, allText: [OCRElement], confidence: Double, method: String, instanceMaskRegions: [MaskedRegion] = [], saliencyHotspots: [CGRect] = [], aiEnhanced: Bool = false) {
            self.emailField = emailField
            self.passwordField = passwordField
            self.loginButton = loginButton
            self.allText = allText
            self.confidence = confidence
            self.method = method
            self.instanceMaskRegions = instanceMaskRegions
            self.saliencyHotspots = saliencyHotspots
            self.aiEnhanced = aiEnhanced
        }
    }

    nonisolated struct FieldHit: Sendable {
        let label: String
        let boundingBox: CGRect
        let pixelCoordinate: CGPoint
        let confidence: Float
        let nearbyText: String?
    }

    nonisolated struct MaskedRegion: Sendable {
        let instanceIndex: Int
        let boundingBox: CGRect
        let pixelArea: Int
        let overlappingText: [String]
        let predictedType: String
    }

    nonisolated struct SaliencyResult: Sendable {
        let hotspots: [CGRect]
        let primaryFocus: CGRect?
        let processingTimeMs: Int
    }

    // Feature 20: Zero-Copy CVPixelBuffer processing stream for Apple Neural Engine
    func recognizePixelBuffer(buffer: CVPixelBuffer) async -> [OCRElement] {
        return []
    }

    func recognizeAllText(in image: UIImage, clippingTo viewportCrop: CGRect? = nil) async -> [OCRElement] {
        return []
    }

    func detectLoginElements(in image: UIImage, viewportSize: CGSize) async -> LoginFieldDetection {
        return LoginFieldDetection(emailField: nil, passwordField: nil, loginButton: nil, allText: [], confidence: 0, method: "vision_ocr_stripped")
    }

    func findTextOnScreen(_ searchText: String, in image: UIImage, viewportSize: CGSize) async -> FieldHit? {
        return nil
    }

    nonisolated enum DisabledDetectionType: String, Sendable {
        case permDisabled
        case tempDisabled
        case smsDetected
        case none
    }

    func detectSuccessIndicators(in image: UIImage) async -> (welcomeFound: Bool, errorFound: Bool, context: String?) {
        return (false, false, nil)
    }

    func detectDisabledAccount(in image: UIImage) async -> (type: DisabledDetectionType, matchedText: String?, allOCRText: String) {
        return (.none, nil, "")
    }

    func detectRectangularRegions(in image: UIImage) async -> [CGRect] {
        return []
    }

    // MARK: - Instance Segmentation (Foreground Mask)

    func detectForegroundInstances(in image: UIImage) async -> [MaskedRegion] {
        return []
    }

    // MARK: - Saliency Detection

    func detectSaliency(in image: UIImage) async -> SaliencyResult {
        return SaliencyResult(hotspots: [], primaryFocus: nil, processingTimeMs: 0)
    }

    // MARK: - Deep Login Detection (OCR + Instance Mask + Saliency + AI)

    func deepDetectLoginElements(in image: UIImage, viewportSize: CGSize) async -> LoginFieldDetection {
        return LoginFieldDetection(emailField: nil, passwordField: nil, loginButton: nil, allText: [], confidence: 0, method: "deep_vision_stripped")
    }

    // MARK: - Region Classification

    private func classifyRegion(box: CGRect, imageSize: CGSize) -> String {
        let widthRatio = box.width / imageSize.width
        let heightRatio = box.height / imageSize.height
        let aspectRatio = box.width / max(box.height, 1)

        if widthRatio > 0.4 && heightRatio < 0.08 && aspectRatio > 4 {
            return "input_field"
        }
        if widthRatio > 0.2 && widthRatio < 0.6 && heightRatio < 0.06 && aspectRatio > 2.5 {
            return "button"
        }
        if widthRatio < 0.15 && heightRatio < 0.04 {
            return "label"
        }
        if widthRatio > 0.8 && heightRatio > 0.1 {
            return "banner"
        }
        return "unknown"
    }

    func clearSaliencyCache() {
        cachedSaliencyResults.removeAll()
    }

    private func estimateInputFieldBelow(labelBox: CGRect, imageSize: CGSize, scaleX: CGFloat, scaleY: CGFloat) -> CGPoint {
        let estimatedInputY = labelBox.maxY + labelBox.height * 0.8
        let centerX = labelBox.midX
        return CGPoint(
            x: centerX * scaleX,
            y: estimatedInputY * scaleY
        )
    }

    func buildVisionCalibration(from detection: LoginFieldDetection, forURL url: String) -> LoginCalibrationService.URLCalibration {
        var emailMapping: LoginCalibrationService.ElementMapping?
        if let ef = detection.emailField {
            emailMapping = LoginCalibrationService.ElementMapping(
                coordinates: ef.pixelCoordinate,
                placeholder: ef.nearbyText,
                nearbyText: ef.label
            )
        }

        var passwordMapping: LoginCalibrationService.ElementMapping?
        if let pf = detection.passwordField {
            passwordMapping = LoginCalibrationService.ElementMapping(
                coordinates: pf.pixelCoordinate,
                placeholder: pf.nearbyText,
                nearbyText: pf.label
            )
        }

        var buttonMapping: LoginCalibrationService.ElementMapping?
        if let lb = detection.loginButton {
            buttonMapping = LoginCalibrationService.ElementMapping(
                coordinates: lb.pixelCoordinate,
                nearbyText: lb.label
            )
        }

        return LoginCalibrationService.URLCalibration(
            urlPattern: url,
            emailField: emailMapping,
            passwordField: passwordMapping,
            loginButton: buttonMapping,
            notes: "Vision ML auto-calibrated (confidence: \(String(format: "%.0f%%", detection.confidence * 100)))"
        )
    }
}
