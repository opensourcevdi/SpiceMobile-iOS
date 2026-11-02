//
//  configureTouchBridge.js
//  OSVDIClient
//
//  Created by Lennard Siegel on 30.10.26.
//


(function(){
    var enabled = __ENABLED__;
    window.enableTouchMouseBridge = enabled;

    if (enabled) {
        window.touchMousePageZoom = __PAGE_ZOOM__;
        window.touchMouseCursorSpeed = __CURSOR_SPEED__;
        window.touchMouseAcceleration = 1.0;
        window.touchMouseScrollSpeed = 2.0;
    } else {
        window.touchMousePageZoom = 1.0;
    }

    // Cursor-Punkt nur sichtbar, solange die Brücke aktiv ist
    var dot = window.__touchMouseCursorDot;
    if (dot) dot.style.display = enabled ? '' : 'none';
})();
