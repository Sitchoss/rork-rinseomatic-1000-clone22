import SwiftUI

struct WireProxyHealthDashboardView: View {
    private let bridge = WireProxyBridge.shared

    private var slots: [WireProxyTunnelSlot] {
        bridge.tunnelSlots
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WireGuard Tunnel Health")
                .font(.title3.bold())

            if slots.isEmpty {
                Text("No active tunnel slots.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(slots, id: \.index) { slot in
                        TunnelGaugeCard(slot: slot, handshakeLatencyMs: bridge.stats.handshakeLatencyMs)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct TunnelGaugeCard: View {
    let slot: WireProxyTunnelSlot
    let handshakeLatencyMs: Int

    private var breakerStatus: ProxyCircuitBreakerService.BreakerStatus {
        ProxyCircuitBreakerService.shared.isAllowed(slot: slot.index) ? .closed : .open
    }

    private var statusColor: Color {
        if !slot.isEstablished { return .secondary }
        if breakerStatus == .open { return .red }
        if breakerStatus == .halfOpen { return .orange }
        return .green
    }

    private var statusText: String {
        if !slot.isEstablished { return "Disconnected" }
        if breakerStatus == .open { return "Ejected" }
        if breakerStatus == .halfOpen { return "Probation" }
        return "Healthy"
    }

    private var latencyValue: Double {
        guard slot.isEstablished, handshakeLatencyMs > 0 else { return 0 }
        return Double(handshakeLatencyMs)
    }

    private var latencyLabel: String {
        guard slot.isEstablished, handshakeLatencyMs > 0 else { return "—" }
        return "\(handshakeLatencyMs)ms"
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Text("Slot \(slot.index)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            Text(slot.serverName)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Gauge(value: latencyValue, in: 0...300) {
                Text("Latency")
            } currentValueLabel: {
                Text(latencyLabel)
                    .font(.caption)
                    .foregroundStyle(breakerStatus == .open ? .red : .primary)
            }
            .gaugeStyle(.linearCapacity)
            .tint(Gradient(colors: [.green, .yellow, .red]))
            .disabled(!slot.isEstablished || breakerStatus == .open || handshakeLatencyMs <= 0)

            Text(statusText)
                .font(.caption2.bold())
                .foregroundStyle(statusColor)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.15))
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor.opacity(0.5), lineWidth: 1)
        }
    }
}
