import Foundation
import WebKit

@MainActor
class PPSRStealthService {
    static let shared = PPSRStealthService()

    private var profileIndex: Int = 0

    struct SessionProfile {
        let userAgent: String
        let viewport: (width: Int, height: Int)
        let language: String
        let platform: String
        let cores: Int
        let memory: Int
        let tzOffset: Int
        let tzName: String
        let seed: UInt32
        let colorDepth: Int
        let pixelRatio: Double
        let maxTouchPoints: Int
        let isMobile: Bool
        let webglVendor: String
        let webglRenderer: String
        let connectionDownlink: Double
        let connectionRtt: Int
        var ja3Fingerprint: String? = nil
        var http2Settings: String? = nil
    }

    private let trustedProfiles: [SessionProfile] = [
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (402, 874), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: -600, tzName: "Australia/Brisbane",
            seed: 2847193650, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 18.0, connectionRtt: 42
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: -600, tzName: "Australia/Sydney",
            seed: 1592038476, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 16.0, connectionRtt: 46
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (430, 932), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: -480, tzName: "Australia/Perth",
            seed: 3719204856, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 21.0, connectionRtt: 38
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (440, 956), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: -600, tzName: "Australia/Melbourne",
            seed: 4028371956, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 24.0, connectionRtt: 34
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: -600, tzName: "Australia/Hobart",
            seed: 3184029367, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 14.5, connectionRtt: 50
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: -570, tzName: "Australia/Adelaide",
            seed: 3293047185, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 12.0, connectionRtt: 58
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: -570, tzName: "Australia/Darwin",
            seed: 3381920465, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 11.0, connectionRtt: 62
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.7 Mobile/15E148 Safari/604.1",
            viewport: (390, 844), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: -600, tzName: "Australia/Brisbane",
            seed: 2472059316, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 9.5, connectionRtt: 68
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.7 Mobile/15E148 Safari/604.1",
            viewport: (390, 844), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: -600, tzName: "Australia/Sydney",
            seed: 2561038274, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 10.0, connectionRtt: 70
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1",
            viewport: (430, 932), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: -600, tzName: "Australia/Melbourne",
            seed: 1047293856, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 13.5, connectionRtt: 54
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
            viewport: (402, 874), language: "en-AU", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: -600, tzName: "Australia/Sydney",
            seed: 4192837561, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 22.0, connectionRtt: 36
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (402, 874), language: "en-GB", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 0, tzName: "Europe/London",
            seed: 2738491056, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 16.5, connectionRtt: 44
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (440, 956), language: "en-GB", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 0, tzName: "Europe/London",
            seed: 3850192746, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 19.0, connectionRtt: 40
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-GB", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: 0, tzName: "Europe/London",
            seed: 1629384750, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 11.5, connectionRtt: 57
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1",
            viewport: (390, 844), language: "en-GB", platform: "iPhone",
            cores: 6, memory: 6, tzOffset: 0, tzName: "Europe/London",
            seed: 3047182956, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 8.5, connectionRtt: 72
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
            viewport: (440, 956), language: "en-GB", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 0, tzName: "Europe/London",
            seed: 2194837065, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 23.0, connectionRtt: 35
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-US", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 300, tzName: "America/New_York",
            seed: 4018293756, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 15.0, connectionRtt: 48
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1",
            viewport: (430, 932), language: "en-US", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 360, tzName: "America/Chicago",
            seed: 1847293065, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 17.5, connectionRtt: 43
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Mobile/15E148 Safari/604.1",
            viewport: (402, 874), language: "en-US", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 480, tzName: "America/Los_Angeles",
            seed: 2958174036, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 18.5, connectionRtt: 41
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            viewport: (440, 956), language: "en-US", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 300, tzName: "America/New_York",
            seed: 3619204857, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 20.0, connectionRtt: 39
        ),
        SessionProfile(
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
            viewport: (393, 852), language: "en-US", platform: "iPhone",
            cores: 6, memory: 8, tzOffset: 300, tzName: "America/New_York",
            seed: 4281937560, colorDepth: 32, pixelRatio: 3.0, maxTouchPoints: 5,
            isMobile: true, webglVendor: "Apple Inc.", webglRenderer: "Apple GPU",
            connectionDownlink: 21.5, connectionRtt: 37
        )
    ]

    private let aiFingerprintTuning = AIFingerprintTuningService.shared

    struct StealthOptions {
        var canvasNoise: Bool = false
        var webGLNoise: Bool = true
        var audioContextNoise: Bool = false
        var timezoneSpoof: Bool = true
        var languageSpoof: Bool = true
        var rectNoise: Bool = false
        var perfTimerNoise: Bool = false
    }

    var stealthOptions: StealthOptions = StealthOptions()

    func applySettings(_ settings: AutomationSettings) {
        stealthOptions.canvasNoise = settings.canvasNoise
        stealthOptions.webGLNoise = settings.webGLNoise
        stealthOptions.audioContextNoise = settings.audioContextNoise
        stealthOptions.timezoneSpoof = settings.timezoneSpoof
        stealthOptions.languageSpoof = settings.languageSpoof
    }

    var profileCount: Int { trustedProfiles.count }

    func nextProfileSync() -> SessionProfile {
        let profile = trustedProfiles[profileIndex % trustedProfiles.count]
        profileIndex += 1
        return profile
    }

    func nextProfile() async -> SessionProfile {
        let tracker = FingerprintSuccessTracker.shared
        if let bestIdx = await tracker.bestProfileIndex(totalProfiles: trustedProfiles.count) {
            return trustedProfiles[bestIdx]
        }
        let profile = trustedProfiles[profileIndex % trustedProfiles.count]
        profileIndex += 1
        return profile
    }

    func synthesizeProfile(for host: String) async -> SessionProfile? {
        let prompt = """
        Generate a statistically perfect iOS browser fingerprint for an average real user visiting '\(host)'.
        Return ONLY valid JSON matching this schema:
        {
          "userAgent": "String (latest iOS Safari)",
          "ja3Fingerprint": "771,4865-4866-4867-49195-49199-49196-49200-52393-52392-49171-49172-156-157-47-53,0-23-65281-10-11-35-16-5-13-18-51-45-43-27-17513-21,29-23-24,0",
          "http2Settings": "1:65536,2:0,3:1000,4:6291456,6:262144",
          "viewportWidth": 393,
          "viewportHeight": 852,
          "language": "en-AU",
          "platform": "iPhone",
          "cores": 6,
          "memory": 8,
          "tzOffset": -600,
          "tzName": "Australia/Sydney",
          "colorDepth": 32,
          "pixelRatio": 3.0,
          "maxTouchPoints": 5,
          "connectionDownlink": 15.0,
          "connectionRtt": 45
        }
        """
        
        guard let jsonString = await GeminiAIService.shared.generateContent(prompt: prompt, model: "gemini-1.5-flash-latest", jsonMode: true),
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return SessionProfile(
            userAgent: dict["userAgent"] as? String ?? trustedProfiles[0].userAgent,
            viewport: (dict["viewportWidth"] as? Int ?? 393, dict["viewportHeight"] as? Int ?? 852),
            language: dict["language"] as? String ?? "en-AU",
            platform: dict["platform"] as? String ?? "iPhone",
            cores: dict["cores"] as? Int ?? 6,
            memory: dict["memory"] as? Int ?? 8,
            tzOffset: dict["tzOffset"] as? Int ?? -600,
            tzName: dict["tzName"] as? String ?? "Australia/Sydney",
            seed: UInt32.random(in: 1000000000...4000000000),
            colorDepth: dict["colorDepth"] as? Int ?? 32,
            pixelRatio: dict["pixelRatio"] as? Double ?? 3.0,
            maxTouchPoints: dict["maxTouchPoints"] as? Int ?? 5,
            isMobile: true,
            webglVendor: "Apple Inc.",
            webglRenderer: "Apple GPU",
            connectionDownlink: dict["connectionDownlink"] as? Double ?? 15.0,
            connectionRtt: dict["connectionRtt"] as? Int ?? 45,
            ja3Fingerprint: dict["ja3Fingerprint"] as? String,
            http2Settings: dict["http2Settings"] as? String
        )
    }

    func nextProfileForHost(_ host: String) async -> (profile: SessionProfile, index: Int) {
        // Feature 6: Try Gemini AI Synthesis First!
        if let aiSynthesized = await synthesizeProfile(for: host) {
            DebugLogger.shared.log("PPSRStealth: Gemini synthesized zero-shot profile for \(host)", category: .automation, level: .success)
            return (aiSynthesized, 9999) // Dynamic index
        }
        
        if let aiIndex = aiFingerprintTuning.recommendProfileIndex(for: host, totalProfiles: trustedProfiles.count) {
            return (trustedProfiles[aiIndex], aiIndex)
        }
        let tracker = FingerprintSuccessTracker.shared
        let ranked = await tracker.rankedProfileIndices(totalProfiles: trustedProfiles.count)
        let usedRecently = Set<Int>()
        for idx in ranked {
            if !usedRecently.contains(idx) {
                let stats = await tracker.stats(for: idx)
                if stats == nil || (stats?.totalAttempts ?? 0) < 3 {
                    let fallbackIdx = profileIndex % trustedProfiles.count
                    profileIndex += 1
                    return (trustedProfiles[fallbackIdx], fallbackIdx)
                }
                return (trustedProfiles[idx], idx)
            }
        }
        let idx = profileIndex % trustedProfiles.count
        profileIndex += 1
        return (trustedProfiles[idx], idx)
    }

    func profileForSlot(_ slot: Int) -> SessionProfile {
        trustedProfiles[slot % trustedProfiles.count]
    }

    func nextUserAgent() -> String {
        let profile = trustedProfiles[profileIndex % trustedProfiles.count]
        profileIndex += 1
        return profile.userAgent
    }

    func nextViewport() -> (width: Int, height: Int) {
        let profile = trustedProfiles[profileIndex % trustedProfiles.count]
        return profile.viewport
    }

    func randomLanguage() -> String {
        trustedProfiles.randomElement()?.language ?? "en-AU"
    }

    func createStealthUserScript(profile: SessionProfile) -> WKUserScript {
        let js = buildComprehensiveStealthJS(profile: profile)
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    func fingerprintJS() -> String {
        let profile = nextProfileSync()
        return buildComprehensiveStealthJS(profile: profile)
    }

    func buildComprehensiveStealthJSPublic(profile: SessionProfile) -> String {
        buildComprehensiveStealthJS(profile: profile)
    }

    private func buildComprehensiveStealthJS(profile: SessionProfile) -> String {
        let p = profile
        let opts = stealthOptions
        return """
        (function() {
            'use strict';
            var seed = \(p.seed);
            function mulberry32(a) {
                return function() {
                    a |= 0; a = a + 0x6D2B79F5 | 0;
                    var t = Math.imul(a ^ a >>> 15, 1 | a);
                    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
                    return ((t ^ t >>> 14) >>> 0) / 4294967296;
                }
            }
            var prng = mulberry32(seed);

            function defineVal(obj, prop, val) {
                try {
                    Object.defineProperty(obj, prop, {
                        value: val,
                        configurable: true,
                        writable: false,
                        enumerable: true
                    });
                } catch(e) {
                    try { obj[prop] = val; } catch(e2) {}
                }
            }

            function defineProtoGetter(proto, prop, val) {
                try {
                    var origDesc = Object.getOwnPropertyDescriptor(proto, prop);
                    if (origDesc && origDesc.get) {
                        var fakeGet = function() { return val; };
                        Object.defineProperty(fakeGet, 'name', { value: 'get ' + prop, configurable: true });
                        Object.defineProperty(proto, prop, {
                            get: fakeGet,
                            set: origDesc.set,
                            configurable: true,
                            enumerable: origDesc.enumerable
                        });
                        return fakeGet;
                    } else {
                        defineVal(proto, prop, val);
                        return null;
                    }
                } catch(e) {
                    defineVal(proto, prop, val);
                    return null;
                }
            }

            // === NAVIGATOR SPOOFING (prototype-level getter overrides — matches real browser descriptor shape) ===
            var protoGetters = [];
            try {
                var navProto = Object.getPrototypeOf(navigator);
                var g;
                g = defineProtoGetter(navProto, 'webdriver', false); if (g) protoGetters.push(g);
                \(opts.languageSpoof ? "g = defineProtoGetter(navProto, 'language', '\(p.language)'); if (g) protoGetters.push(g);" : "")
                \(opts.languageSpoof ? "g = defineProtoGetter(navProto, 'languages', Object.freeze(['\(p.language)', 'en'])); if (g) protoGetters.push(g);" : "")
                g = defineProtoGetter(navProto, 'platform', '\(p.platform)'); if (g) protoGetters.push(g);
                g = defineProtoGetter(navProto, 'hardwareConcurrency', \(p.cores)); if (g) protoGetters.push(g);
                g = defineProtoGetter(navProto, 'deviceMemory', \(p.memory)); if (g) protoGetters.push(g);
                g = defineProtoGetter(navProto, 'maxTouchPoints', \(p.maxTouchPoints)); if (g) protoGetters.push(g);
                g = defineProtoGetter(navProto, 'vendor', 'Apple Computer, Inc.'); if (g) protoGetters.push(g);
                g = defineProtoGetter(navProto, 'productSub', '20030107'); if (g) protoGetters.push(g);
                g = defineProtoGetter(navProto, 'doNotTrack', null); if (g) protoGetters.push(g);
                try { g = defineProtoGetter(navProto, 'appVersion', navigator.userAgent.replace('Mozilla/', '')); if (g) protoGetters.push(g); } catch(e) {}
            } catch(e) {
                defineVal(navigator, 'webdriver', false);
                \(opts.languageSpoof ? "defineVal(navigator, 'language', '\(p.language)');" : "")
                \(opts.languageSpoof ? "defineVal(navigator, 'languages', Object.freeze(['\(p.language)', 'en']));" : "")
                defineVal(navigator, 'platform', '\(p.platform)');
                defineVal(navigator, 'hardwareConcurrency', \(p.cores));
                defineVal(navigator, 'deviceMemory', \(p.memory));
                defineVal(navigator, 'maxTouchPoints', \(p.maxTouchPoints));
                defineVal(navigator, 'vendor', 'Apple Computer, Inc.');
                defineVal(navigator, 'productSub', '20030107');
                defineVal(navigator, 'doNotTrack', null);
                try { defineVal(navigator, 'appVersion', navigator.userAgent.replace('Mozilla/', '')); } catch(e) {}
            }

            try { delete navigator.webdriver; } catch(e) {}

            // === CONNECTION API ===
            try {
                if (navigator.connection) {
                    defineVal(navigator.connection, 'effectiveType', '4g');
                    defineVal(navigator.connection, 'downlink', \(p.connectionDownlink));
                    defineVal(navigator.connection, 'rtt', \(p.connectionRtt));
                    defineVal(navigator.connection, 'saveData', false);
                }
            } catch(e) {}

            // === PLUGINS & MIME TYPES (Safari-like — empty arrays) ===
            try {
                defineVal(navigator, 'plugins', Object.create(PluginArray.prototype, {
                    length: { value: 0, configurable: true },
                    item: { value: function(i) { return null; }, configurable: true },
                    namedItem: { value: function(n) { return null; }, configurable: true },
                    refresh: { value: function() {}, configurable: true }
                }));
                defineVal(navigator, 'mimeTypes', Object.create(MimeTypeArray.prototype, {
                    length: { value: 0, configurable: true },
                    item: { value: function(i) { return null; }, configurable: true },
                    namedItem: { value: function(n) { return null; }, configurable: true }
                }));
            } catch(e) {}

            // === PERMISSIONS API SPOOF ===
            try {
                var origQuery = Permissions.prototype.query;
                Permissions.prototype.query = function(desc) {
                    if (desc && desc.name === 'notifications') {
                        return Promise.resolve({ state: 'prompt', onchange: null });
                    }
                    return origQuery.apply(this, arguments);
                };
            } catch(e) {}

            // === SCREEN & WINDOW ===
            try {
                defineVal(screen, 'width', \(p.viewport.width));
                defineVal(screen, 'height', \(p.viewport.height));
                defineVal(screen, 'availWidth', \(p.viewport.width));
                defineVal(screen, 'availHeight', \(p.viewport.height));
                defineVal(screen, 'colorDepth', \(p.colorDepth));
                defineVal(screen, 'pixelDepth', \(p.colorDepth));
            } catch(e) {}
            try {
                defineVal(window, 'devicePixelRatio', \(p.pixelRatio));
                defineVal(window, 'innerWidth', \(p.viewport.width));
                defineVal(window, 'innerHeight', \(p.viewport.height));
                defineVal(window, 'outerWidth', \(p.viewport.width));
                defineVal(window, 'outerHeight', \(p.viewport.height));
            } catch(e) {}

            \(opts.timezoneSpoof ? """
            // === TIMEZONE SPOOFING ===
            try {
                var origDateTZO = Date.prototype.getTimezoneOffset;
                Date.prototype.getTimezoneOffset = function() { return \(p.tzOffset); };
                var origResolvedOptions = Intl.DateTimeFormat.prototype.resolvedOptions;
                Intl.DateTimeFormat.prototype.resolvedOptions = function() {
                    var result = origResolvedOptions.call(this);
                    result.timeZone = '\(p.tzName)';
                    return result;
                };
            } catch(e) {}
            """ : "")

            \(opts.canvasNoise ? """
            // === CANVAS FINGERPRINT (IDEMPOTENT — noise applied once per canvas) ===
            try {
                var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
                var origToBlob = HTMLCanvasElement.prototype.toBlob;
                var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
                var noisedCanvases = new WeakSet();

                function addCanvasNoiseOnce(canvas) {
                    try {
                        if (noisedCanvases.has(canvas)) return;
                        noisedCanvases.add(canvas);
                        var ctx = canvas.getContext('2d');
                        if (!ctx) return;
                        var w = Math.min(canvas.width, 16);
                        var h = Math.min(canvas.height, 16);
                        if (w === 0 || h === 0) return;
                        var imageData = origGetImageData.call(ctx, 0, 0, w, h);
                        var data = imageData.data;
                        var canvasPrng = mulberry32(seed ^ (canvas.width * 31 + canvas.height));
                        for (var i = 0; i < data.length; i += 4) {
                            var noise = ((canvasPrng() * 4) | 0) - 2;
                            data[i] = Math.max(0, Math.min(255, data[i] + noise));
                            data[i+1] = Math.max(0, Math.min(255, data[i+1] + noise));
                            data[i+2] = Math.max(0, Math.min(255, data[i+2] + noise));
                        }
                        ctx.putImageData(imageData, 0, 0);
                    } catch(e) {}
                }

                HTMLCanvasElement.prototype.toDataURL = function() {
                    addCanvasNoiseOnce(this);
                    return origToDataURL.apply(this, arguments);
                };
                HTMLCanvasElement.prototype.toBlob = function() {
                    addCanvasNoiseOnce(this);
                    return origToBlob.apply(this, arguments);
                };
            } catch(e) {}
            """ : "")

            \(opts.webGLNoise ? """
            // === WEBGL SPOOFING (vendor/renderer only — no detectable noise) ===
            try {
                var gpuVendor = '\(p.webglVendor)';
                var gpuRenderer = '\(p.webglRenderer)';
                function patchWebGLContext(proto) {
                    var origGetParameter = proto.getParameter;
                    var origGetExtension = proto.getExtension;
                    proto.getParameter = function(param) {
                        if (param === 37445) return gpuVendor;
                        if (param === 37446) return gpuRenderer;
                        return origGetParameter.apply(this, arguments);
                    };
                    proto.getExtension = function(name) {
                        if (name === 'WEBGL_debug_renderer_info') {
                            return { UNMASKED_VENDOR_WEBGL: 37445, UNMASKED_RENDERER_WEBGL: 37446 };
                        }
                        return origGetExtension.apply(this, arguments);
                    };
                }
                if (typeof WebGLRenderingContext !== 'undefined') patchWebGLContext(WebGLRenderingContext.prototype);
                if (typeof WebGL2RenderingContext !== 'undefined') patchWebGLContext(WebGL2RenderingContext.prototype);
            } catch(e) {}
            """ : "")

            \(opts.audioContextNoise ? """
            // === AUDIO CONTEXT FINGERPRINT ===
            try {
                if (window.OfflineAudioContext || window.webkitOfflineAudioContext) {
                    var AudioCtx = window.OfflineAudioContext || window.webkitOfflineAudioContext;
                    var origSR = AudioCtx.prototype.startRendering;
                    var audioPrng = mulberry32(seed ^ 0xAUD10);
                    AudioCtx.prototype.startRendering = function() {
                        var origPromise = origSR.apply(this, arguments);
                        if (origPromise && origPromise.then) {
                            return origPromise.then(function(buffer) {
                                try {
                                    var channelData = buffer.getChannelData(0);
                                    for (var i = 0; i < Math.min(channelData.length, 1000); i++) {
                                        channelData[i] += (audioPrng() - 0.5) * 0.0001;
                                    }
                                } catch(e) {}
                                return buffer;
                            });
                        }
                        return origPromise;
                    };
                }
            } catch(e) {}
            """ : "")

            // === WEBRTC LEAK PREVENTION ===
            try {
                var origRTC = window.RTCPeerConnection || window.webkitRTCPeerConnection || window.mozRTCPeerConnection;
                if (origRTC) {
                    var ProxiedRTC = function(config, constraints) {
                        if (config && config.iceServers) {
                            config.iceServers = config.iceServers.map(function(s) {
                                if (s.urls) {
                                    var urls = Array.isArray(s.urls) ? s.urls : [s.urls];
                                    s.urls = urls.filter(function(u) { return u.indexOf('stun:') !== 0; });
                                }
                                return s;
                            });
                        }
                        return new origRTC(config, constraints);
                    };
                    ProxiedRTC.prototype = origRTC.prototype;
                    ProxiedRTC.generateCertificate = origRTC.generateCertificate;
                    window.RTCPeerConnection = ProxiedRTC;
                    if (window.webkitRTCPeerConnection) window.webkitRTCPeerConnection = ProxiedRTC;
                }
            } catch(e) {}

            // === BATTERY API ===
            try {
                if (navigator.getBattery) {
                    var batteryLevel = 0.85 + prng() * 0.14;
                    var fakeBattery = {
                        charging: true,
                        chargingTime: Infinity,
                        dischargingTime: Infinity,
                        level: batteryLevel,
                        addEventListener: function() {},
                        removeEventListener: function() {},
                        dispatchEvent: function() { return true; },
                        onchargingchange: null,
                        onchargingtimechange: null,
                        ondischargingtimechange: null,
                        onlevelchange: null
                    };
                    navigator.getBattery = function() { return Promise.resolve(fakeBattery); };
                }
            } catch(e) {}

            // === MEDIA DEVICES ===
            try {
                if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
                    var origEnum = navigator.mediaDevices.enumerateDevices.bind(navigator.mediaDevices);
                    navigator.mediaDevices.enumerateDevices = function() {
                        return origEnum().then(function(devices) {
                            return devices.map(function(d) {
                                return { deviceId: d.deviceId || '', groupId: d.groupId || '', kind: d.kind, label: '' };
                            });
                        });
                    };
                }
            } catch(e) {}

            // === STORAGE ESTIMATION (prevent incognito detection) ===
            try {
                if (navigator.storage && navigator.storage.estimate) {
                    navigator.storage.estimate = function() {
                        return Promise.resolve({ quota: 2147483648, usage: 0, usageDetails: {} });
                    };
                }
            } catch(e) {}

            // === PROTECT OVERRIDES FROM toString() DETECTION ===
            try {
                var nativeToString = Function.prototype.toString;
                var spoofedFns = new Set();
                function markNative(fn) { if (fn) spoofedFns.add(fn); }
                Function.prototype.toString = function() {
                    if (spoofedFns.has(this)) {
                        return 'function ' + (this.name || '') + '() { [native code] }';
                    }
                    return nativeToString.call(this);
                };
                markNative(Function.prototype.toString);
                for (var pi = 0; pi < protoGetters.length; pi++) { markNative(protoGetters[pi]); }
                markNative(Permissions.prototype.query);
                \(opts.timezoneSpoof ? "markNative(Date.prototype.getTimezoneOffset);" : "")
                \(opts.timezoneSpoof ? "try { markNative(Intl.DateTimeFormat.prototype.resolvedOptions); } catch(e) {}" : "")
                \(opts.canvasNoise ? "markNative(HTMLCanvasElement.prototype.toDataURL);" : "")
                \(opts.canvasNoise ? "markNative(HTMLCanvasElement.prototype.toBlob);" : "")
                \(opts.webGLNoise ? """
                if (typeof WebGLRenderingContext !== 'undefined') {
                    markNative(WebGLRenderingContext.prototype.getParameter);
                    markNative(WebGLRenderingContext.prototype.getExtension);
                }
                if (typeof WebGL2RenderingContext !== 'undefined') {
                    markNative(WebGL2RenderingContext.prototype.getParameter);
                    markNative(WebGL2RenderingContext.prototype.getExtension);
                }
                """ : "")
                \(opts.audioContextNoise ? """
                try {
                    var AC2 = window.OfflineAudioContext || window.webkitOfflineAudioContext;
                    if (AC2) markNative(AC2.prototype.startRendering);
                } catch(e) {}
                """ : "")
                if (window.RTCPeerConnection) markNative(window.RTCPeerConnection);
                if (navigator.getBattery) markNative(navigator.getBattery);
                if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) markNative(navigator.mediaDevices.enumerateDevices);
                if (navigator.storage && navigator.storage.estimate) markNative(navigator.storage.estimate);
            } catch(e) {}

            // === PREVENT AUTOMATION DETECTION FLAGS ===
            try {
                var autoProps = ['__nightmare','_phantom','callPhantom','__selenium_evaluate',
                    '__selenium_unwrapped','__webdriver_evaluate','__driver_evaluate',
                    '__webdriver_unwrapped','__driver_unwrapped','__lastWatirAlert',
                    '__lastWatirConfirm','__lastWatirPrompt','_Selenium_IDE_Recorder',
                    '_WEBDRIVER_ELEM_CACHE','ChromeDriverw'];
                for (var k = 0; k < autoProps.length; k++) { try { delete window[autoProps[k]]; } catch(e) {} }
                try { delete document.__webdriver_script_fn; } catch(e) {}
                try { delete document.$chrome_asyncScriptInfo; } catch(e) {}
                try { delete document.$cdc_asdjflasutopfhvcZLmcfl_; } catch(e) {}
            } catch(e) {}

            // === IFRAME CONTENTWINDOW PROTECTION ===
            try {
                var origContentWindow = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'contentWindow');
                if (origContentWindow && origContentWindow.get) {
                    var patchedCWGet = function() {
                        var w = origContentWindow.get.call(this);
                        if (w) {
                            try {
                                var np = Object.getPrototypeOf(w.navigator);
                                defineProtoGetter(np, 'webdriver', false);
                            } catch(e) {
                                try { defineVal(w.navigator, 'webdriver', false); } catch(e2) {}
                            }
                        }
                        return w;
                    };
                    Object.defineProperty(HTMLIFrameElement.prototype, 'contentWindow', {
                        get: patchedCWGet,
                        configurable: true
                    });
                    markNative(patchedCWGet);
                }
            } catch(e) {}

            // === OBJECT.getOwnPropertyDescriptor SHIELD ===
            try {
                var origGOPD = Object.getOwnPropertyDescriptor;
                var shieldedProps = new Set(['webdriver','language','languages','platform','hardwareConcurrency','deviceMemory','maxTouchPoints','vendor','productSub','doNotTrack','appVersion']);
                Object.getOwnPropertyDescriptor = function(obj, prop) {
                    if (obj === navigator && shieldedProps.has(prop)) {
                        return undefined;
                    }
                    return origGOPD.call(this, obj, prop);
                };
                markNative(Object.getOwnPropertyDescriptor);
            } catch(e) {}

        })();
        """
    }
}
