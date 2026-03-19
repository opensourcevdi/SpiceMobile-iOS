//
//  WebView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import WebKit
import UIKit

extension Notification.Name { static let WebViewSendBackspace = Notification.Name("WebViewSendBackspace") }


// MARK: - WebView Wrapper
struct WebView: UIViewRepresentable {
    
    let urlString: String
    @Binding var isLoading: Bool
    @Binding var shouldForceLandscape: Bool
    @Binding var currentURL: URL?
    @Binding var requestedURL: URL?
    @Binding var typingBuffer: String
    var pageZoom: CGFloat = 0.62
    var cursorSpeed: Double = 2.0
    
    var pageReadyPredicateJS: String? = nil
    
    var pageReadyTimeout: TimeInterval = 10.0
    var pageReadyInterval: TimeInterval = 0.3

    // Convenience initializer to keep existing call sites working without passing requestKeyboardFocus
    init(urlString: String,
         isLoading: Binding<Bool>,
         shouldForceLandscape: Binding<Bool>,
         currentURL: Binding<URL?>,
         requestedURL: Binding<URL?>,
         typingBuffer: Binding<String>,
         pageZoom: CGFloat = 0.62,
         cursorSpeed: Double = 2.0,
         pageReadyPredicateJS: String? = nil,
         pageReadyTimeout: TimeInterval = 10.0,
         pageReadyInterval: TimeInterval = 0.3) {
        self.urlString = urlString
        self._isLoading = isLoading
        self._shouldForceLandscape = shouldForceLandscape
        self._currentURL = currentURL
        self._requestedURL = requestedURL
        self._typingBuffer = typingBuffer
        self.pageZoom = pageZoom
        self.cursorSpeed = cursorSpeed
        self.pageReadyPredicateJS = pageReadyPredicateJS
        self.pageReadyTimeout = pageReadyTimeout
        self.pageReadyInterval = pageReadyInterval
        
    }

    // Designated initializer including requestKeyboardFocus binding
    init(urlString: String,
         isLoading: Binding<Bool>,
         shouldForceLandscape: Binding<Bool>,
         currentURL: Binding<URL?>,
         requestedURL: Binding<URL?>,
         requestKeyboardFocus: Binding<Bool>,
         typingBuffer: Binding<String>,
         pageZoom: CGFloat = 0.62,
         cursorSpeed: Double = 2.0,
         pageReadyPredicateJS: String? = nil,
         pageReadyTimeout: TimeInterval = 10.0,
         pageReadyInterval: TimeInterval = 0.3) {
        self.urlString = urlString
        self._isLoading = isLoading
        self._shouldForceLandscape = shouldForceLandscape
        self._currentURL = currentURL
        self._requestedURL = requestedURL
        self._typingBuffer = typingBuffer
        self.pageZoom = pageZoom
        self.cursorSpeed = cursorSpeed
        self.pageReadyPredicateJS = pageReadyPredicateJS
        self.pageReadyTimeout = pageReadyTimeout
        self.pageReadyInterval = pageReadyInterval
    }

    // convert Image (base 64 encoded)
    func base64ForSFSymbol(named name: String, pointSize: CGFloat = 10, weight: UIImage.SymbolWeight = .regular) -> String? {

        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        if let image = UIImage(systemName: name, withConfiguration: config),
           let png = image.pngData() {
            return png.base64EncodedString()
        }
        return nil
    }

    

    

    private func makeConfiguredWebView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "haptics")

        
        // load disableSelectionScript.js and convert to string
        contentController.addUserScript(JSLoader(fileName: "disableSelectionScript"))
        
        // load touchToMouseScript.js and convert to string
        // load touchToMouseScript.js nur wenn Touch-Mode aktiv ist
        let isTouchModeEnabled = UserDefaults.standard.object(forKey: "isTouchMode") as? Bool ?? true
        if isTouchModeEnabled {
            contentController.addUserScript(JSLoader(fileName: "touchToMouseScript"))
        }
        
       // let base64 = base64ForSFSymbol(named: "cursorarrow") ?? ""
        
  
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = makeConfiguredWebView(context: context)
        
        context.coordinator.webView = webView

        // Optional: Scroll und Zoom konfigurieren
            webView.scrollView.bounces = false
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.keyboardDismissMode = .onDrag
            webView.allowsBackForwardNavigationGestures = true
            webView.navigationDelegate = context.coordinator
            DispatchQueue.main.async {
                self.currentURL = nil
            }
            webView.scrollView.bounces = false
            // webView.scrollView.isScrollEnabled = false
            webView.scrollView.alwaysBounceVertical = false
            webView.scrollView.alwaysBounceHorizontal = false
            webView.allowsBackForwardNavigationGestures = false

            webView.uiDelegate = context.coordinator
        
        webView.gestureRecognizers?.forEach { recognizer in
            if let longPress = recognizer as? UILongPressGestureRecognizer {
                longPress.isEnabled = false
            }
        }
        
        // Remove native drag interactions if present
        if #available(iOS 11.0, *) {
            webView.interactions
                .compactMap { $0 as? UIDragInteraction }
                .forEach { webView.removeInteraction($0) }
        }

        // Lade die URL
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
            DispatchQueue.main.async {
                self.isLoading = true
                self.currentURL = url
            }
        }
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Event-based propagation of typingBuffer changes
        let oldValue = context.coordinator.lastLoggedTypingBuffer
        let newValue = self.typingBuffer
        if oldValue != newValue {
            context.coordinator.processTypingBufferChange(old: oldValue, new: newValue)
            context.coordinator.lastLoggedTypingBuffer = newValue
        }
        
        

        // Proceed with navigation request if any
        guard let url = requestedURL else { return }
        
        

        let spicePrefix = "https://demo.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"
        let targetIsSpice = url.absoluteString.hasPrefix(spicePrefix)

        if targetIsSpice {
            // Preserve SPICE settings before loading a SPICE target
            webView.pageZoom = self.pageZoom
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.alwaysBounceVertical = false
            webView.scrollView.panGestureRecognizer.isEnabled = false
            webView.scrollView.alwaysBounceHorizontal = false
        } else {
            // Proactively reset to normal browsing behavior BEFORE loading non-SPICE targets
            webView.pageZoom = 1.0
            webView.scrollView.isScrollEnabled = true
            webView.scrollView.alwaysBounceVertical = true
            webView.scrollView.alwaysBounceHorizontal = true
         
        }

        let request = URLRequest(url: url)
        webView.load(request)


        // Reset the request to avoid repeated loads
        DispatchQueue.main.async { self.requestedURL = nil }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebView
        
        weak var webView: WKWebView?
        
        var lastLoggedTypingBuffer: String = ""

        init(parent: WebView) {
            self.parent = parent
            self.lastLoggedTypingBuffer = parent.typingBuffer
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(handleBackspaceNotification), name: .WebViewSendBackspace, object: nil)
        }
        
        @objc private func handleBackspaceNotification() {
            sendBackspace()
        }
        
        func sendBackspace() {
            guard let webView = self.webView else { return }
            let js = """
            (function(){
              function findSpiceTarget(){
                var canvas = document.querySelector('canvas');
                if (canvas) return canvas;
                var el = document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas');
                return el || document.body;
              }
              function focusTarget(el){
                try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex','0'); } catch(_) {}
                try { el.focus(); } catch(_) {}
              }
              function dispatchKey(el, type, key, code, keyCode){
                var evt = new KeyboardEvent(type, { bubbles: true, cancelable: true, key: key, code: code, composed: true });
                try { Object.defineProperty(evt, 'keyCode', { get: function(){ return keyCode; } }); } catch(_){ }
                try { Object.defineProperty(evt, 'which', { get: function(){ return keyCode; } }); } catch(_){ }
                try { Object.defineProperty(evt, 'charCode', { get: function(){ return keyCode; } }); } catch(_){ }
                el.dispatchEvent(evt);
              }
              function sendViaSpiceAPIKey(key){
                try { if (window.SpiceKeyboard && typeof window.SpiceKeyboard.sendKey === 'function') { window.SpiceKeyboard.sendKey(key); return true; } } catch(_) {}
                try { if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyPress === 'function') { window.rfb._keyboard.keyPress(key); return true; } } catch(_) {}
                return false;
              }
              var target = findSpiceTarget();
              focusTarget(target);
              var key = 'Backspace';
              var code = 'Backspace';
              var keyCode = 8;
              dispatchKey(target, 'keydown', key, code, keyCode);
              dispatchKey(target, 'keyup', key, code, keyCode);
              sendViaSpiceAPIKey(key);
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func processTypingBufferChange(old: String, new current: String) {
            guard let webView = self.webView else { return }
            // Determine if a single character was added or removed
            if current.count > old.count, let lastChar = current.last {
                let ch = String(lastChar)
                let escaped = ch
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
               
                
                let js = """
                (function(){
                  function findSpiceTarget(){
                    var canvas = document.querySelector('canvas');
                    if (canvas) return canvas;
                    var el = document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas');
                    return el || document.body;
                  }

                  function focusTarget(el){
                    try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex','0'); } catch(_) {}
                    try { el.focus(); } catch(_) {}
                  }

                  function dispatchKey(el, type, key, code, keyCode){
                    var evt = new KeyboardEvent(type, {
                      bubbles: true,
                      cancelable: true,
                      key: key,
                      code: code,
                      composed: true
                    });

                    try { Object.defineProperty(evt, 'keyCode', { get: function(){ return keyCode; } }); } catch(_){}
                    try { Object.defineProperty(evt, 'which', { get: function(){ return keyCode; } }); } catch(_){}
                    try { Object.defineProperty(evt, 'charCode', { get: function(){ return keyCode; } }); } catch(_){}

                    el.dispatchEvent(evt);
                  }

                  function sendViaSpiceAPIChar(ch){
                    try {
                      if (window.SpiceKeyboard && typeof window.SpiceKeyboard.sendChar === 'function') {
                        window.SpiceKeyboard.sendChar(ch);
                        return true;
                      }
                    } catch(_){}

                    try {
                      if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyPress === 'function') {
                        window.rfb._keyboard.keyPress(ch);
                        return true;
                      }
                    } catch(_){}

                    return false;
                  }

                  var target = findSpiceTarget();
                  focusTarget(target);

                  var ch = "\(escaped)";

                  // WICHTIG: Erst direkte Unicode-API versuchen
                  var sent = sendViaSpiceAPIChar(ch);

                  // Nur wenn API nicht existiert → ASCII Fallback
                  if (!sent && ch.length === 1 && ch.charCodeAt(0) < 128) {
                    var keyCode = ch.charCodeAt(0);
                    var code = 'Key' + ch.toUpperCase();
                    dispatchKey(target, 'keydown', ch, code, keyCode);
                    dispatchKey(target, 'keypress', ch, code, keyCode);
                    dispatchKey(target, 'keyup', ch, code, keyCode);
                  }

                })();
                """
                webView.evaluateJavaScript(js, completionHandler: nil)
                
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let prefix = "https://demo.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"
            let target = navigationAction.request.url?.absoluteString ?? ""
            let shouldLandscape = target.hasPrefix(prefix)
            DispatchQueue.main.async {
                self.parent.shouldForceLandscape = shouldLandscape
                self.parent.currentURL = navigationAction.request.url
            }
            decisionHandler(.allow)
        }

        // Wird aufgerufen, wenn das Laden beginnt (erste Antwort vom Server)
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.currentURL = webView.url
            }
        }

        // Wird aufgerufen, wenn Inhalte beginnen zu laden
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.currentURL = webView.url
            }
        }

        // Wird aufgerufen, wenn die Seite vollständig geladen ist
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                let prefix = "https://demo.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"
                let current = webView.url?.absoluteString ?? ""
                self.parent.shouldForceLandscape = current.hasPrefix(prefix)
                self.parent.currentURL = webView.url
            }
            let prefix = "https://demo.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"
            let current = webView.url?.absoluteString ?? ""
            if current.hasPrefix(prefix) {
                webView.pageZoom = self.parent.pageZoom
                webView.scrollView.isScrollEnabled = false
                webView.scrollView.alwaysBounceVertical = false
                webView.scrollView.alwaysBounceHorizontal = false
            }
            // Enable touch->mouse bridge only when we force landscape (SPICE session)
            let enableBridge = self.parent.shouldForceLandscape || current.hasPrefix(prefix)
            if enableBridge {
                webView.evaluateJavaScript("window.enableTouchMouseBridge = true;") { _, _ in }
                webView.evaluateJavaScript("window.touchMousePageZoom = \(self.parent.pageZoom);") { _, _ in }
                do {
                    let speedNumber = NSNumber(value: Double(self.parent.cursorSpeed))
                    let data = try JSONSerialization.data(withJSONObject: ["speed": speedNumber], options: [])
                    if let json = String(data: data, encoding: .utf8) {
                        webView.evaluateJavaScript("(function(){ try { var cfg = \(json); if (cfg && typeof cfg.speed === 'number' && isFinite(cfg.speed)) { window.touchMouseCursorSpeed = cfg.speed; } } catch(_){} })();") { _, _ in }
                    }
                } catch {
                    webView.evaluateJavaScript("window.touchMouseCursorSpeed = 1.0;") { _, _ in }
                }
                webView.evaluateJavaScript("window.touchMouseLerp = 0.6;") { _, _ in }
            } else {
                webView.evaluateJavaScript("window.enableTouchMouseBridge = false;") { _, _ in }
                webView.evaluateJavaScript("window.touchMousePageZoom = 1.0;") { _, _ in }
            }
        }

        // Fehler beim endgültigen Laden
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.currentURL = webView.url
            }
        }

        // Fehler bereits bei der vorläufigen Navigation (z.B. DNS/Netzwerk)
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.currentURL = webView.url
            }
        }
        
        private func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKContextMenuElementInfo) -> Bool {
            return false
        }
        
        // User content controller
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "haptics" else { return }
            if let body = message.body as? [String: Any], let type = body["type"] as? String {
                switch type {
                case "tap":
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                case "longPress":
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                default:
                    break
                }
            } else if let type = message.body as? String {
                // Fallback if only a string is sent
                if type == "tap" {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } else if type == "longPress" {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
        }
    }
    
}




// Xcode preview
#Preview {
    struct WebView_PreviewWrapper: View {
        @State private var isLoading = false
        @State private var shouldForceLandscape = false
        @State private var currentURL: URL? = nil
        @State private var requestedURL: URL? = nil
        @State private var requestKeyboardFocus: Bool = false
        @State private var typingBuffer: String = ""
        var body: some View {
            WebView(urlString: "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape, currentURL: $currentURL, requestedURL: $requestedURL, requestKeyboardFocus: $requestKeyboardFocus, typingBuffer: $typingBuffer, pageZoom: 0.95)
                .ignoresSafeArea()
        }
    }
    return WebView_PreviewWrapper()
}

