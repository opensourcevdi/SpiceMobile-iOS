//
//  touchToMouseBridge.js
//  OSVDIClient
//
//  Created by Lennard Siegel on 17.03.26.
//

/*
 touchToMouseBridge.js
 - Converts single-finger touch into relative cursor/mouse events (touchpad style).
 - Tap = left click, long-press = drag, two-finger tap = right click, two-finger move = scroll.
 - Configured at runtime via window properties (see configureTouchBridge.js):
   enableTouchMouseBridge, touchMousePageZoom, touchMouseCursorSpeed (default 1.6),
   touchMouseAcceleration (0 = off, 1 = default), touchMouseScrollSpeed (default 2.0)
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

  function defineOption(name, value) {
    if (name in window) return;
    Object.defineProperty(window, name, {
      configurable: true,
      enumerable: false,
      writable: true,
      value: value
    });
  }

  // Page zoom factor from native
  defineOption('touchMousePageZoom', 1.0);
  // Pointer acceleration strength: 0 = linear, 1 = default curve
  defineOption('touchMouseAcceleration', 1.0);
  // Scroll speed multiplier for two-finger scrolling
  defineOption('touchMouseScrollSpeed', 2.0);

  function numberOption(name, fallback) {
    const v = window[name];
    return (typeof v === 'number' && isFinite(v)) ? v : fallback;
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

  function haptic() {
    try { if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.haptics) { window.webkit.messageHandlers.haptics.postMessage({ type: 'tap' }); } } catch(_) {}
  }

  // Cursor position (page coordinates) and pending, not yet applied movement
  let cursorX = 0;
  let cursorY = 0;
  let pendingDX = 0;
  let pendingDY = 0;
  let rafId = 0;

  function clampCursorToViewport() {
    const maxX = Math.max(0, window.innerWidth - 1);
    const maxY = Math.max(0, window.innerHeight - 1);
    if (cursorX < 0) cursorX = 0;
    if (cursorY < 0) cursorY = 0;
    if (cursorX > maxX) cursorX = maxX;
    if (cursorY > maxY) cursorY = maxY;
  }

  // Tap / long-press / stroke thresholds
  const tapTimeThreshold = 300; // ms
  const tapMoveThreshold = 8; // px, max distance from touch start
  const longPressDelay = 400; // ms
  const longPressRadius = 18; // px
  const twoFingerTapWindow = 300; // ms
  const twoFingerMoveThreshold = 8; // px

  // Single-finger gesture state
  let singleActive = false;
  let startTime = 0;
  let startX = 0;
  let startY = 0;
  let lastTouchX = 0;
  let lastTouchY = 0;
  let lastMoveTime = 0;
  let maxDisplacementSq = 0;
  let longPressTimer = null;
  let isDragging = false;
  let dragTarget = null;

  // Two-finger gesture state
  let multiTouchActive = false;
  let multiStartTime = 0;
  let multiStartX = 0;
  let multiStartY = 0;
  let multiLastX = 0;
  let multiLastY = 0;
  let multiMoved = false;
  let multiMaxTouches = 0;

  // True as soon as touches are fed in from the phone touchpad (controller mode).
  // The coordinates then do not belong to this page, so e.g. scrolling happens at the cursor.
  let remoteInput = false;

  function distanceSq(aX, aY, bX, bY) { const dx = aX - bX; const dy = aY - bY; return dx*dx + dy*dy; }

  function cancelLongPress() {
    if (longPressTimer) { clearTimeout(longPressTimer); longPressTimer = null; }
  }

  function ensureCursor() {
    if (window.__touchMouseCursorDot) return window.__touchMouseCursorDot;
    const img = document.createElement('img');
    img.id = '__touchMouseCursorDot';

    // mouse cursor base64 image
    const base64 = 'iVBORw0KGgoAAAANSUhEUgAAABkAAAAjCAYAAABhCKGoAAAAAXNSR0IArs4c6QAAAIRlWElmTU0AKgAAAAgABQESAAMAAAABAAEAAAEaAAUAAAABAAAASgEbAAUAAAABAAAAUgEoAAMAAAABAAIAAIdpAAQAAAABAAAAWgAAAAAAAADYAAAAAQAAANgAAAABAAOgAQADAAAAAQABAACgAgAEAAAAAQAAABmgAwAEAAAAAQAAACMAAAAA/ltSngAAAAlwSFlzAAAhOAAAITgBRZYxYAAAABxpRE9UAAAAAgAAAAAAAAASAAAAKAAAABIAAAARAAAA6xAOUZoAAAC3SURBVEgN7NCtCsJgFIfx+YGK6B16PyaLxSKCxWIwWAyGBUEQBEEEQRAEwcvQ5x9WZM737D02DzwsjHN+Y0nyn8g/0GN/Qt3IO4XrKW+ftKEO/WR0XIhKqU3us+Vihui5ppa3sntDBK2o6QntcxBBS2p4QYcPiKAF1T2gYwEiaE61WOj0BRE0o2oMdA5ABE1joEsgImhMFTLPlQ0dCG1kFli4GYDsQ4ZW6F4CETawQI+SiKB+HvQCAAD//5d+LDIAAADsSURBVGNgwASvgEL/KcBFmEZiirwlwoLXQDUXgfgBEL8D4j9ADHPYNCCbIHgPVAHTgIt+BFTDjGYSN5AvDsRMaOJYuZ+AouiGz8IiFoxVN5GCX9EMrIXqu4Imvp9I87Aq+4FkGHL45iKJw3yqg9UEIgR/QQ1bC6SRw1cAyEf35QwizMOqZCFQdDUQc2CRnQcUg/kCRH8BYpDlVAVmQNOQLQGxC6lqA9Swc2gW3QbyGaltUTqaJSDfeFHbEh6ggeh5aTO1LQGZNx2IkeMGVN5RHWgATfwJxDCL1lHdBqiB9kB6ERC3ADEfVGyYUwD30+1dzivT0gAAAABJRU5ErkJggg==';

    img.src = 'data:image/png;base64,' + base64;
    img.style.position = 'fixed';
    img.style.marginLeft = '0px';
    img.style.marginTop = '0px';
    img.style.zIndex = '2147483647';
    img.style.pointerEvents = 'none';
    img.style.left = cursorX + 'px';
    img.style.top = cursorY + 'px';
    img.style.opacity = '1';
    img.style.transition = 'opacity 0.08s linear';
    document.documentElement.appendChild(img);
    window.__touchMouseCursorDot = img;
    return img;
  }

  function createWheelEvent(deltaX, deltaY, clientX, clientY){
    let evt;
    try {
      evt = new WheelEvent('wheel', {
        bubbles: true,
        cancelable: true,
        composed: true,
        deltaMode: 0, // pixel
        deltaX: deltaX,
        deltaY: deltaY,
        clientX: clientX,
        clientY: clientY
      });
    } catch (e) {
      evt = document.createEvent('WheelEvent');
      evt.initEvent('wheel', true, true);
      evt.deltaX = deltaX;
      evt.deltaY = deltaY;
      evt.clientX = clientX;
      evt.clientY = clientY;
    }
    return evt;
  }

  function dispatchWheelAt(clientX, clientY, dx, dy){
    const el = document.elementFromPoint(clientX, clientY) || document.body;
    el.dispatchEvent(createWheelEvent(dx, dy, clientX, clientY));
  }

  // Bitmask for MouseEvent.buttons: left = 1, right = 2, middle = 4 (differs from MouseEvent.button)
  const buttonMasks = [1, 4, 2];

  function createMouseEvent(type, x, y, button, pressed, detail) {
    return new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      view: window,
      clientX: x,
      clientY: y,
      screenX: 0,
      screenY: 0,
      button: button,
      buttons: pressed ? (buttonMasks[button] || 0) : 0,
      detail: detail
    });
  }

  function elementAtCursor() {
    return document.elementFromPoint(cursorX, cursorY) || document.body;
  }

  // Pointer acceleration: slow movements are more precise, fast movements cover more distance
  function cursorGain(distance, dt) {
    const base = (typeof window.touchMouseCursorSpeed === 'number' && isFinite(window.touchMouseCursorSpeed) && window.touchMouseCursorSpeed > 0) ? window.touchMouseCursorSpeed : 1.6;
    const accel = numberOption('touchMouseAcceleration', 1);
    if (accel <= 0 || dt <= 0) return base;
    const velocity = distance / dt; // px/ms
    const factor = Math.min(2.2, 0.7 + 0.5 * velocity);
    return base * (1 + (factor - 1) * accel);
  }

  // Applies all movement collected since the last frame in one step
  function flushCursor() {
    if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
    if (pendingDX === 0 && pendingDY === 0) return;
    const dot = ensureCursor();
    cursorX += pendingDX;
    cursorY += pendingDY;
    pendingDX = 0;
    pendingDY = 0;
    clampCursorToViewport();
    dot.style.left = cursorX + 'px';
    dot.style.top = cursorY + 'px';
    dot.style.opacity = '1';

    // Send the updated cursor position to the native/web bridge
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cursor) {
        window.webkit.messageHandlers.cursor.postMessage({ x: cursorX, y: cursorY });
      } else if (typeof window.sendMousePosition === 'function') {
        window.sendMousePosition(cursorX, cursorY);
      }
    } catch (_) {}

    // Keep page logic in sync; while dragging the events stay on the element where the drag began
    const el = (isDragging && dragTarget) ? dragTarget : elementAtCursor();
    el.dispatchEvent(createMouseEvent('mousemove', cursorX, cursorY, 0, isDragging, 0));
  }

  function queueCursorMove(dx, dy, dt) {
    const eff = getEffectiveScale() || 1;
    const gain = cursorGain(Math.sqrt(dx*dx + dy*dy), dt);
    pendingDX += (dx * gain) / eff;
    pendingDY += (dy * gain) / eff;
    if (!rafId) {
      rafId = requestAnimationFrame(function() { rafId = 0; flushCursor(); });
    }
  }

  function startDrag() {
    flushCursor();
    isDragging = true;
    dragTarget = elementAtCursor();
    dragTarget.dispatchEvent(createMouseEvent('mousedown', cursorX, cursorY, 0, true, 1));
    haptic();
  }

  function releaseDrag() {
    if (!isDragging) return;
    flushCursor();
    const el = dragTarget || elementAtCursor();
    el.dispatchEvent(createMouseEvent('mouseup', cursorX, cursorY, 0, false, 1));
    isDragging = false;
    dragTarget = null;
  }

  function dispatchLeftClick() {
    const el = elementAtCursor();
    el.dispatchEvent(createMouseEvent('mousedown', cursorX, cursorY, 0, true, 1));
    el.dispatchEvent(createMouseEvent('mouseup', cursorX, cursorY, 0, false, 1));
    el.dispatchEvent(createMouseEvent('click', cursorX, cursorY, 0, false, 1));
  }

  function dispatchRightClick() {
    const el = elementAtCursor();
    el.dispatchEvent(createMouseEvent('mousedown', cursorX, cursorY, 2, true, 1));
    el.dispatchEvent(createMouseEvent('mouseup', cursorX, cursorY, 2, false, 1));
    el.dispatchEvent(createMouseEvent('contextmenu', cursorX, cursorY, 2, false, 0));
  }

  function handleTouchStart(e){
    // Bei deaktivierter Brücke bleiben Touches unangetastet
    if (!window.enableTouchMouseBridge) return;
    const count = e.touches.length;
    if (count === 1 && !multiTouchActive) {
      onTouchStart(e);
      return;
    }
    if (count < 2) return;

    if (!multiTouchActive) {
      // A second finger joined: abort whatever the single finger was doing, without a click
      multiTouchActive = true;
      singleActive = false;
      cancelLongPress();
      releaseDrag();
      const t1 = e.touches[0];
      const t2 = e.touches[1];
      multiStartTime = Date.now();
      multiStartX = (t1.clientX + t2.clientX) / 2;
      multiStartY = (t1.clientY + t2.clientY) / 2;
      multiLastX = multiStartX;
      multiLastY = multiStartY;
      multiMoved = false;
      multiMaxTouches = 0;
    }
    multiMaxTouches = Math.max(multiMaxTouches, count);
    e.preventDefault();
  }

  function handleTouchMove(e){
    if (multiTouchActive) {
      if (e.touches.length >= 2) {
        const t1 = e.touches[0];
        const t2 = e.touches[1];
        const cx = (t1.clientX + t2.clientX) / 2;
        const cy = (t1.clientY + t2.clientY) / 2;
        if (!multiMoved && distanceSq(cx, cy, multiStartX, multiStartY) > (twoFingerMoveThreshold * twoFingerMoveThreshold)) {
          multiMoved = true;
        }
        // Two-finger scroll starts once the fingers moved clearly, so a tap never scrolls
        if (multiMoved) {
          const eff = getEffectiveScale() || 1;
          const scrollSpeed = numberOption('touchMouseScrollSpeed', 2.0);
          const pxDX = -(cx - multiLastX) * scrollSpeed / eff;
          const pxDY = -(cy - multiLastY) * scrollSpeed / eff;
          multiLastX = cx;
          multiLastY = cy;
          if (Math.abs(pxDX) + Math.abs(pxDY) > 0) {
            flushCursor();
            dispatchWheelAt(remoteInput ? cursorX : cx, remoteInput ? cursorY : cy, pxDX, pxDY);
          }
        }
      }
      e.preventDefault();
      return;
    }
    if (e.touches.length === 1) {
      onTouchMove(e);
    }
  }

  function handleTouchEnd(e, cancelled){
    if (multiTouchActive) {
      // The gesture ends only when all fingers are up; remaining fingers are ignored to avoid cursor jumps
      if (e.touches.length === 0 || cancelled) {
        const isTwoFingerTap = !cancelled && !multiMoved && multiMaxTouches === 2 && (Date.now() - multiStartTime) <= twoFingerTapWindow;
        multiTouchActive = false;
        if (isTwoFingerTap) {
          flushCursor();
          dispatchRightClick();
          haptic();
        }
      }
      e.preventDefault();
      return;
    }
    onTouchEnd(e, cancelled);
  }

  // Real touches on this page: coordinates are local
  document.addEventListener('touchstart', function(e) { remoteInput = false; handleTouchStart(e); }, { passive: false });
  document.addEventListener('touchmove', function(e) { remoteInput = false; handleTouchMove(e); }, { passive: false });
  document.addEventListener('touchend', function(e) { remoteInput = false; handleTouchEnd(e, false); }, { passive: false });
  document.addEventListener('touchcancel', function(e) { remoteInput = false; handleTouchEnd(e, true); }, { passive: false });

  // Entry point for the native touchpad: points are [x, y] pairs of the active resp. changed fingers.
  window.__touchBridgeInject = function(type, touches, changed) {
    remoteInput = true;
    const toTouches = function(points) { return points.map(function(p) { return { clientX: p[0], clientY: p[1] }; }); };
    const event = { touches: toTouches(touches), changedTouches: toTouches(changed), preventDefault: function() {} };
    if (type === 'touchstart') handleTouchStart(event);
    else if (type === 'touchmove') handleTouchMove(event);
    else if (type === 'touchend') handleTouchEnd(event, false);
    else if (type === 'touchcancel') handleTouchEnd(event, true);
  };

  function onTouchStart(e) {
    if (!window.enableTouchMouseBridge) return;
    const t = e.touches[0];
    e.preventDefault();

    // Safety net: never leave a previous drag pressed
    cancelLongPress();
    releaseDrag();

    singleActive = true;
    startTime = Date.now();
    startX = t.clientX;
    startY = t.clientY;
    lastTouchX = t.clientX;
    lastTouchY = t.clientY;
    lastMoveTime = performance.now();
    maxDisplacementSq = 0;

    ensureCursor().style.opacity = '1';

    // Long-press starts dragging at the current cursor position
    longPressTimer = setTimeout(function(){
      longPressTimer = null;
      if (!singleActive || isDragging) return;
      if (maxDisplacementSq > (longPressRadius * longPressRadius)) return;
      startDrag();
    }, longPressDelay);
  }

  function onTouchMove(e) {
    if (!window.enableTouchMouseBridge || !singleActive) return;
    const t = e.touches[0];
    e.preventDefault();

    const dx = t.clientX - lastTouchX;
    const dy = t.clientY - lastTouchY;
    lastTouchX = t.clientX;
    lastTouchY = t.clientY;

    // Distance from the touch start decides between tap/long-press and a real movement
    maxDisplacementSq = Math.max(maxDisplacementSq, distanceSq(t.clientX, t.clientY, startX, startY));

    const now = performance.now();
    const dt = Math.max(4, now - lastMoveTime);
    lastMoveTime = now;
    queueCursorMove(dx, dy, dt);
  }

  function onTouchEnd(e, cancelled) {
    if (!window.enableTouchMouseBridge) return;
    e.preventDefault();
    cancelLongPress();
    if (!singleActive) return;
    singleActive = false;

    flushCursor();

    if (isDragging) {
      releaseDrag();
      return;
    }

    const elapsed = Date.now() - startTime;
    const isTap = !cancelled && elapsed <= tapTimeThreshold && maxDisplacementSq <= (tapMoveThreshold * tapMoveThreshold);
    if (isTap) {
      dispatchLeftClick();
      haptic();
    }
  }

})();
