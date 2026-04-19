import SwiftUI

struct SettingsConsoleView: View {
    @State private var logger = DebugLogger.shared

    var body: some View {
        DebugLogView()
            .navigationTitle("Console")
    }
}
