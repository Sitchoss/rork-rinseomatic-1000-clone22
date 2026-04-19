import SwiftUI
import Combine

nonisolated struct AIInsight: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let message: String
    let severity: Severity
    let category: String
    
    enum Severity: String, Sendable {
        case info
        case warning
        case critical
        case success
    }
}

@MainActor
class AITickerService: ObservableObject {
    static let shared = AITickerService()
    
    @Published var activeInsights: [AIInsight] = []
    
    func publish(message: String, severity: AIInsight.Severity, category: String) {
        let insight = AIInsight(id: UUID(), timestamp: Date(), message: message, severity: severity, category: category)
        withAnimation(.spring()) {
            activeInsights.insert(insight, at: 0)
            if activeInsights.count > 5 {
                activeInsights.removeLast()
            }
        }
        
        // Auto-dismiss after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            // Must run on main thread
            guard let self = self else { return }
            withAnimation(.easeInOut) {
                self.activeInsights.removeAll { $0.id == insight.id }
            }
        }
    }
    
    func publishInfo(_ message: String, category: String = "Engine") { publish(message: message, severity: .info, category: category) }
    func publishWarning(_ message: String, category: String = "Challenge") { publish(message: message, severity: .warning, category: category) }
    func publishCritical(_ message: String, category: String = "Security") { publish(message: message, severity: .critical, category: category) }
    func publishSuccess(_ message: String, category: String = "Completion") { publish(message: message, severity: .success, category: category) }
}

struct AITickerBannerView: View {
    @StateObject private var service = AITickerService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(service.activeInsights) { insight in
                InsightBannerCell(insight: insight)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .clipped()
    }
}

struct InsightBannerCell: View {
    let insight: AIInsight
    
    var color: Color {
        switch insight.severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        case .success: return .green
        }
    }
    
    var icon: String {
        switch insight.severity {
        case .info: return "brain.head.profile"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "shield.lefthalf.filled"
        case .success: return "checkmark.seal.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("AI \(insight.category.uppercased())")
                        .font(.caption2.bold())
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text("\(insight.timestamp, formatter: timeFormatter)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(insight.message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }
}
