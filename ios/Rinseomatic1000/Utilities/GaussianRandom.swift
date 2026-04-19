import Foundation

/// Centralized Gaussian (Box-Muller) random number utilities.
/// Replaces duplicate implementations across the codebase.
enum GaussianRandom {

    /// Generate a Gaussian-distributed random value with given mean and standard deviation.
    static func sample(mean: Double, stdDev: Double) -> Double {
        let u1 = Double.random(in: 0.0001...0.9999)
        let u2 = Double.random(in: 0.0001...0.9999)
        let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        return mean + z * stdDev
    }

    /// Generate a Gaussian-distributed delay in milliseconds, clamped to [minMs, maxMs].
    static func delay(minMs: Int, maxMs: Int) -> Int {
        let mean = Double(minMs + maxMs) / 2.0
        let stdDev = Double(maxMs - minMs) / 4.0
        let value = sample(mean: mean, stdDev: stdDev)
        return max(minMs, min(maxMs, Int(value)))
    }

    /// Generate a Gaussian-distributed jitter value clamped to [-range, +range].
    static func jitter(range: Int) -> Double {
        let value = sample(mean: 0, stdDev: Double(range) / 3.0)
        return max(Double(-range), min(Double(range), value))
    }
}
