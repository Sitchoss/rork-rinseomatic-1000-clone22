import SwiftUI

struct SettingsHubSheet: View {
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            SettingsHubRootView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onDone)
                    }
                }
        }
    }
}
