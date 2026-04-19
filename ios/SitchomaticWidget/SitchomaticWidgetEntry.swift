import Foundation
import WidgetKit

nonisolated struct SitchomaticWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let headline: String
    let subheadline: String
    let detail: String
    let symbolName: String
    let accent: SitchomaticWidgetAccent
}
