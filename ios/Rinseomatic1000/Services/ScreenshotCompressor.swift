import UIKit
import Foundation
import CryptoKit

actor ScreenshotCompressor {
    static let shared = ScreenshotCompressor()
    
    /// Throttles and safely resizes images to prevent Memory/Main Thread freezing
    /// Downsamples images to a maximum width of 1080px (covering Task 7 as well!)
    func compressAndHash(_ image: UIImage) -> (data: Data, hash: String, resized: UIImage) {
        let resizedImage = downsampleIfNecessary(image: image, maxWidth: 1080)
        let data = resizedImage.jpegData(compressionQuality: 0.4) ?? Data()
        let hash = computeHash(data: data)
        return (data, hash, resizedImage)
    }
    
    private func downsampleIfNecessary(image: UIImage, maxWidth: CGFloat) -> UIImage {
        let size = image.size
        if size.width <= maxWidth { return image }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // Use 1.0 scale to keep byte size low
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func computeHash(data: Data) -> String {
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
