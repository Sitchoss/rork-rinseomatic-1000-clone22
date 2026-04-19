import Foundation

nonisolated struct XLSXParserService: Sendable {
    static func parseToCSV(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return nil }
        if content.contains(",") || content.contains("\t") {
            return content
        }
        return nil
    }
}
