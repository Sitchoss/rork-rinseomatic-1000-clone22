import Foundation
import SwiftUI
import Observation

nonisolated enum FlowScriptMode: String, CaseIterable, Sendable, Identifiable {
    case joe
    case ignition
    case bpoint
    case ppsr
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .joe: return "Joe Script"
        case .ignition: return "Ignition Script"
        case .bpoint: return "BPoint Script"
        case .ppsr: return "PPSR Script"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .joe: return "flame.fill"
        case .ignition: return "engine.combustion.fill"
        case .bpoint: return "creditcard.and.123"
        case .ppsr: return "magnifyingglass.circle.fill"
        }
    }
}

@Observable
class FlowScriptAssignmentService {
    static let shared = FlowScriptAssignmentService()
    
    private let storageKey = "flowScriptAssignments_v1"
    
    private(set) var assignments: [String: String] = [:] // mode rawValue -> flow ID
    
    private init() {
        self.assignments = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
    
    func assign(flowID: String, to mode: FlowScriptMode) {
        assignments[mode.rawValue] = flowID
        save()
    }
    
    func unassign(_ mode: FlowScriptMode) {
        assignments.removeValue(forKey: mode.rawValue)
        save()
    }
    
    func assignedFlowID(for mode: FlowScriptMode) -> String? {
        assignments[mode.rawValue]
    }
    
    func assignedFlow(for mode: FlowScriptMode, in flows: [RecordedFlow]) -> RecordedFlow? {
        guard let flowID = assignedFlowID(for: mode) else { return nil }
        return flows.first(where: { $0.id == flowID })
    }
    
    func assignedMode(for flowID: String) -> FlowScriptMode? {
        for (modeRaw, assignedID) in assignments {
            if assignedID == flowID {
                return FlowScriptMode(rawValue: modeRaw)
            }
        }
        return nil
    }
    
    func assignedModes(for flowID: String) -> [FlowScriptMode] {
        var modes: [FlowScriptMode] = []
        for (modeRaw, assignedID) in assignments {
            if assignedID == flowID {
                if let mode = FlowScriptMode(rawValue: modeRaw) {
                    modes.append(mode)
                }
            }
        }
        return modes
    }
    
    private func save() {
        UserDefaults.standard.set(assignments, forKey: storageKey)
    }
}
