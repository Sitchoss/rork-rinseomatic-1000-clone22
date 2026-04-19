import Foundation

/// Normalises Joe Fortune and Ignition URLs so they always use the `https://www.<domain>` form.
/// Any other domain is returned unchanged.
nonisolated enum URLNormalizer {

    private static let joeBaseDomains: Set<String> = [
        "joefortune.eu",
        "joefortune.club",
        "joefortune.lv",
        "joefortune.ooo",
        "joefortune.net",
        "joefortune.com",
        "joefortune.win",
        "joefortunepokies.eu",
        "joefortunepokies.net",
        "joefortunepokies.win",
        "joefortunepokies.com",
        "joefortuneonlinepokies.eu",
        "joefortuneonlinepokies.net",
    ]

    private static let ignitionBaseDomains: Set<String> = [
        "ignitioncasino.eu",
        "ignitioncasino.lat",
        "ignitioncasino.cool",
        "ignitioncasino.fun",
        "ignitioncasino.ooo",
        "ignitioncasino.lv",
        "ignitioncasino.buzz",
        "ignitioncasino.com",
        "ignitionpoker.eu",
        "ignitionpoker.com",
    ]

    /// Heuristic: any host whose base domain (last two labels) starts with "joefortune" or "ignition".
    private static func isManagedHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        let stripped = lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower
        if joeBaseDomains.contains(stripped) || ignitionBaseDomains.contains(stripped) {
            return true
        }
        let labels = stripped.split(separator: ".")
        guard labels.count >= 2 else { return false }
        let sld = labels[labels.count - 2].lowercased()
        return sld.hasPrefix("joefortune") || sld.hasPrefix("ignitioncasino") || sld.hasPrefix("ignitionpoker")
    }

    /// Reduces a host to its base domain (last 2 labels) and strips any leading subdomain.
    private static func baseDomain(of host: String) -> String {
        let lower = host.lowercased()
        let labels = lower.split(separator: ".")
        guard labels.count >= 2 else { return lower }
        return labels.suffix(2).joined(separator: ".")
    }

    /// Normalise a URL string. For Joe/Ignition hosts, force `https://www.<baseDomain><path?query#fragment>`.
    /// For anything else, return the input unchanged (apart from a leading scheme if obviously missing).
    static func normalize(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        var working = trimmed
        if !working.lowercased().hasPrefix("http://") && !working.lowercased().hasPrefix("https://") {
            working = "https://" + working
        }

        guard var comps = URLComponents(string: working), let host = comps.host, !host.isEmpty else {
            return working
        }

        guard isManagedHost(host) else { return working }

        let base = baseDomain(of: host)
        comps.scheme = "https"
        comps.host = "www." + base
        return comps.string ?? working
    }

    /// Convenience: normalise in place on a mutable array.
    static func normalizeAll(_ urls: [String]) -> [String] {
        urls.map(normalize)
    }
}
