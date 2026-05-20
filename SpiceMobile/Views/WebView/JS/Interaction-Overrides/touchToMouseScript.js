//
//  touchToMouseBridge.js
//  OSVDIClient
//
//  Created by Lennard Siegel on 17.03.26.
//

/*
 touchToMouseBridge.js
 - Converts single-finger touch into cursor/mouse events, supports long-press drag and two-finger right click.
 - Placeholders to be replaced by native before injection:
   __CURSOR_IMAGE_BASE64__
   __DEFAULT_SPEED__
   __DEFAULT_LERP__
*/

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

  // Optional interpolation factor for smoothing cursor motion (0..1)
  if (!('touchMouseLerp' in window)) {
    Object.defineProperty(window, 'touchMouseLerp', {
      configurable: true,
      enumerable: false,
      writable: true,
      value: 0.6
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

  function clampCursorToViewport() {
    var minX = 0;
    var minY = 0;
    var maxX = Math.max(0, window.innerWidth - 1);
    var maxY = Math.max(0, window.innerHeight - 1);
    if (cursorX < minX) cursorX = minX;
    if (cursorY < minY) cursorY = minY;
    if (cursorX > maxX) cursorX = maxX;
    if (cursorY > maxY) cursorY = maxY;
  }

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
  let multiTouchActive = false;

  let twoFingerStartTime = { v: 0 };
  let twoFingerStartX = { v: 0 };
  let twoFingerStartY = { v: 0 };
  let twoFingerMoved = { v: false };
  let twoFingerTimer = { id: null };
  const twoFingerImmediateWindow = 120; // ms
  const twoFingerMoveThreshold = 8; // px radius

  function distanceSq(aX, aY, bX, bY) { const dx = aX - bX; const dy = aY - bY; return dx*dx + dy*dy; }



  function ensureCursor() {
    if (window.__touchMouseCursorDot) return window.__touchMouseCursorDot;
    const img = document.createElement('img');
    img.id = '__touchMouseCursorDot';
      
    // Use base64 provided by native via window.touchMouseCursorBase64
    img.src = (typeof window.touchMouseCursorBase64 === 'string' && window.touchMouseCursorBase64.length > 0)
      ? (window.touchMouseCursorBase64.startsWith('data:') ? window.touchMouseCursorBase64 : ('data:image/png;base64,' + window.touchMouseCursorBase64))
      : 'data:image/png;base64,';
    img.style.position = 'fixed';
   
    // Hotspot of typical Windows cursor is near the top-left corner; offset a bit so the tip is the point
    img.style.marginLeft = '0px';
    img.style.marginTop = '0px';
    img.style.zIndex = '2147483647';
    img.style.pointerEvents = 'none';
    img.style.left = '0px';
    img.style.top = '0px';
    img.style.opacity = '1';
    img.style.transition = 'opacity 0.08s linear';
    document.documentElement.appendChild(img);
    window.__touchMouseCursorDot = img;
    if (!hasCursorPosition) {
      cursorX = parseFloat(img.style.left) || 0;
      cursorY = parseFloat(img.style.top) || 0;
      hasCursorPosition = true;
    }
    return img;
  }


  function showCursorAt(clientX, clientY) {
    const dot = ensureCursor();
    cursorX = clientX;
    cursorY = clientY;
    clampCursorToViewport();
    dot.style.left = cursorX + 'px';
    dot.style.top = cursorY + 'px';
    dot.style.opacity = '1';
    hasCursorPosition = true;
  }

    
  function moveCursorBy(dx, dy) {
    const dot = ensureCursor();
    const speed = (typeof window.touchMouseCursorSpeed === 'number' && isFinite(window.touchMouseCursorSpeed) && window.touchMouseCursorSpeed > 0) ? window.touchMouseCursorSpeed : 1.6;
    const eff = getEffectiveScale(); // visualViewport.scale * touchMousePageZoom
    const sx = (dx * speed) / (eff || 1);
    const sy = (dy * speed) / (eff || 1);
    // Smooth interpolation for more even updates without requiring extra frames
    const lerp = (a, b, t) => a + (b - a) * t;
    const t = (typeof window.touchMouseLerp === 'number' && isFinite(window.touchMouseLerp)) ? Math.max(0, Math.min(1, window.touchMouseLerp)) : 0.35;
    const targetX = cursorX + sx;
    const targetY = cursorY + sy;
    cursorX = lerp(cursorX, targetX, t);
    cursorY = lerp(cursorY, targetY, t);
    clampCursorToViewport();
    dot.style.left = cursorX + 'px';
    dot.style.top = cursorY + 'px';
    dot.style.opacity = '1';
    hasCursorPosition = true;

    // Immediately send the updated cursor position to the native/web bridge (no delay)
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cursor) {
        window.webkit.messageHandlers.cursor.postMessage({ x: cursorX, y: cursorY });
      } else if (typeof window.sendMousePosition === 'function') {
        window.sendMousePosition(cursorX, cursorY);
      }
    } catch (_) {}
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

  function dispatchRightClickAt(clientX, clientY) {
    const el = document.elementFromPoint(clientX, clientY) || document.body;
    const clientXY = { clientX: clientX, clientY: clientY };
    el.dispatchEvent(createMouseEvent('mousedown', clientXY, 2, 1));
    el.dispatchEvent(createMouseEvent('mouseup', clientXY, 2, 1));
    el.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true, clientX: clientXY.clientX, clientY: clientXY.clientY }));
  }

  document.addEventListener('touchstart', function(e){
    if (e.touches.length === 1) {
      multiTouchActive = false;
      onTouchStart(e);
    } else if (e.touches.length > 1) {
      multiTouchActive = true;
      if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
      if (e.touches.length === 2) {
        const t1 = e.touches[0];
        const t2 = e.touches[1];
        twoFingerStartTime.v = Date.now();
        twoFingerStartX.v = (t1.clientX + t2.clientX) / 2;
        twoFingerStartY.v = (t1.clientY + t2.clientY) / 2;
        twoFingerMoved.v = false;
        if (twoFingerTimer.id) { clearTimeout(twoFingerTimer.id); twoFingerTimer.id = null; }
        twoFingerTimer.id = setTimeout(function(){
          // Fire right-click only if still in immediate window and not moved, and still two touches
          try {
            if (twoFingerMoved.v) return;
            // Check if two touches still active
            if (document && typeof document !== 'undefined') {
              // We cannot access e.touches here; rely on multiTouchActive and movement flag
            }
            dispatchRightClickAt(cursorX, cursorY);
            try { if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.haptics) { window.webkit.messageHandlers.haptics.postMessage({ type: 'tap' }); } } catch(_){ }
          } catch(_) { }
          twoFingerTimer.id = null;
        }, twoFingerImmediateWindow);
      }
      e.preventDefault();
    }
  }, { passive: false });

  document.addEventListener('touchmove', function(e){
    if (e.touches.length === 1 && !multiTouchActive) {
      onTouchMove(e);
    } else if (e.touches.length > 1) {
      multiTouchActive = true;
      if (e.touches.length >= 2) {
        const t1 = e.touches[0];
        const t2 = e.touches[1];
        const cx = (t1.clientX + t2.clientX) / 2;
        const cy = (t1.clientY + t2.clientY) / 2;
        const dx = cx - twoFingerStartX.v;
        const dy = cy - twoFingerStartY.v;
        if ((dx*dx + dy*dy) > (twoFingerMoveThreshold * twoFingerMoveThreshold)) {
          twoFingerMoved.v = true;
          if (twoFingerTimer.id) { clearTimeout(twoFingerTimer.id); twoFingerTimer.id = null; }
        }
      }
      e.preventDefault();
        
    }
  }, { passive: false });

  document.addEventListener('touchend', function(e){
    if (multiTouchActive) {
      // Clear any pending immediate right-click; do not dispatch here
      if (twoFingerTimer.id) { clearTimeout(twoFingerTimer.id); twoFingerTimer.id = null; }
      multiTouchActive = false;
      if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
      e.preventDefault();
      return;
    }
    onTouchEnd(e);
  }, { passive: false });

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

    const dot = ensureCursor();
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

})();
