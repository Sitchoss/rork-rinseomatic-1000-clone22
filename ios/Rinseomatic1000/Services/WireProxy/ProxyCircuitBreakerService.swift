import Foundation

final class ProxyCircuitBreakerService: @unchecked Sendable {
    static let shared = ProxyCircuitBreakerService()

    private var slotStates: [Int: CircuitState] = [:]
    private let lock = NSLock()

    private let failureThreshold: Int = 3
    private let baseCooldownSeconds: TimeInterval = 60
    private let halfOpenMaxProbes: Int = 2

    private struct CircuitState {
        var status: BreakerStatus = .closed
        var failureCount: Int = 0
        var openedAt: Date?
        var halfOpenProbes: Int = 0
        var consecutiveTrips: Int = 0
        var effectiveCooldown: TimeInterval = 60

        var isTripped: Bool {
            switch status {
            case .open: return true
            case .halfOpen, .closed: return false
            }
        }
    }

    enum BreakerStatus: String, Sendable {
        case closed
        case open
        case halfOpen
    }

    func isAllowed(slot: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard var state = slotStates[slot] else { return true }

        switch state.status {
        case .closed:
            return true
        case .open:
            if let opened = state.openedAt, Date().timeIntervalSince(opened) >= state.effectiveCooldown {
                state.status = .halfOpen
                state.halfOpenProbes = 0
                slotStates[slot] = state
                DebugLogger.logBackground("ProxyCircuitBreaker: Slot \(slot) → HALF-OPEN (cooldown expired)", category: .network, level: .info)
                return true
            }
            return false
        case .halfOpen:
            if state.halfOpenProbes < halfOpenMaxProbes {
                return true
            }
            return false
        }
    }

    func recordFailure(slot: Int, reason: String) {
        lock.lock()
        defer { lock.unlock() }

        var state = slotStates[slot] ?? CircuitState()

        state.failureCount += 1

        if state.status == .halfOpen {
            state.consecutiveTrips += 1
            state.status = .open
            state.openedAt = Date()
            state.halfOpenProbes = 0
            state.effectiveCooldown = computeCooldown(consecutiveTrips: state.consecutiveTrips)
            DebugLogger.logBackground("ProxyCircuitBreaker: Slot \(slot) HALF-OPEN → OPEN (probe failed: \(reason)) cooldown=\(Int(state.effectiveCooldown))s", category: .network, level: .warning)
        } else if state.failureCount >= failureThreshold {
            state.consecutiveTrips += 1
            state.status = .open
            state.openedAt = Date()
            state.effectiveCooldown = computeCooldown(consecutiveTrips: state.consecutiveTrips)
            DebugLogger.logBackground("ProxyCircuitBreaker: Slot \(slot) TRIPPED OPEN — \(state.failureCount) failures (\(reason)), cooldown=\(Int(state.effectiveCooldown))s", category: .network, level: .critical)
        }

        slotStates[slot] = state
    }

    func recordSuccess(slot: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard var state = slotStates[slot] else { return }

        if state.status == .halfOpen {
            state.halfOpenProbes += 1
            if state.halfOpenProbes >= halfOpenMaxProbes {
                state.status = .closed
                state.failureCount = 0
                state.openedAt = nil
                state.halfOpenProbes = 0
                state.consecutiveTrips = 0
                state.effectiveCooldown = baseCooldownSeconds
                DebugLogger.logBackground("ProxyCircuitBreaker: Slot \(slot) HALF-OPEN → CLOSED (probes succeeded)", category: .network, level: .success)
            }
        } else {
            state.failureCount = max(0, state.failureCount - 1)
        }

        slotStates[slot] = state
    }

    func resetCircuit(slot: Int) {
        lock.lock()
        defer { lock.unlock() }
        slotStates.removeValue(forKey: slot)
        DebugLogger.logBackground("ProxyCircuitBreaker: Slot \(slot) manually RESET", category: .network, level: .info)
    }

    func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        slotStates.removeAll()
        DebugLogger.logBackground("ProxyCircuitBreaker: all slots RESET", category: .network, level: .info)
    }

    private func computeCooldown(consecutiveTrips: Int) -> TimeInterval {
        let escalationMultiplier = min(4.0, pow(1.5, Double(max(0, consecutiveTrips - 1))))
        let cooldown = baseCooldownSeconds * escalationMultiplier
        let maxCooldown: TimeInterval = 600
        return min(maxCooldown, cooldown)
    }
}
