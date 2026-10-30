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
        window.touchMouseLerp = 0.6;
        window.touchMouseScrollSpeed = 2.0;
    } else {
        window.touchMousePageZoom = 1.0;
    }
})();
