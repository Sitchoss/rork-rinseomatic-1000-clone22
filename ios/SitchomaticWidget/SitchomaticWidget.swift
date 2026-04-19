import WidgetKit
import SwiftUI

struct SitchomaticWidget: Widget {
    let kind: String = "SitchomaticWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SitchomaticWidgetProvider()) { entry in
            SitchomaticWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Command Center")
        .description("Quick glance access to sessions, tools, and live run status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
