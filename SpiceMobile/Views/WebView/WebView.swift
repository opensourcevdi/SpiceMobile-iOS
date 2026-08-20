//
//  WebView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import WebKit
import UIKit
import UniformTypeIdentifiers


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
    
    /*
    func base64ForSFSymbol(named name: String, pointSize: CGFloat = 10, weight: UIImage.SymbolWeight = .regular) -> String? {

        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        if let image = UIImage(systemName: name, withConfiguration: config),
           let png = image.pngData() {
            return png.base64EncodedString()
        }
        return nil
    }
     */


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
        
        let source: String = "var meta = document.createElement('meta');" +
            "meta.name = 'viewport';" +
            "meta.content = 'user-scalable=no';" +
            "var head = document.getElementsByTagName('head')[0];" +
            "head.appendChild(meta);"

        let script: WKUserScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
       contentController.addUserScript(script)

        
        
  
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
        DispatchQueue.main.async { context.coordinator.clearModifiers() }

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

        // cursorSpeed will be applied on didFinish; no immediate action needed here

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
        
        // cursorSpeed is read in didFinish; no need to push here unless reloading
        
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

    // MARK: - Coordinator Class
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebView
        
        weak var webView: WKWebView?
        
        var lastLoggedTypingBuffer: String = ""
        
        private static let sendBackspaceNotification = Notification.Name("WebViewSendBackspace")
        private static let sendEnterNotification = Notification.Name("WebViewSendEnter")
        private static let uploadFilesNotification = Notification.Name("WebViewUploadFiles")
        
        private static let toggleShiftNotification = Notification.Name("WebViewToggleShift")
        private static let toggleControlNotification = Notification.Name("WebViewToggleControl")
        private static let toggleOptionNotification = Notification.Name("WebViewToggleOption")
        private static let toggleCommandNotification = Notification.Name("WebViewToggleCommand")
        private static let clearModifiersNotification = Notification.Name("WebViewClearModifiers")
        private static let setModifiersNotification = Notification.Name("WebViewSetModifiers")

        private static let sendArrowNotification = Notification.Name("WebViewSendArrowKey")
        private static let sendTabNotification = Notification.Name("WebViewSendTab")
        private static let sendSuperNotification = Notification.Name("WebViewSendSuper")
        
        var shiftActive: Bool = false
        var controlActive: Bool = false
        var optionActive: Bool = false
        var commandActive: Bool = false

        init(parent: WebView) {
            self.parent = parent
            self.lastLoggedTypingBuffer = parent.typingBuffer
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(handleBackspaceNotification), name: Coordinator.sendBackspaceNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleEnterNotification), name: Coordinator.sendEnterNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleUploadFilesNotification(_:)), name: Coordinator.uploadFilesNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleFunctionKeyNotification(_:)), name: Notification.Name("WebViewSendFunctionKey"), object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggleShift), name: Coordinator.toggleShiftNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggleControl), name: Coordinator.toggleControlNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggleOption), name: Coordinator.toggleOptionNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggleCommand), name: Coordinator.toggleCommandNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleClearModifiers), name: Coordinator.clearModifiersNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSetModifiers(_:)), name: Coordinator.setModifiersNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(handleArrowKeyNotification(_:)), name: Coordinator.sendArrowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSendTab), name: Coordinator.sendTabNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSendSuper), name: Coordinator.sendSuperNotification, object: nil)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleBackspaceNotification() {
            sendBackspace()
        }
        
        @objc private func handleEnterNotification() {
            sendEnter()
        }
        
        @objc private func handleUploadFilesNotification(_ notification: Notification) {
            
            // Extract files array of URLs either from notification.object or notification.userInfo["files"]
            let fileURLs: [URL]?
            if let obj = notification.object as? [URL] {
                fileURLs = obj
            } else if let info = notification.userInfo, let files = info["files"] as? [URL] {
                fileURLs = files
            } else {
                fileURLs = nil
            }
            
            guard let urls = fileURLs, !urls.isEmpty else { return }
            
            var fileDescriptors: [[String: String]] = []
            
            for fileURL in urls {
                guard let data = try? Data(contentsOf: fileURL) else { continue }
                
                let ext = fileURL.pathExtension
                let utType = UTType(filenameExtension: ext)
                let mime = utType?.preferredMIMEType ?? "application/octet-stream"
                
                let base64String = data.base64EncodedString()
                
                fileDescriptors.append([
                    "name": fileURL.lastPathComponent,
                    "mime": mime,
                    "base64": base64String
                ])
            }
            
            guard !fileDescriptors.isEmpty else { return }
            
            var jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: fileDescriptors, options: [])
            } catch {
                return
            }
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
    
            // JS to create File objects and send to appropriate handlers
            
            guard self.webView != nil else { return }

            guard let webView = self.webView else { return }
            let js = JSLoader(fileName: "fileUplaod", swiftVar: jsonString)
 
            webView.evaluateJavaScript(js.source, completionHandler: nil)
        }
        
        func sendBackspace() {
            guard let webView = self.webView else { return }
            let js = JSLoader(fileName: "sendBackspace")
 
            webView.evaluateJavaScript(js.source, completionHandler: nil)
        }
        
        func sendEnter() {
            guard let webView = self.webView else { return }
            let js = JSLoader(fileName: "sendEnter")
            webView.evaluateJavaScript(js.source, completionHandler: nil)
        }

        @objc private func handleFunctionKeyNotification(_ notification: Notification) {
            var n: Int? = nil
            if let obj = notification.object as? Int {
                n = obj
            } else if let info = notification.userInfo?["key"] as? Int {
                n = info
            }
            guard let num = n, (1...12).contains(num) else { return }
            sendFunctionKey(num)
        }
        
        @objc private func handleToggleShift() { shiftActive.toggle(); applyModifierStateToPage() }
        @objc private func handleToggleControl() { controlActive.toggle(); applyModifierStateToPage() }
        @objc private func handleToggleOption() { optionActive.toggle(); applyModifierStateToPage() }
        @objc private func handleToggleCommand() { commandActive.toggle(); applyModifierStateToPage() }
        @objc private func handleClearModifiers() { shiftActive = false; controlActive = false; optionActive = false; commandActive = false; applyModifierStateToPage() }
        @objc private func handleSetModifiers(_ note: Notification) {
            if let info = note.userInfo {
                if let s = info["shift"] as? Bool { shiftActive = s }
                if let c = info["control"] as? Bool { controlActive = c }
                if let o = info["option"] as? Bool { optionActive = o }
                if let m = info["command"] as? Bool { commandActive = m }
            }
            applyModifierStateToPage()
        }
        
        @objc private func handleArrowKeyNotification(_ notification: Notification) {
            // Expect direction in object or userInfo["direction"]: "up","down","left","right"
            var dir: String? = nil
            if let s = notification.object as? String { dir = s }
            else if let s = notification.userInfo?["direction"] as? String { dir = s }
            guard let direction = dir else { return }
            sendArrowKey(direction)
        }
        @objc private func handleSendTab() { sendTabKey() }
        @objc private func handleSendSuper() { sendSuperKey() }
        
        private func applyModifierStateToPage() {
            guard let webView = self.webView else { return }
            // Expose modifier state globally so injected key events can use it
            let shift = shiftActive ? "true" : "false"
            let ctrl = controlActive ? "true" : "false"
            let alt = optionActive ? "true" : "false"
            let meta = commandActive ? "true" : "false"
            let finalJS = "(function(){ window.__iosModifiers = window.__iosModifiers || {}; window.__iosModifiers.shift = \(shift); window.__iosModifiers.ctrl = \(ctrl); window.__iosModifiers.alt = \(alt); window.__iosModifiers.meta = \(meta); })();"
            webView.evaluateJavaScript(finalJS, completionHandler: nil)
        }

        func sendFunctionKey(_ n: Int) {
            guard let webView = self.webView else { return }
            let shift = shiftActive ? "true" : "false"
            let ctrl = controlActive ? "true" : "false"
            let alt = optionActive ? "true" : "false"
            let meta = commandActive ? "true" : "false"
            let js = """
            (function(){
                function focusTarget(el){
                    try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex','0'); } catch(_) {}
                    try { el.focus(); } catch(_) {}
                }
                function findTarget(){
                    var canvas = document.querySelector('canvas');
                    if (canvas) return canvas;
                    var el = document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas');
                    return el || document.body;
                }
                function dispatchKey(el, type, key, code, keyCode, mods){
                    var evt = new KeyboardEvent(type, {
                        bubbles: true,
                        cancelable: true,
                        key: key,
                        code: code,
                        composed: true,
                        shiftKey: !!mods.shift,
                        ctrlKey: !!mods.ctrl,
                        altKey: !!mods.alt,
                        metaKey: !!mods.meta
                    });
                    try { Object.defineProperty(evt, 'keyCode', { get: function(){ return keyCode; } }); } catch(_){ }
                    try { Object.defineProperty(evt, 'which', { get: function(){ return keyCode; } }); } catch(_){ }
                    el.dispatchEvent(evt);
                }
                function getMods(){
                    var m = (typeof window.__iosModifiers === 'object' && window.__iosModifiers) || {};
                    return { shift: !!m.shift || \(shift), ctrl: !!m.ctrl || \(ctrl), alt: !!m.alt || \(alt), meta: !!m.meta || \(meta) };
                }
                function sendViaAPI(n, mods){
                    // Try SPICE first
                    try {
                        if (window.SpiceKeyboard && typeof window.SpiceKeyboard.sendKeyCode === 'function') {
                            // If Spice supports modifiers, try to send modifier presses around the key
                            // F1 base 112
                            var keycode = 112 + (n - 1);
                            // Try modifier down
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(16); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(17); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(18); } catch(_){}
                            try { if (mods.meta && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(91); } catch(_){}
                            window.SpiceKeyboard.sendKeyCode(keycode);
                            // Modifier up
                            try { if (mods.meta && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(91); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(18); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(17); } catch(_){}
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(16); } catch(_){}
                            return true;
                        }
                    } catch(_){ }
                    // Try noVNC API
                    try {
                        if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyDown === 'function' && typeof window.rfb._keyboard.keyUp === 'function') {
                            function modDown(up){
                                try { if (mods.shift) window.rfb._keyboard[up ? 'keyUp' : 'keyDown']({ keysym: 0xFFE1 }); } catch(_){}
                                try { if (mods.ctrl) window.rfb._keyboard[up ? 'keyUp' : 'keyDown']({ keysym: 0xFFE3 }); } catch(_){}
                                try { if (mods.alt) window.rfb._keyboard[up ? 'keyUp' : 'keyDown']({ keysym: 0xFFE9 }); } catch(_){}
                                try { if (mods.meta) window.rfb._keyboard[up ? 'keyUp' : 'keyDown']({ keysym: 0xFFE7 }); } catch(_){}
                            }
                            var base = 0xFFBE; // XK_F1
                            var keysym = base + (n - 1);
                            modDown(false);
                            window.rfb._keyboard.keyDown({ keysym: keysym });
                            window.rfb._keyboard.keyUp({ keysym: keysym });
                            modDown(true);
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                var target = findTarget();
                focusTarget(target);
                var n = \(n);
                var mods = getMods();
                var sent = sendViaAPI(n, mods);
                if (!sent) {
                    var keyName = 'F' + String(n);
                    var keyCode = 111 + n; // 112..123
                    dispatchKey(target, 'keydown', keyName, keyName, keyCode, mods);
                    dispatchKey(target, 'keyup', keyName, keyName, keyCode, mods);
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        func sendArrowKey(_ direction: String) {
            guard let webView = self.webView else { return }
            let shift = shiftActive ? "true" : "false"
            let ctrl = controlActive ? "true" : "false"
            let alt = optionActive ? "true" : "false"
            let meta = commandActive ? "true" : "false"
            let js = """
            (function(){
                function focusTarget(el){ try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex','0'); } catch(_){} try { el.focus(); } catch(_){} }
                function findTarget(){ var c=document.querySelector('canvas'); if(c) return c; var el=document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas'); return el||document.body; }
                function dispatchKey(el, type, key, code, keyCode, mods){
                    var evt = new KeyboardEvent(type, { bubbles:true, cancelable:true, key:key, code:code, composed:true, shiftKey:!!mods.shift, ctrlKey:!!mods.ctrl, altKey:!!mods.alt, metaKey:!!mods.meta });
                    try{ Object.defineProperty(evt,'keyCode',{ get:function(){ return keyCode; } }); }catch(_){ }
                    try{ Object.defineProperty(evt,'which',{ get:function(){ return keyCode; } }); }catch(_){ }
                    el.dispatchEvent(evt);
                }
                function getMods(){ var m=(typeof window.__iosModifiers==='object' && window.__iosModifiers)||{}; return { shift:!!m.shift || \(shift), ctrl:!!m.ctrl || \(ctrl), alt:!!m.alt || \(alt), meta:!!m.meta || \(meta) }; }
                function spiceVKForArrow(dir){ return dir==='up'?38:dir==='down'?40:dir==='left'?37:39; }
                function sendViaSpice(dir, mods){
                    try {
                        if (window.SpiceKeyboard && (window.SpiceKeyboard.sendKeyDown || window.SpiceKeyboard.sendKeyUp)) {
                            var vk = spiceVKForArrow(dir);
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(16); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(17); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(18); } catch(_){}
                            try { if (mods.meta && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(91); } catch(_){}
                            try { if (window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(vk); } catch(_){}
                            try { if (window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(vk); } catch(_){}
                            try { if (mods.meta && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(91); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(18); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(17); } catch(_){}
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(16); } catch(_){}
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                function sendViaNoVNC(dir, mods){
                    try {
                        if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyDown==='function' && typeof window.rfb._keyboard.keyUp==='function') {
                            function mod(up){ try{ if(mods.shift) window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE1}); }catch(_){ }
                                              try{ if(mods.ctrl)  window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE3}); }catch(_){}
                                              try{ if(mods.alt)   window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE9}); }catch(_){}
                                              try{ if(mods.meta)  window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE7}); }catch(_){ } }
                            var map = { up:0xFF52, down:0xFF54, left:0xFF51, right:0xFF53 };
                            var ks = map[dir]; if (!ks) return false;
                            mod(false);
                            window.rfb._keyboard.keyDown({keysym: ks});
                            window.rfb._keyboard.keyUp({keysym: ks});
                            mod(true);
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                var target = findTarget(); focusTarget(target);
                var mods = getMods();
                var dir = "__DIR__";
                var sent = sendViaSpice(dir, mods) || sendViaNoVNC(dir, mods);
                if (!sent) {
                    var map = { up:{key:'ArrowUp', code:'ArrowUp', keyCode:38}, down:{key:'ArrowDown', code:'ArrowDown', keyCode:40}, left:{key:'ArrowLeft', code:'ArrowLeft', keyCode:37}, right:{key:'ArrowRight', code:'ArrowRight', keyCode:39} };
                    var info = map[dir]; if (!info) return;
                    dispatchKey(target,'keydown', info.key, info.code, info.keyCode, mods);
                    dispatchKey(target,'keyup',   info.key, info.code, info.keyCode, mods);
                }
            })();
            """
            .replacingOccurrences(of: "__DIR__", with: direction)
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func sendTabKey() {
            guard let webView = self.webView else { return }
            let shift = shiftActive ? "true" : "false"
            let ctrl = controlActive ? "true" : "false"
            let alt = optionActive ? "true" : "false"
            let meta = commandActive ? "true" : "false"
            let js = """
            (function(){
                function focusTarget(el){ try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex','0'); } catch(_){} try { el.focus(); } catch(_){} }
                function findTarget(){ var c=document.querySelector('canvas'); if(c) return c; var el=document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas'); return el||document.body; }
                function dispatchKey(el, type, key, code, keyCode, mods){
                    var evt = new KeyboardEvent(type, { bubbles:true, cancelable:true, key:key, code:code, composed:true, shiftKey:!!mods.shift, ctrlKey:!!mods.ctrl, altKey:!!mods.alt, metaKey:!!mods.meta });
                    try{ Object.defineProperty(evt,'keyCode',{ get:function(){ return keyCode; } }); }catch(_){ }
                    try{ Object.defineProperty(evt,'which',{ get:function(){ return keyCode; } }); }catch(_){ }
                    el.dispatchEvent(evt);
                }
                function getMods(){ var m=(typeof window.__iosModifiers==='object' && window.__iosModifiers)||{}; return { shift:!!m.shift || \(shift), ctrl:!!m.ctrl || \(ctrl), alt:!!m.alt || \(alt), meta:!!m.meta || \(meta) }; }
                function sendViaSpice(mods){
                    try {
                        if (window.SpiceKeyboard && (window.SpiceKeyboard.sendKeyDown || window.SpiceKeyboard.sendKeyUp)) {
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(16); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(17); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(18); } catch(_){}
                            try { if (mods.meta && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(91); } catch(_){}
                            try { if (window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(9); } catch(_){}
                            try { if (window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(9); } catch(_){}
                            try { if (mods.meta && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(91); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(18); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(17); } catch(_){}
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(16); } catch(_){}
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                function sendViaNoVNC(mods){
                    try {
                        if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyDown==='function' && typeof window.rfb._keyboard.keyUp==='function') {
                            function mod(up){ try{ if(mods.shift) window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE1}); }catch(_){}
                                              try{ if(mods.ctrl)  window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE3}); }catch(_){}
                                              try{ if(mods.alt)   window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE9}); }catch(_){}
                                              try{ if(mods.meta)  window.rfb._keyboard[up?'keyUp':'keyDown']({keysym:0xFFE7}); }catch(_){} }
                            mod(false);
                            window.rfb._keyboard.keyDown({keysym: 0xFF09});
                            window.rfb._keyboard.keyUp({keysym: 0xFF09});
                            mod(true);
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                var target = findTarget(); focusTarget(target);
                var mods = getMods();
                var sent = sendViaSpice(mods) || sendViaNoVNC(mods);
                if (!sent) {
                    var key = 'Tab', code = 'Tab', keyCode = 9;
                    dispatchKey(target,'keydown', key, code, keyCode, mods);
                    dispatchKey(target,'keyup',   key, code, keyCode, mods);
                }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func sendSuperKey() {
            guard let webView = self.webView else { return }
            let shift = shiftActive ? "true" : "false"
            let ctrl = controlActive ? "true" : "false"
            let alt = optionActive ? "true" : "false"
            let meta = commandActive ? "true" : "false"
            let js = """
            (function(){
                function focusTarget(el){ try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex','0'); } catch(_){} try { el.focus(); } catch(_){} }
                function findTarget(){ var c=document.querySelector('canvas'); if(c) return c; var el=document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas'); return el||document.body; }
                function dispatchKey(el, type, key, code, keyCode, mods){
                    var evt = new KeyboardEvent(type, { bubbles:true, cancelable:true, key:key, code:code, composed:true, shiftKey:!!mods.shift, ctrlKey:!!mods.ctrl, altKey:!!mods.alt, metaKey:!!mods.meta });
                    try{ Object.defineProperty(evt,'keyCode',{ get:function(){ return keyCode; } }); }catch(_){ }
                    try{ Object.defineProperty(evt,'which',{ get:function(){ return keyCode; } }); }catch(_){ }
                    el.dispatchEvent(evt);
                }
                function getMods(){ var m=(typeof window.__iosModifiers==='object' && window.__iosModifiers)||{}; return { shift:!!m.shift || \(shift), ctrl:!!m.ctrl || \(ctrl), alt:!!m.alt || \(alt), meta:!!m.meta || \(meta) }; }
                function sendViaSpice(mods){
                    try {
                        if (window.SpiceKeyboard && (window.SpiceKeyboard.sendKeyDown || window.SpiceKeyboard.sendKeyUp)) {
                            // Press and release the Windows key (VK_LWIN ~ 91)
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(16); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(17); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(18); } catch(_){}
                            try { if (window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(91); } catch(_){}
                            try { if (window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(91); } catch(_){}
                            try { if (mods.alt && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(18); } catch(_){}
                            try { if (mods.ctrl && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(17); } catch(_){}
                            try { if (mods.shift && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(16); } catch(_){}
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                function sendViaNoVNC(mods){
                    try {
                        if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyDown==='function' && typeof window.rfb._keyboard.keyUp==='function') {
                            // Super_L keysym 0xFFEB
                            window.rfb._keyboard.keyDown({keysym: 0xFFEB});
                            window.rfb._keyboard.keyUp({keysym: 0xFFEB});
                            return true;
                        }
                    } catch(_){ }
                    return false;
                }
                var target = findTarget(); focusTarget(target);
                var mods = getMods();
                var sent = sendViaSpice(mods) || sendViaNoVNC(mods);
                if (!sent) {
                    var key = 'Meta'; var code = 'MetaLeft'; var keyCode = 91;
                    dispatchKey(target,'keydown', key, code, keyCode, mods);
                    dispatchKey(target,'keyup',   key, code, keyCode, mods);
                }
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
                  function dispatchKey(el, type, key, code, keyCode, mods){
                    var evt = new KeyboardEvent(type, {
                      bubbles: true,
                      cancelable: true,
                      key: key,
                      code: code,
                      composed: true,
                      shiftKey: !!mods.shift,
                      ctrlKey: !!mods.ctrl,
                      altKey: !!mods.alt,
                      metaKey: !!mods.meta
                    });
                    try { Object.defineProperty(evt, 'keyCode', { get: function(){ return keyCode; } }); } catch(_){}
                    try { Object.defineProperty(evt, 'which', { get: function(){ return keyCode; } }); } catch(_){}
                    try { Object.defineProperty(evt, 'charCode', { get: function(){ return keyCode; } }); } catch(_){}
                    el.dispatchEvent(evt);
                  }
                  function sendViaSpiceAPIChar(ch, mods){
                    try {
                      if (window.SpiceKeyboard && typeof window.SpiceKeyboard.sendChar === 'function') {
                        // Attempt to hold modifiers around char if supported
                        try { if (mods.shift && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(16); } catch(_){}
                        try { if (mods.ctrl && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(17); } catch(_){}
                        try { if (mods.alt && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(18); } catch(_){}
                        try { if (mods.meta && window.SpiceKeyboard.sendKeyDown) window.SpiceKeyboard.sendKeyDown(91); } catch(_){}
                        window.SpiceKeyboard.sendChar(ch);
                        try { if (mods.meta && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(91); } catch(_){}
                        try { if (mods.alt && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(18); } catch(_){}
                        try { if (mods.ctrl && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(17); } catch(_){}
                        try { if (mods.shift && window.SpiceKeyboard.sendKeyUp) window.SpiceKeyboard.sendKeyUp(16); } catch(_){}
                        return true;
                      }
                    } catch(_){ }
                    try {
                      if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyPress === 'function') {
                        // noVNC keyPress doesn't take modifiers directly; try modifier down/up around it
                        function modDown(up){
                          try { if (mods.shift) window.rfb._keyboard[up?'keyUp':'keyDown']({keysym: 0xFFE1}); } catch(_){}
                          try { if (mods.ctrl) window.rfb._keyboard[up?'keyUp':'keyDown']({keysym: 0xFFE3}); } catch(_){}
                          try { if (mods.alt) window.rfb._keyboard[up?'keyUp':'keyDown']({keysym: 0xFFE9}); } catch(_){}
                          try { if (mods.meta) window.rfb._keyboard[up?'keyUp':'keyDown']({keysym: 0xFFE7}); } catch(_){}
                        }
                        modDown(false);
                        window.rfb._keyboard.keyPress(ch);
                        modDown(true);
                        return true;
                      }
                    } catch(_){ }
                    return false;
                  }
                  function getMods(){
                    var m = (typeof window.__iosModifiers === 'object' && window.__iosModifiers) || {};
                    return { shift: !!m.shift, ctrl: !!m.ctrl, alt: !!m.alt, meta: !!m.meta };
                  }
                  var target = findSpiceTarget();
                  focusTarget(target);
                  var ch = "\(escaped)";
                  var mods = getMods();
                  var sent = sendViaSpiceAPIChar(ch, mods);
                  if (!sent && ch.length === 1 && ch.charCodeAt(0) < 128) {
                    var keyCode = ch.charCodeAt(0);
                    var code = 'Key' + ch.toUpperCase();
                    dispatchKey(target, 'keydown', ch, code, keyCode, mods);
                    dispatchKey(target, 'keypress', ch, code, keyCode, mods);
                    dispatchKey(target, 'keyup', ch, code, keyCode, mods);
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
                webView.evaluateJavaScript("window.touchMouseScrollSpeed = 2.0;") { _, _ in }
            } else {
                webView.evaluateJavaScript("window.enableTouchMouseBridge = false;") { _, _ in }
                webView.evaluateJavaScript("window.touchMousePageZoom = 1.0;") { _, _ in }
            }
            
            DispatchQueue.main.async {
                self.clearModifiers()
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
        
        func clearModifiers() {
            shiftActive = false; controlActive = false; optionActive = false; commandActive = false
            applyModifierStateToPage()
        }
    }
    
}

extension WebView.Coordinator {
    static func toggleShift() { NotificationCenter.default.post(name: Notification.Name("WebViewToggleShift"), object: nil) }
    static func toggleControl() { NotificationCenter.default.post(name: Notification.Name("WebViewToggleControl"), object: nil) }
    static func toggleOption() { NotificationCenter.default.post(name: Notification.Name("WebViewToggleOption"), object: nil) }
    static func toggleCommand() { NotificationCenter.default.post(name: Notification.Name("WebViewToggleCommand"), object: nil) }
    static func clearModifiers() { NotificationCenter.default.post(name: Notification.Name("WebViewClearModifiers"), object: nil) }
    static func setModifiers(shift: Bool, control: Bool, option: Bool, command: Bool) {
        NotificationCenter.default.post(name: Notification.Name("WebViewSetModifiers"), object: nil, userInfo: ["shift": shift, "control": control, "option": option, "command": command])
    }
    static func sendArrow(_ direction: String) { NotificationCenter.default.post(name: Notification.Name("WebViewSendArrowKey"), object: direction) }
    static func sendTab() { NotificationCenter.default.post(name: Notification.Name("WebViewSendTab"), object: nil) }
    static func sendSuper() { NotificationCenter.default.post(name: Notification.Name("WebViewSendSuper"), object: nil) }
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

