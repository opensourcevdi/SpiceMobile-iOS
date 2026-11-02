//
//  WebView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - Notifications

// Der Hidden-TextField und die VMView steuern die WebView über diese Notifications.
extension Notification.Name {
    static let webViewSendBackspace = Notification.Name("WebViewSendBackspace")
    static let webViewSendEnter = Notification.Name("WebViewSendEnter")
    static let webViewUploadFiles = Notification.Name("WebViewUploadFiles")
    static let webViewSendFunctionKey = Notification.Name("WebViewSendFunctionKey")
    static let webViewSendArrowKey = Notification.Name("WebViewSendArrowKey")
    static let webViewSendTab = Notification.Name("WebViewSendTab")
    static let webViewSendSuper = Notification.Name("WebViewSendSuper")
    static let webViewToggleShift = Notification.Name("WebViewToggleShift")
    static let webViewToggleControl = Notification.Name("WebViewToggleControl")
    static let webViewToggleOption = Notification.Name("WebViewToggleOption")
    static let webViewToggleCommand = Notification.Name("WebViewToggleCommand")
    static let webViewClearModifiers = Notification.Name("WebViewClearModifiers")
    static let webViewSetModifiers = Notification.Name("WebViewSetModifiers")
    /// Touches vom Handy-Touchpad im Controller-Modus (userInfo: type, touches, changed).
    static let webViewInjectTouch = Notification.Name("WebViewInjectTouch")
}

// MARK: - Container

/// Hält die WKWebView, damit sie zwischen Handy-Bildschirm und externem Display wechseln kann,
/// ohne dass die laufende Session neu geladen werden muss.
final class WebContainerView: UIView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        embedWebView(in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embedWebView(in host: UIView) {
        guard webView.superview !== host else { return }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor)
        ])
    }
}

// MARK: - WebView

struct WebView: UIViewRepresentable {

    private static let spiceURLPrefix = "https://bwlehrpool.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"

    let urlString: String
    @Binding var isLoading: Bool
    @Binding var shouldForceLandscape: Bool
    @Binding var currentURL: URL?
    @Binding var requestedURL: URL?
    @Binding var typingBuffer: String
    var pageZoom: CGFloat = 0.62
    var cursorSpeed: Double = 2.0
    var isPresentedExternally = false

    init(urlString: String,
         isLoading: Binding<Bool>,
         shouldForceLandscape: Binding<Bool>,
         currentURL: Binding<URL?>,
         requestedURL: Binding<URL?>,
         typingBuffer: Binding<String>,
         pageZoom: CGFloat = 0.62,
         cursorSpeed: Double = 2.0,
         isPresentedExternally: Bool = false) {
        self.isPresentedExternally = isPresentedExternally
        self.urlString = urlString
        self._isLoading = isLoading
        self._shouldForceLandscape = shouldForceLandscape
        self._currentURL = currentURL
        self._requestedURL = requestedURL
        self._typingBuffer = typingBuffer
        self.pageZoom = pageZoom
        self.cursorSpeed = cursorSpeed
    }

    fileprivate static func isSpiceURL(_ url: URL?) -> Bool {
        url?.absoluteString.hasPrefix(spiceURLPrefix) ?? false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WebContainerView {
        let webView = makeConfiguredWebView(context: context)
        let container = WebContainerView(webView: webView)

        context.coordinator.webView = webView
        DispatchQueue.main.async { context.coordinator.clearModifiers() }

        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Long-Press-Menüs und natives Drag & Drop stören die Touch-Steuerung
        webView.gestureRecognizers?
            .compactMap { $0 as? UILongPressGestureRecognizer }
            .forEach { $0.isEnabled = false }
        webView.interactions
            .compactMap { $0 as? UIDragInteraction }
            .forEach { webView.removeInteraction($0) }

        DispatchQueue.main.async {
            self.currentURL = nil
        }

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
            DispatchQueue.main.async {
                self.isLoading = true
                self.currentURL = url
            }
        }

        return container
    }

    static func dismantleUIView(_ container: WebContainerView, coordinator: Coordinator) {
        // Verhindert, dass eine verworfene WebView auf dem externen Display hängen bleibt
        container.webView.removeFromSuperview()
    }

    func updateUIView(_ container: WebContainerView, context: Context) {
        let webView = container.webView

        // Im Controller-Modus läuft die WebView auf dem externen Display, sonst im Container
        if isPresentedExternally, let host = ExternalDisplayManager.shared.hostView {
            container.embedWebView(in: host)
        } else {
            container.embedWebView(in: container)
        }

        context.coordinator.syncTypingBuffer(typingBuffer)

        guard let url = requestedURL else { return }

        if Self.isSpiceURL(url) {
            // SPICE-Einstellungen vor dem Laden festhalten
            webView.pageZoom = pageZoom
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.alwaysBounceVertical = false
            webView.scrollView.alwaysBounceHorizontal = false
            webView.scrollView.panGestureRecognizer.isEnabled = false
        } else {
            // Normales Browser-Verhalten wiederherstellen
            webView.pageZoom = 1.0
            webView.scrollView.isScrollEnabled = true
            webView.scrollView.alwaysBounceVertical = true
            webView.scrollView.alwaysBounceHorizontal = true
        }

        webView.load(URLRequest(url: url))

        // Request zurücksetzen, damit nicht erneut geladen wird
        DispatchQueue.main.async { self.requestedURL = nil }
    }

    private func makeConfiguredWebView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "haptics")
        contentController.addUserScript(JSLoader(fileName: "disableSelectionScript"))

        // touchToMouseScript.js nur laden, wenn Touch-Mode aktiv ist
        let isTouchModeEnabled = UserDefaults.standard.object(forKey: "isTouchMode") as? Bool ?? true
        if isTouchModeEnabled {
            contentController.addUserScript(JSLoader(fileName: "touchToMouseScript"))
        }

        // Pinch-Zoom der Seite selbst unterbinden
        contentController.addUserScript(JSLoader(fileName: "disableUserScalable", forMainFrameOnly: true))

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        return WKWebView(frame: .zero, configuration: config)
    }
}

// MARK: - Coordinator

extension WebView {

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

        let parent: WebView
        weak var webView: WKWebView?

        private var modifiers = ModifierState()
        private var lastTypingBuffer: String
        private var observers: [NSObjectProtocol] = []

        init(parent: WebView) {
            self.parent = parent
            self.lastTypingBuffer = parent.typingBuffer
            super.init()
            registerObservers()
        }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        // MARK: Notifications

        private func observe(_ name: Notification.Name, _ handler: @escaping (Coordinator, Notification) -> Void) {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                guard let self else { return }
                handler(self, note)
            }
            observers.append(token)
        }

        private func registerObservers() {
            observe(.webViewSendBackspace) { me, _ in me.run(KeyScripts.backspace) }
            observe(.webViewSendEnter) { me, _ in me.run(KeyScripts.enter) }
            observe(.webViewUploadFiles) { me, note in me.uploadFiles(from: note) }
            observe(.webViewInjectTouch) { me, note in me.injectTouch(from: note) }

            observe(.webViewSendFunctionKey) { me, note in
                let number = note.object as? Int ?? note.userInfo?["key"] as? Int
                guard let number, (1...12).contains(number) else { return }
                me.sendKey(.function(number))
            }
            observe(.webViewSendArrowKey) { me, note in
                let name = note.object as? String ?? note.userInfo?["direction"] as? String
                guard let name, let key = KeySpec.arrow(name) else { return }
                me.sendKey(key)
            }
            observe(.webViewSendTab) { me, _ in me.sendKey(.tab) }
            observe(.webViewSendSuper) { me, _ in me.sendKey(.superKey) }

            observe(.webViewToggleShift) { me, _ in me.modifiers.shift.toggle(); me.applyModifiers() }
            observe(.webViewToggleControl) { me, _ in me.modifiers.control.toggle(); me.applyModifiers() }
            observe(.webViewToggleOption) { me, _ in me.modifiers.option.toggle(); me.applyModifiers() }
            observe(.webViewToggleCommand) { me, _ in me.modifiers.command.toggle(); me.applyModifiers() }
            observe(.webViewClearModifiers) { me, _ in me.clearModifiers() }
            observe(.webViewSetModifiers) { me, note in
                if let info = note.userInfo {
                    me.modifiers.shift = info["shift"] as? Bool ?? me.modifiers.shift
                    me.modifiers.control = info["control"] as? Bool ?? me.modifiers.control
                    me.modifiers.option = info["option"] as? Bool ?? me.modifiers.option
                    me.modifiers.command = info["command"] as? Bool ?? me.modifiers.command
                }
                me.applyModifiers()
            }
        }

        // MARK: Modifiers

        func clearModifiers() {
            modifiers = ModifierState()
            applyModifiers()
        }

        /// Macht den Modifier-Zustand global für die eingeschleusten Key-Events verfügbar.
        private func applyModifiers() {
            run(JSLoader(fileName: "setModifiers", variables: [
                "__SHIFT__": "\(modifiers.shift)",
                "__CTRL__": "\(modifiers.control)",
                "__ALT__": "\(modifiers.option)",
                "__META__": "\(modifiers.command)"
            ]).source)
        }

        // MARK: Keyboard input

        private func run(_ js: String) {
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        private func sendKey(_ key: KeySpec) {
            run(KeyScripts.sendKey(key))
        }

        /// Reicht neu getippte Zeichen aus dem Hidden-TextField an die Remote-Session weiter.
        func syncTypingBuffer(_ newValue: String) {
            guard newValue != lastTypingBuffer else { return }
            let oldValue = lastTypingBuffer
            lastTypingBuffer = newValue

            // Nur hinzugefügte Zeichen werden gesendet; Backspace läuft über den TextField-Callback
            guard newValue.count > oldValue.count, let last = newValue.last else { return }
            run(KeyScripts.sendCharacter(last))
        }

        // MARK: Remote touch (Controller-Modus)

        /// Speist Touches des Handy-Touchpads in die Touch-zu-Maus-Brücke der Seite ein.
        private func injectTouch(from notification: Notification) {
            guard let info = notification.userInfo,
                  let type = info["type"] as? String,
                  let touches = info["touches"] as? [[Double]],
                  let changed = info["changed"] as? [[Double]],
                  let json = try? JSONSerialization.data(withJSONObject: [touches, changed]),
                  let points = String(data: json, encoding: .utf8) else { return }

            run("(function(a){ if (window.__touchBridgeInject) window.__touchBridgeInject('\(type)', a[0], a[1]); })(\(points));")
        }

        // MARK: File upload

        private func uploadFiles(from notification: Notification) {
            let urls = notification.object as? [URL] ?? notification.userInfo?["files"] as? [URL] ?? []

            let descriptors: [[String: String]] = urls.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                return [
                    "name": url.lastPathComponent,
                    "mime": mime,
                    "base64": data.base64EncodedString()
                ]
            }
            guard !descriptors.isEmpty,
                  let json = try? JSONSerialization.data(withJSONObject: descriptors),
                  let jsonString = String(data: json, encoding: .utf8) else { return }

            run(JSLoader(fileName: "fileUplaod", swiftVar: jsonString).source)
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            DispatchQueue.main.async {
                self.parent.shouldForceLandscape = WebView.isSpiceURL(url)
                self.parent.currentURL = url
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.currentURL = webView.url
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let isSpice = WebView.isSpiceURL(webView.url)

            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.shouldForceLandscape = isSpice
                self.parent.currentURL = webView.url
            }

            if isSpice {
                webView.pageZoom = parent.pageZoom
                webView.scrollView.isScrollEnabled = false
                webView.scrollView.alwaysBounceVertical = false
                webView.scrollView.alwaysBounceHorizontal = false
            }

            configureTouchBridge(enabled: isSpice || parent.shouldForceLandscape)

            DispatchQueue.main.async {
                self.clearModifiers()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishLoading(with: webView)
        }

        // Fehler bei der vorläufigen Navigation (z. B. DNS/Netzwerk)
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishLoading(with: webView)
        }

        private func finishLoading(with webView: WKWebView) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.currentURL = webView.url
            }
        }

        /// Schaltet die Touch-zu-Maus-Brücke im Seiteninhalt ein (SPICE-Session) oder aus.
        private func configureTouchBridge(enabled: Bool) {
            let speed = parent.cursorSpeed.isFinite ? parent.cursorSpeed : 1.0
            run(JSLoader(fileName: "configureTouchBridge", variables: [
                "__ENABLED__": "\(enabled)",
                "__PAGE_ZOOM__": "\(parent.pageZoom)",
                "__CURSOR_SPEED__": "\(speed)"
            ]).source)
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "haptics" else { return }

            let type = (message.body as? [String: Any])?["type"] as? String ?? message.body as? String
            switch type {
            case "tap":
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case "longPress":
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            default:
                break
            }
        }
    }
}

// MARK: - Modifier state

private struct ModifierState {
    var shift = false
    var control = false
    var option = false
    var command = false
}

// MARK: - Key definitions

/// Beschreibt eine Taste für die verschiedenen Backends (SPICE, noVNC, DOM-Event-Fallback).
private struct KeySpec {
    let spiceCode: Int      // Windows-Virtual-Key-Code für SpiceKeyboard
    let vncKeysym: Int      // X11-Keysym für noVNC
    let key: String
    let code: String
    let keyCode: Int
    var usesSpiceKeyCode = false    // Funktionstasten gehen über sendKeyCode statt sendKeyDown/Up
    var ignoresMeta = false         // die Super-Taste selbst darf Meta nicht zusätzlich halten

    static func function(_ n: Int) -> KeySpec {
        KeySpec(spiceCode: 111 + n, vncKeysym: 0xFFBD + n, key: "F\(n)", code: "F\(n)", keyCode: 111 + n,
                usesSpiceKeyCode: true)
    }

    static func arrow(_ direction: String) -> KeySpec? {
        switch direction {
        case "up": KeySpec(spiceCode: 38, vncKeysym: 0xFF52, key: "ArrowUp", code: "ArrowUp", keyCode: 38)
        case "down": KeySpec(spiceCode: 40, vncKeysym: 0xFF54, key: "ArrowDown", code: "ArrowDown", keyCode: 40)
        case "left": KeySpec(spiceCode: 37, vncKeysym: 0xFF51, key: "ArrowLeft", code: "ArrowLeft", keyCode: 37)
        case "right": KeySpec(spiceCode: 39, vncKeysym: 0xFF53, key: "ArrowRight", code: "ArrowRight", keyCode: 39)
        default: nil
        }
    }

    static let tab = KeySpec(spiceCode: 9, vncKeysym: 0xFF09, key: "Tab", code: "Tab", keyCode: 9)
    static let superKey = KeySpec(spiceCode: 91, vncKeysym: 0xFFEB, key: "Meta", code: "MetaLeft", keyCode: 91,
                                  ignoresMeta: true)
}

// MARK: - Injected key scripts

private enum KeyScripts {

    /// Sendet eine Taste (inkl. aktiver Modifier) über SPICE, noVNC oder als DOM-Event.
    static func sendKey(_ spec: KeySpec) -> String {
        load("sendKey", [
            "__SPICE_CODE__": "\(spec.spiceCode)",
            "__VNC_KEYSYM__": "\(spec.vncKeysym)",
            "__KEY__": spec.key,
            "__CODE__": spec.code,
            "__KEY_CODE__": "\(spec.keyCode)",
            "__USES_SPICE_KEYCODE__": "\(spec.usesSpiceKeyCode)",
            "__IGNORES_META__": "\(spec.ignoresMeta)"
        ])
    }

    /// Sendet ein einzelnes getipptes Zeichen.
    static func sendCharacter(_ character: Character) -> String {
        let literal = (try? JSONEncoder().encode(String(character))).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return load("sendCharacter", ["__CHARACTER__": literal])
    }

    static var backspace: String { load("sendBackspace") }
    static var enter: String { load("sendEnter") }

    /// Lädt ein Skript und fügt die gemeinsamen Tastatur-Helfer an der Stelle `__KEYBOARD_HELPERS__` ein.
    private static func load(_ name: String, _ variables: [String: String] = [:]) -> String {
        var variables = variables
        variables["__KEYBOARD_HELPERS__"] = JSLoader(fileName: "keyboardHelpers").source
        return JSLoader(fileName: name, variables: variables).source
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isLoading = false
        @State private var shouldForceLandscape = false
        @State private var currentURL: URL? = nil
        @State private var requestedURL: URL? = nil
        @State private var typingBuffer = ""

        var body: some View {
            WebView(urlString: "https://demo.osvdi.uni-freiburg.de/#/",
                    isLoading: $isLoading,
                    shouldForceLandscape: $shouldForceLandscape,
                    currentURL: $currentURL,
                    requestedURL: $requestedURL,
                    typingBuffer: $typingBuffer,
                    pageZoom: 0.95)
                .ignoresSafeArea()
        }
    }
    return PreviewWrapper()
}
