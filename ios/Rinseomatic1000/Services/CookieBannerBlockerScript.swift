import Foundation
import WebKit

enum CookieBannerBlockerScript {
    private static let defaultsKey = "rork.cookieBannerBlocker.enabled"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: defaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static let js: String = """
    (function() {
        'use strict';
        var SELECTORS = [
            '.coi-banner__accept',
            '.coi-banner__wrapper',
            '#coi-banner-wrapper',
            '.coi-banner__text',
            '.coi-banner__lastpage',
            '.coi-banner__close',
            '.coi-banner__link',
            '.coi-button-group',
            '.coi-banner__page',
            '.coi-banner__page-footer',
            '.coi-banner__cookiedeclaration',
            '.cookiedeclaration_wrapper',
            '[class*="cookiedeclaration" i]',
            '#coiPage-1',
            '#coiPage-2',
            '#coiPage-3',
            '[id^="coiPage-"]',
            '.coi_expanded',
            '[aria-label="Cookie Information Banner"]',
            '[role="dialog"][aria-label*="Cookie" i]',
            '[id^="coi-"]',
            '[id^="coiPage"]',
            '[id*="coiBanner" i]',
            '[class*="coi-banner" i]',
            '[class*="coi_banner" i]',
            '[class*="cookieinformation" i]',
            '[onclick*="CookieInformation"]',
            '[onclick*="TogglePage"]'
        ];

        function injectCSS() {
            try {
                if (document.getElementById('__rork_coi_kill_css__')) return;
                var style = document.createElement('style');
                style.id = '__rork_coi_kill_css__';
                var rules = SELECTORS.map(function(s){return s;}).join(',\\n');
                style.textContent = rules + ' { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; width: 0 !important; height: 0 !important; max-width: 0 !important; max-height: 0 !important; position: absolute !important; left: -99999px !important; top: -99999px !important; z-index: -99999 !important; } html, body { overflow: auto !important; }';
                (document.head || document.documentElement).appendChild(style);
            } catch(e) {}
        }

        function nuke(root) {
            try {
                var scope = root && root.querySelectorAll ? root : document;
                for (var i = 0; i < SELECTORS.length; i++) {
                    var nodes;
                    try { nodes = scope.querySelectorAll(SELECTORS[i]); } catch(e) { continue; }
                    for (var j = 0; j < nodes.length; j++) {
                        var n = nodes[j];
                        try { if (n && n.parentNode) n.parentNode.removeChild(n); } catch(e) {}
                    }
                }
                try {
                    document.documentElement.classList.remove('coi_expanded');
                    if (document.body) document.body.classList.remove('coi_expanded');
                } catch(e) {}
            } catch(e) {}
        }

        function stubCookieInformation() {
            try {
                var noop = function(){};
                var stub = {
                    submitAllCategories: noop,
                    submitConsent: noop,
                    submitCustomConsent: noop,
                    changeCategoryConsent: noop,
                    renew: noop,
                    showSettings: noop,
                    hideBanner: noop,
                    getConsentGivenFor: function(){ return true; },
                    loadCategory: noop
                };
                try { Object.defineProperty(window, 'CookieInformation', { value: stub, writable: false, configurable: false }); } catch(e) { window.CookieInformation = stub; }
                try { Object.defineProperty(window, 'TogglePage', { value: noop, writable: false, configurable: false }); } catch(e) { window.TogglePage = noop; }
                try { window.CookieConsent = stub; } catch(e) {}
            } catch(e) {}
        }

        injectCSS();
        stubCookieInformation();
        nuke(document);

        try {
            var mo = new MutationObserver(function(muts) {
                injectCSS();
                for (var i = 0; i < muts.length; i++) {
                    var m = muts[i];
                    if (m.addedNodes && m.addedNodes.length) {
                        for (var k = 0; k < m.addedNodes.length; k++) {
                            var n = m.addedNodes[k];
                            if (n && n.nodeType === 1) {
                                nuke(n);
                            }
                        }
                    }
                }
                nuke(document);
            });
            var start = function() {
                try {
                    mo.observe(document.documentElement || document, { childList: true, subtree: true, attributes: true, attributeFilter: ['class','id','aria-label','role'] });
                } catch(e) {}
            };
            start();
            document.addEventListener('DOMContentLoaded', function(){ injectCSS(); nuke(document); start(); }, true);
            document.addEventListener('readystatechange', function(){ injectCSS(); nuke(document); }, true);
            window.addEventListener('load', function(){ injectCSS(); nuke(document); }, true);
        } catch(e) {}

        try {
            setInterval(function(){ injectCSS(); nuke(document); }, 500);
        } catch(e) {}
    })();
    """

    static var userScript: WKUserScript {
        WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    static func addIfEnabled(to controller: WKUserContentController) {
        guard isEnabled else { return }
        controller.addUserScript(userScript)
    }
}
