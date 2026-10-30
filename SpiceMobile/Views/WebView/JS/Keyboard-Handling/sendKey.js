//
//  sendKey.js
//  SpiceMobile
//
//  Created by Lennard Siegel on 30.10.26.
//

(function(){
    __KEYBOARD_HELPERS__

    var spec = {
        spiceCode: __SPICE_CODE__,
        vncKeysym: __VNC_KEYSYM__,
        key: '__KEY__',
        code: '__CODE__',
        keyCode: __KEY_CODE__,
        usesSpiceKeyCode: __USES_SPICE_KEYCODE__,
        ignoresMeta: __IGNORES_META__
    };

    var target = findTarget();
    focusTarget(target);
    var mods = getMods();
    if (spec.ignoresMeta) mods.meta = false;

    var sent = false;
    try {
        var kb = window.SpiceKeyboard;
        var supported = kb && (spec.usesSpiceKeyCode ? typeof kb.sendKeyCode === 'function' : (kb.sendKeyDown || kb.sendKeyUp));
        if (supported) {
            withSpiceModifiers(mods, function () {
                if (spec.usesSpiceKeyCode) {
                    kb.sendKeyCode(spec.spiceCode);
                } else {
                    if (kb.sendKeyDown) kb.sendKeyDown(spec.spiceCode);
                    if (kb.sendKeyUp) kb.sendKeyUp(spec.spiceCode);
                }
            });
            sent = true;
        }
    } catch (_) {}

    if (!sent) {
        try {
            if (hasVncKeyboard(['keyDown', 'keyUp'])) {
                withVncModifiers(mods, function () {
                    window.rfb._keyboard.keyDown({ keysym: spec.vncKeysym });
                    window.rfb._keyboard.keyUp({ keysym: spec.vncKeysym });
                });
                sent = true;
            }
        } catch (_) {}
    }

    if (!sent) {
        dispatchKey(target, 'keydown', spec.key, spec.code, spec.keyCode, mods);
        dispatchKey(target, 'keyup', spec.key, spec.code, spec.keyCode, mods);
    }
})();
