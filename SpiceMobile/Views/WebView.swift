//
//  WebView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import WebKit

// MARK: - WebView Wrapper
struct WebView: UIViewRepresentable {
    let urlString: String
    @Binding var isLoading: Bool
    @Binding var shouldForceLandscape: Bool
    var pageZoom: CGFloat = 0.5
    
    var pageReadyPredicateJS: String? = nil
    
    var pageReadyTimeout: TimeInterval = 10.0
    var pageReadyInterval: TimeInterval = 0.3

    private func makeConfiguredWebView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        let disableSelectionScript = """
var css = "* { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; -webkit-user-drag: none !important; } img, a, video, canvas { -webkit-user-drag: none !important; user-drag: none !important; }";
var style = document.createElement('style');
style.type = 'text/css';
style.appendChild(document.createTextNode(css));
document.documentElement.appendChild(style);

// Disable context menu & selection & gestures
['contextmenu','selectstart','gesturestart'].forEach(function(type){
  document.addEventListener(type, function(e){ e.preventDefault(); }, { passive: false });
});

// Prevent multi-touch default behaviors
document.addEventListener('touchstart', function(e) {
  if (e.touches && e.touches.length > 1) { e.preventDefault(); }
}, { passive: false });

// Disable HTML5 drag & drop on common draggable elements
function disableDragFor(selector) {
  document.querySelectorAll(selector).forEach(function(el){
    try { el.setAttribute('draggable', 'false'); } catch(_) {}
    el.addEventListener('dragstart', function(e){ e.preventDefault(); }, { passive: false });
    el.addEventListener('drag', function(e){ e.preventDefault(); }, { passive: false });
    el.addEventListener('drop', function(e){ e.preventDefault(); }, { passive: false });
  });
}

disableDragFor('img, a, video, canvas, svg, *[draggable="true"]');

// Also disable on dynamically added nodes
var observer = new MutationObserver(function(mutations){
  mutations.forEach(function(m){
    if (m.addedNodes) {
      m.addedNodes.forEach(function(node){
        if (node.nodeType === 1) {
          var el = node;
          if (el.matches && (el.matches('img, a, video, canvas, svg, *[draggable="true"]'))) {
            disableDragFor('img, a, video, canvas, svg, *[draggable="true"]');
          }
        }
      });
    }
  });
});
observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
"""
        let userScript = WKUserScript(source: disableSelectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        
        let touchToMouseScript = """
(function() {
  if (window.__touchMouseBridgeInstalled) return;
  window.__touchMouseBridgeInstalled = true;

  // Bridge is gated by this flag to allow enabling only when needed
  if (!('enableTouchMouseBridge' in window)) {
    Object.defineProperty(window, 'enableTouchMouseBridge', {
      configurable: false,
      enumerable: false,
      writable: true,
      value: false
    });
  }

  // Expose a page zoom factor from native; default 1.0
  if (!('touchMousePageZoom' in window)) {
    Object.defineProperty(window, 'touchMousePageZoom', {
      configurable: true,
      enumerable: false,
      writable: true,
      value: 1.0
    });
  }

  function getViewportScale() {
    try { return (window.visualViewport && window.visualViewport.scale) ? window.visualViewport.scale : 1; } catch(_) { return 1; }
  }

  function getEffectiveScale() {
    // Combine viewport scale and the native-provided page zoom
    const v = getViewportScale();
    const p = (typeof window.touchMousePageZoom === 'number' && window.touchMousePageZoom > 0) ? window.touchMousePageZoom : 1;
    return v * p;
  }

  // Create a simple overlay cursor dot
  function ensureCursorDot() {
    if (window.__touchMouseCursorDot) return window.__touchMouseCursorDot;
    const dot = document.createElement('div');
    dot.id = '__touchMouseCursorDot';
    dot.style.position = 'fixed';
    dot.style.width = '56px';
    dot.style.height = '56px';
    dot.style.marginLeft = '-7px';
    dot.style.marginTop = '-7px';
    dot.style.borderRadius = '50%';
    dot.style.background = 'rgba(255, 0, 0, 0.85)';
    dot.style.border = '2px solid white';
    dot.style.boxShadow = '0 0 6px rgba(0,0,0,0.4)';
    dot.style.zIndex = '2147483647';
    dot.style.pointerEvents = 'none';
    dot.style.left = '0px';
    dot.style.top = '0px';
    dot.style.opacity = '1';
    dot.style.transition = 'opacity 0.08s linear';
    document.documentElement.appendChild(dot);
    window.__touchMouseCursorDot = dot;
    return dot;
  }

  function showCursorAt(clientX, clientY) {
    const dot = ensureCursorDot();
    dot.style.left = clientX + 'px';
    dot.style.top = clientY + 'px';
    dot.style.opacity = '1';
  }

  function moveCursorOnly(touch) {
    const el = targetElementAt(touch);
    const clientXY = mapToElementClientXY(touch, el);
    showCursorAt(clientXY.clientX, clientXY.clientY);
  }

  function hideCursor() {
    const dot = ensureCursorDot();
    dot.style.opacity = '0';
  }

  function targetElementAt(touch) {
    return document.elementFromPoint(touch.clientX, touch.clientY) || document.body;
  }

  function mapToElementClientXY(touch, element) {
    const rect = element.getBoundingClientRect();
    const scale = getEffectiveScale();
    const x = (touch.clientX - rect.left) / scale;
    const y = (touch.clientY - rect.top) / scale;
    return { clientX: rect.left + x, clientY: rect.top + y };
  }

  function createMouseEvent(type, clientXY, button = 0, detail = 0) {
    const event = new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      view: window,
      clientX: clientXY.clientX,
      clientY: clientXY.clientY,
      screenX: 0,
      screenY: 0,
      button: button,
      buttons: button === 0 ? 0 : (1 << button),
      detail: detail
    });
    return event;
  }

  let isDragging = false;
  let lastTarget = null;
  let pendingTouch = null;
  let lastTapTime = 0;
  let lastTapX = 0;
  let lastTapY = 0;
  const doubleTapThreshold = 300; // ms
  const doubleTapDistance = 30; // px radius

  function dispatchAt(touch, type, button = 0, detail = 0) {
    const el = targetElementAt(touch);
    lastTarget = el;
    const clientXY = mapToElementClientXY(touch, el);
    showCursorAt(clientXY.clientX, clientXY.clientY);
    el.dispatchEvent(createMouseEvent(type, clientXY, button, detail));
  }

  function onTouchStart(e) {
    if (!window.enableTouchMouseBridge) return;
    if (e.touches.length !== 1) return;
    const t = e.touches[0];
    e.preventDefault();

    // Move cursor immediately for visual feedback
    moveCursorOnly(t);

    const now = Date.now();
    const dx = Math.abs(t.clientX - lastTapX);
    const dy = Math.abs(t.clientY - lastTapY);
    const isSecondTap = (now - lastTapTime) <= doubleTapThreshold && (dx*dx + dy*dy) <= (doubleTapDistance*doubleTapDistance);

    if (isSecondTap) {
      // Start selection/drag on double tap
      isDragging = true;
      dispatchAt(t, 'mousedown', 0);
      // reset lastTapTime to avoid triple-tap chaining
      lastTapTime = 0;
    } else {
      // remember this tap
      lastTapTime = now;
      lastTapX = t.clientX;
      lastTapY = t.clientY;
    }

    pendingTouch = t;
  }

  function onTouchMove(e) {
    if (!window.enableTouchMouseBridge) return;
    if (e.touches.length !== 1) return;
    const t = e.touches[0];
    e.preventDefault();
    // Always move the visible cursor immediately
    moveCursorOnly(t);
    if (isDragging) {
      dispatchAt(t, 'mousemove');
    } else {
      pendingTouch = t;
    }
  }

  function onTouchEnd(e) {
    if (!window.enableTouchMouseBridge) return;
    e.preventDefault();
    const t = (e.changedTouches && e.changedTouches[0]) || (e.touches && e.touches[0]) || pendingTouch;
    if (isDragging) {
      if (t) {
        dispatchAt(t, 'mouseup', 0);
      } else if (lastTarget) {
        lastTarget.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true }));
      }
    }
    isDragging = false;
    pendingTouch = null;
  }

  // Optional: two-finger scroll -> wheel, compensate scale for delta
  let lastTwoFingerY = null;
  function onTouchMoveTwoFinger(e) {
    if (!window.enableTouchMouseBridge) return;
    if (e.touches.length === 2) {
      e.preventDefault();
      const scale = getEffectiveScale();
      const avgX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
      const avgY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
      if (lastTwoFingerY != null) {
        const deltaY = (lastTwoFingerY - avgY) / scale;
        const wheelEvent = new WheelEvent('wheel', {
          bubbles: true,
          cancelable: true,
          deltaY: deltaY,
          deltaMode: 0
        });
        const el = document.elementFromPoint(avgX, avgY) || document.body;
        el.dispatchEvent(wheelEvent);
      }
      lastTwoFingerY = avgY;
    } else {
      lastTwoFingerY = null;
    }
  }

  // Attach listeners (passive: false so we can preventDefault)
  document.addEventListener('touchstart', function(e){
    if (e.touches.length === 1) onTouchStart(e);
  }, { passive: false });

  document.addEventListener('touchmove', function(e){
    if (e.touches.length === 1) onTouchMove(e);
    else if (e.touches.length === 2) onTouchMoveTwoFinger(e);
  }, { passive: false });

  document.addEventListener('touchend', function(e){
    onTouchEnd(e);
  }, { passive: false });
})();
"""
        let touchScript = WKUserScript(source: touchToMouseScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(touchScript)
        
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

        // Optional: Scroll und Zoom konfigurieren
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
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
            }
        }
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
     // Bei Bedarf URL dynamisch ändern
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let prefix = "https://demo.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"
            let target = navigationAction.request.url?.absoluteString ?? ""
            let shouldLandscape = target.hasPrefix(prefix)
            DispatchQueue.main.async {
                self.parent.shouldForceLandscape = shouldLandscape
            }
            decisionHandler(.allow)
        }

        // Wird aufgerufen, wenn das Laden beginnt (erste Antwort vom Server)
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        // Wird aufgerufen, wenn Inhalte beginnen zu laden
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        // Wird aufgerufen, wenn die Seite vollständig geladen ist
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                let prefix = "https://demo.osvdi.uni-freiburg.de/spice-html5/#spice+tls://"
                let current = webView.url?.absoluteString ?? ""
                self.parent.shouldForceLandscape = current.hasPrefix(prefix)
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
            } else {
                webView.evaluateJavaScript("window.enableTouchMouseBridge = false;") { _, _ in }
                webView.evaluateJavaScript("window.touchMousePageZoom = 1.0;") { _, _ in }
            }
        }

        // Fehler beim endgültigen Laden
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        // Fehler bereits bei der vorläufigen Navigation (z.B. DNS/Netzwerk)
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        private func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKContextMenuElementInfo) -> Bool {
            return false
        }
    }
}


#Preview {
    struct WebView_PreviewWrapper: View {
        @State private var isLoading = false
        @State private var shouldForceLandscape = false
        var body: some View {
            WebView(urlString: "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape, pageZoom: 0.95)
                .ignoresSafeArea()
        }
    }
    return WebView_PreviewWrapper()
}

