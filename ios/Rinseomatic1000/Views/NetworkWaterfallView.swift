import SwiftUI
import Charts

struct NetworkWaterfallView: View {
    let replay: EnrichedSessionReplay
    
    @State private var hoveredStep: EnrichedReplayStep?
    
    // Sort steps and strip anything that lacks duration or isn't a "network" event for the chart
    private var timelineSteps: [WaterfallStep] {
        var result: [WaterfallStep] = []
        var cumulatedStart = 0
        
        let validSteps = replay.steps.filter { $0.durationMs != nil || $0.action.contains("load") || $0.action.contains("evaluate") }
        
        for step in validSteps {
            let dur = step.durationMs ?? 120
            let wStep = WaterfallStep(id: step.id, action: step.action, phase: step.phase ?? "script", startMs: cumulatedStart, durationMs: dur, level: step.level)
            result.append(wStep)
            cumulatedStart += dur + 16
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network & Execution Timeline")
                .font(.headline)
            
            Chart {
                ForEach(timelineSteps) { step in
                    BarMark(
                        xStart: .value("Start Time", step.startMs),
                        xEnd: .value("End Time", step.startMs + step.durationMs),
                        y: .value("Action", step.action)
                    )
                    .foregroundStyle(by: .value("Phase", step.phase))
                    .clipShape(.rect(cornerRadius: 4))
                    .annotation(position: .trailing) {
                        Text("\(step.durationMs)ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartForegroundStyleScale([
                "page_load": Color.blue,
                "evaluate": Color.orange,
                "fill_credentials": Color.purple,
                "submit": Color.red,
                "script": Color.green
            ])
            .frame(height: max(200, CGFloat(timelineSteps.count * 35)))
            .padding()
            .background(Color(.systemGray6).opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding()
    }
}

struct WaterfallStep: Identifiable {
    let id: String
    let action: String
    let phase: String
    let startMs: Int
    let durationMs: Int
    let level: String
}
