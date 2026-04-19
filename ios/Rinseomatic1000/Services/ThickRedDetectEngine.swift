import Foundation
import WebKit
import UIKit
import CoreGraphics

nonisolated enum ThickRedDetectResult: Sendable {
    case noRedDetected
    case crimsonHit(pollCount: Int, elapsedMs: Int)
    case snapshotFailed(reason: String)
    case cancelled
}

nonisolated enum ThickRedDetectError: Error, Sendable {
    case webViewUnavailable
    case cancelled
    case snapshotFailed(String)
}

@MainActor
final class ThickRedDetectEngine {
    static let shared = ThickRedDetectEngine()

    private let logger = DebugLogger.shared

    private static let pollIntervalMs: Int = 150
    private static let successTimeoutSeconds: Double = 3.0
    private static let sampleRect = CGRect(x: 40, y: 20, width: 15, height: 15)
    private static let totalPixels: Int = 15 * 15 // 225

    private static let redMinimum: UInt8 = 160
    private static let greenMaximum: UInt8 = 90
    private static let blueMaximum: UInt8 = 90

    func runPostSubmitDetection(
        webView: WKWebView,
        sessionId: String = "",
        onRedDetected: @escaping @Sendable () async -> Void,
        onNoRed: @escaping @Sendable () async -> Void
    ) async {
        logger.log("ThickRedDetect: BEGIN post-submit pixel sniper race", category: .evaluation, level: .info, sessionId: sessionId)

        let result = await executeDetectionRace(webView: webView, sessionId: sessionId)

        switch result {
        case .crimsonHit(let pollCount, let elapsedMs):
            logger.log("ThickRedDetect: CRIMSON HIT — poll #\(pollCount) at \(elapsedMs)ms", category: .evaluation, level: .critical, sessionId: sessionId)
            await onRedDetected()

        case .noRedDetected:
            logger.log("ThickRedDetect: NO RED — 3s timeout elapsed, treating as success path", category: .evaluation, level: .success, sessionId: sessionId)
            await onNoRed()

        case .snapshotFailed(let reason):
            logger.log("ThickRedDetect: SNAPSHOT FAILED — \(reason), defaulting to success path", category: .evaluation, level: .warning, sessionId: sessionId)
            await onNoRed()

        case .cancelled:
            logger.log("ThickRedDetect: CANCELLED", category: .evaluation, level: .warning, sessionId: sessionId)
        }
    }

    func executeDetectionRace(
        webView: WKWebView,
        sessionId: String = ""
    ) async -> ThickRedDetectResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        return await withCheckedContinuation { continuation in
            var didResume = false
            let lock = NSLock()

            func resumeOnce(_ result: ThickRedDetectResult) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: result)
            }

            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: .seconds(Self.successTimeoutSeconds))
                    resumeOnce(.noRedDetected)
                } catch {
                    resumeOnce(.cancelled)
                }
            }

            Task { [weak self] in
                guard let self else {
                    resumeOnce(.cancelled)
                    return
                }
                let loopResult = await self.pixelSniperLoop(webView: webView, startTime: startTime, sessionId: sessionId)
                timeoutTask.cancel()
                resumeOnce(loopResult)
            }
        }
    }

    private func pixelSniperLoop(
        webView: WKWebView,
        startTime: CFAbsoluteTime,
        sessionId: String
    ) async -> ThickRedDetectResult {
        var pollCount = 0

        while !Task.isCancelled {
            pollCount += 1

            let snapshotResult = await captureTargetPixels(webView: webView, pollCount: pollCount, sessionId: sessionId)

            switch snapshotResult {
            case .hit:
                let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                return .crimsonHit(pollCount: pollCount, elapsedMs: elapsedMs)
            case .miss:
                break
            case .error(let reason):
                if pollCount > 5 {
                    return .snapshotFailed(reason: reason)
                }
            }

            guard !Task.isCancelled else { return .cancelled }

            do {
                try await Task.sleep(for: .milliseconds(Self.pollIntervalMs))
            } catch {
                return .cancelled
            }
        }

        return .cancelled
    }

    private nonisolated enum PixelCheckResult {
        case hit
        case miss
        case error(String)
    }

    private func captureTargetPixels(
        webView: WKWebView,
        pollCount: Int,
        sessionId: String
    ) async -> PixelCheckResult {
        let config = WKSnapshotConfiguration()
        config.rect = Self.sampleRect

        let snapshot: UIImage
        do {
            snapshot = try await webView.takeSnapshot(configuration: config)
        } catch {
            return .error("takeSnapshot threw: \(error.localizedDescription)")
        }

        guard let cgImage = snapshot.cgImage else {
            return .error("cgImage nil from snapshot")
        }

        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            return .error("dataProvider or data nil")
        }

        let ptr: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height

        let bitmapInfo = cgImage.bitmapInfo
        let alphaInfo = CGImageAlphaInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue) ?? .noneSkipLast
        let byteOrder = CGBitmapInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue)

        let isBGRA: Bool
        if byteOrder == .byteOrder32Little {
            isBGRA = true
        } else {
            isBGRA = false
        }

        let rOffset: Int
        let gOffset: Int
        let bOffset: Int

        if isBGRA {
            rOffset = 2
            gOffset = 1
            bOffset = 0
        } else {
            switch alphaInfo {
            case .first, .premultipliedFirst, .noneSkipFirst:
                rOffset = 1
                gOffset = 2
                bOffset = 3
            default:
                rOffset = 0
                gOffset = 1
                bOffset = 2
            }
        }

        guard bytesPerPixel >= 3 else {
            return .error("unexpected bytesPerPixel=\(bytesPerPixel)")
        }

        let pixelCount = width * height
        guard pixelCount > 0 else {
            return .error("zero pixels in snapshot")
        }

        var crimsonCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = ptr[offset + rOffset]
                let g = ptr[offset + gOffset]
                let b = ptr[offset + bOffset]

                if r > Self.redMinimum && g < Self.greenMaximum && b < Self.blueMaximum {
                    crimsonCount += 1
                }
            }
        }

        if crimsonCount == pixelCount {
            logger.log("ThickRedDetect: poll #\(pollCount) — ALL \(pixelCount) pixels CRIMSON (\(width)x\(height))", category: .evaluation, level: .critical, sessionId: sessionId)
            return .hit
        } else {
            if pollCount <= 3 || pollCount % 10 == 0 {
                logger.log("ThickRedDetect: poll #\(pollCount) — \(crimsonCount)/\(pixelCount) crimson pixels (miss)", category: .evaluation, level: .trace, sessionId: sessionId)
            }
            return .miss
        }
    }
}
