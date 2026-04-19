// Rinseomatic1000ApexActor.swift
// rork-Rinseomatic1000-APEX
//
// Hardware-locked global actor for A19 Pro Max silicon.
// Isolates all automation workloads from the Main Thread,
// ensuring the UI remains at a locked 120 Hz ProMotion refresh.

import Foundation

/// Global actor for all JoePoint & Ignition Lite automation work.
/// Keeps heavy WebKit injection, credential iteration, and network
/// I/O off the cooperative main-thread pool.
@globalActor
public actor Rinseomatic1000ApexActor {
    public static let shared = Rinseomatic1000ApexActor()
}

/// Convenience typealias used throughout the codebase.
public typealias JoePointActor = Rinseomatic1000ApexActor
