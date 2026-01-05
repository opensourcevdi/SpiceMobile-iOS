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
    var cursorSpeed: Double = 3.0
    
    var pageReadyPredicateJS: String? = nil
    
    var pageReadyTimeout: TimeInterval = 10.0
    var pageReadyInterval: TimeInterval = 0.3

    private func makeConfiguredWebView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "haptics")
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

  // Track cursor and touch positions for delta-based movement
  let cursorX = 0;
  let cursorY = 0;
  let hasCursorPosition = false;
  let lastTouchX = 0;
  let lastTouchY = 0;

  // Tap detection
  let touchStartTime = 0;
  const tapTimeThreshold = 300; // ms
  const tapMoveThreshold = 6; // px radius

  // Long-press detection for starting selection/drag
  let longPressTimer = null;
  const longPressDelay = 400; // ms
  let movedBeyondLongPress = false;
  let longPressStartX = 0;
  let longPressStartY = 0;
  const longPressRadius = 18; // px
  // Stroke detection (swipe/draw): if moved beyond a slightly larger threshold, suppress click on end
  let isStrokeGesture = false;
  let totalMoveSinceStartSq = 0;

  function distanceSq(aX, aY, bX, bY) { const dx = aX - bX; const dy = aY - bY; return dx*dx + dy*dy; }

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
    if (!hasCursorPosition) {
      cursorX = parseFloat(dot.style.left) || 0;
      cursorY = parseFloat(dot.style.top) || 0;
      hasCursorPosition = true;
    }
    return dot;
  }

  function showCursorAt(clientX, clientY) {
    const dot = ensureCursorDot();
    cursorX = clientX;
    cursorY = clientY;
    dot.style.left = cursorX + 'px';
    dot.style.top = cursorY + 'px';
    dot.style.opacity = '1';
    hasCursorPosition = true;
  }

  function moveCursorBy(dx, dy) {
    const dot = ensureCursorDot();
    const speed = (typeof window.touchMouseCursorSpeed === 'number' && isFinite(window.touchMouseCursorSpeed) && window.touchMouseCursorSpeed > 0) ? window.touchMouseCursorSpeed : 1.6;
    const eff = getEffectiveScale(); // visualViewport.scale * touchMousePageZoom
    const sx = (dx * speed) / (eff || 1);
    const sy = (dy * speed) / (eff || 1);
    cursorX += sx;
    cursorY += sy;
    dot.style.left = cursorX + 'px';
    dot.style.top = cursorY + 'px';
    dot.style.opacity = '1';
    hasCursorPosition = true;
  }



  function targetElementAt(touch) {
    return document.elementFromPoint(touch.clientX, touch.clientY) || document.body;
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
    const el = lastTarget || targetElementAt(touch);
    lastTarget = el;
    const clientXY = { clientX: cursorX, clientY: cursorY };
    el.dispatchEvent(createMouseEvent(type, clientXY, button, detail));
  }

  function onTouchStart(e) {
    if (!window.enableTouchMouseBridge) return;
    if (e.touches.length !== 1) return;
    const t = e.touches[0];
    e.preventDefault();

    touchStartTime = Date.now();

    // Remember initial touch position for delta, show cursor without teleport
    lastTouchX = t.clientX;
    lastTouchY = t.clientY;

    longPressStartX = t.clientX;
    longPressStartY = t.clientY;
    movedBeyondLongPress = false;

    const dot = ensureCursorDot();
    dot.style.opacity = '1';

    // Schedule long-press to start dragging
    if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
    longPressTimer = setTimeout(function(){
      const stayedNear = distanceSq(lastTouchX, lastTouchY, longPressStartX, longPressStartY) <= (longPressRadius * longPressRadius);
      if (!stayedNear || movedBeyondLongPress || isDragging) { return; }
      // Start selection/drag at the current cursor position (do not realign to touch to avoid visible jump)
      try { if (typeof syncCursorOverlay === 'function') { syncCursorOverlay(); } } catch(_){ }
      isDragging = true;
      const el = document.elementFromPoint(cursorX, cursorY) || document.body;
      const clientXY = { clientX: cursorX, clientY: cursorY };
      el.dispatchEvent(createMouseEvent('mousedown', clientXY, 0, 1));
      // Haptic feedback like single tap when selection starts
      try { if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.haptics) { window.webkit.messageHandlers.haptics.postMessage({ type: 'tap' }); } } catch(_){}
    }, longPressDelay);

    isStrokeGesture = false;
    totalMoveSinceStartSq = 0;
    pendingTouch = t;
  }

  function onTouchMove(e) {
    if (!window.enableTouchMouseBridge) return;
    if (e.touches.length !== 1) return;
    const t = e.touches[0];
    e.preventDefault();

    const dx = t.clientX - lastTouchX;
    const dy = t.clientY - lastTouchY;
    lastTouchX = t.clientX;
    lastTouchY = t.clientY;

    if (!movedBeyondLongPress) {
      movedBeyondLongPress = distanceSq(lastTouchX, lastTouchY, longPressStartX, longPressStartY) > (longPressRadius * longPressRadius);
    }

    if (!isDragging) {
      const moveSq = dx*dx + dy*dy;
      if (moveSq > (tapMoveThreshold * tapMoveThreshold)) {
        movedBeyondLongPress = true;
      }
      // If the finger moves more than a modest threshold from the initial long-press start, consider it a stroke
      const fromStartSq = distanceSq(lastTouchX, lastTouchY, longPressStartX, longPressStartY);
      if (fromStartSq > ((longPressRadius * 1.2) * (longPressRadius * 1.2))) {
        isStrokeGesture = true;
      }
      // Not dragging yet: move cursor and also send mousemove to keep page logic in sync
      moveCursorBy(dx, dy);
      const el = document.elementFromPoint(cursorX, cursorY) || document.body;
      const clientXY = { clientX: cursorX, clientY: cursorY };
      el.dispatchEvent(createMouseEvent('mousemove', clientXY));
      pendingTouch = t;
      return;
    }

    // Dragging: move the cursor by delta and send mousemove at the last target
    moveCursorBy(dx, dy);
    const el = lastTarget || document.elementFromPoint(cursorX, cursorY) || document.body;
    const clientXY = { clientX: cursorX, clientY: cursorY };
    el.dispatchEvent(createMouseEvent('mousemove', clientXY));
    // While dragging, any meaningful movement marks this as a stroke-like interaction
    const fromStartDragSq = distanceSq(cursorX, cursorY, longPressStartX, longPressStartY);
    if (fromStartDragSq > ((longPressRadius * 1.0) * (longPressRadius * 1.0))) {
      isStrokeGesture = true;
    }
  }

  function onTouchEnd(e) {
    if (!window.enableTouchMouseBridge) return;
    e.preventDefault();
    const t = (e.changedTouches && e.changedTouches[0]) || (e.touches && e.touches[0]) || pendingTouch;

    if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }

    const elapsed = Date.now() - touchStartTime;
    const movedSq = (lastTouchX - (t ? t.clientX : lastTouchX))**2 + (lastTouchY - (t ? t.clientY : lastTouchY))**2;
    const isTap = !isDragging && !movedBeyondLongPress && !isStrokeGesture && (elapsed <= tapTimeThreshold) && (movedSq <= (tapMoveThreshold * tapMoveThreshold));

    if (isDragging) {
      if (t) {
        dispatchAt(t, 'mouseup', 0);
      } else if (lastTarget) {
        lastTarget.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true }));
      }
    } else if (isTap) {
      // Simulate a normal left click at current cursor position
      const el = document.elementFromPoint(cursorX, cursorY) || document.body;
      const clientXY = { clientX: cursorX, clientY: cursorY };
      el.dispatchEvent(createMouseEvent('mousedown', clientXY, 0, 1));
      el.dispatchEvent(createMouseEvent('mouseup', clientXY, 0, 1));
      el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, clientX: clientXY.clientX, clientY: clientXY.clientY }));
      try { if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.haptics) { window.webkit.messageHandlers.haptics.postMessage({ type: 'tap' }); } } catch(_){}
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

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
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
                do {
                    let speedNumber = NSNumber(value: Double(self.parent.cursorSpeed))
                    let data = try JSONSerialization.data(withJSONObject: ["speed": speedNumber], options: [])
                    if let json = String(data: data, encoding: .utf8) {
                        webView.evaluateJavaScript("(function(){ try { var cfg = \(json); if (cfg && typeof cfg.speed === 'number' && isFinite(cfg.speed)) { window.touchMouseCursorSpeed = cfg.speed; } } catch(_){} })();") { _, _ in }
                    }
                } catch {
                    webView.evaluateJavaScript("window.touchMouseCursorSpeed = 1.0;") { _, _ in }
                }
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

