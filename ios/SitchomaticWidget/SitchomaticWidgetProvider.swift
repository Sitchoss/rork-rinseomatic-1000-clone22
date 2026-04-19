import Foundation
import WidgetKit

nonisolated struct SitchomaticWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SitchomaticWidgetEntry {
        sampleEntry(for: .now, index: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SitchomaticWidgetEntry) -> Void) {
        completion(sampleEntry(for: .now, index: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SitchomaticWidgetEntry>) -> Void) {
        let currentDate: Date = .now
        let entries: [SitchomaticWidgetEntry] = (0..<4).map { index in
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 90, to: currentDate) ?? currentDate
            return sampleEntry(for: entryDate, index: index)
        }
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 360, to: currentDate) ?? currentDate.addingTimeInterval(21600)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    private func sampleEntry(for date: Date, index: Int) -> SitchomaticWidgetEntry {
        switch index % 4 {
        case 0:
            SitchomaticWidgetEntry(
                date: date,
                headline: "Unified Sessions",
                subheadline: "Paired testing ready",
                detail: "JoePoint + Ignition Lite",
                symbolName: "rectangle.split.2x1.fill",
                accent: .green
            )
        case 1:
            SitchomaticWidgetEntry(
                date: date,
                headline: "Card Testing",
                subheadline: "PPSR, BPOINT & WA REGO",
                detail: "Focused card checks",
                symbolName: "creditcard.fill",
                accent: .blue
            )
        case 2:
            SitchomaticWidgetEntry(
                date: date,
                headline: "Tools & Testing",
                subheadline: "Diagnostics and validation",
                detail: "Super Test · Fingerprint · Nord",
                symbolName: "wrench.and.screwdriver.fill",
                accent: .orange
            )
        default:
            SitchomaticWidgetEntry(
                date: date,
                headline: "Credential Hub",
                subheadline: "Saved and working access",
                detail: "Dashboard · Sessions · Working",
                symbolName: "person.crop.rectangle.stack.fill",
                accent: .teal
            )
        }
    }
}
