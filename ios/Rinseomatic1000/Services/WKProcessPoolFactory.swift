import Foundation
import WebKit

/// A synchronized factory for managing WKProcessPool allocations.
/// Creating an infinite number of WKProcessPools for thousands of credentials
/// will crash the WebKit WebContent engine. This factory allows isolated sessions
/// to safely share a process pool without actually sharing cookies, rotating the
/// pool periodically to clear zombie memory.
@MainActor
class WKProcessPoolFactory {
    static let shared = WKProcessPoolFactory()
    
    private let limitPerPool = 10
    private var currentPool: WKProcessPool = WKProcessPool()
    private var allocationCount = 0
    
    /// Requests a process pool for a new isolated web view session.
    func requestPool() -> WKProcessPool {
        allocationCount += 1
        
        if allocationCount >= limitPerPool {
            // Allocate a fresh pool to aggressively drop massive memory allocations
            // that WebKit handles silently in the background
            currentPool = WKProcessPool()
            allocationCount = 0
            DebugLogger.shared.log("WKProcessPoolFactory: Allocated fresh WebKit Process Pool (Limit \(limitPerPool) reached).", category: .webView, level: .info)
        }
        
        return currentPool
    }
    
    /// Instantly forces a pool rotation (useful after a heavy crash or large script dump)
    func forceRotatePool() {
        currentPool = WKProcessPool()
        allocationCount = 0
        DebugLogger.shared.log("WKProcessPoolFactory: FORCED rotation of WebKit Process Pool.", category: .webView, level: .warning)
    }
}
