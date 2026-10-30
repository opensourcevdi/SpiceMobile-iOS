//
//  keyboardHelpers.js
//  SpiceMobile
//
//  Created by Lennard Siegel on 30.10.26.
//

function findTarget() {
    var canvas = document.querySelector('canvas');
    if (canvas) return canvas;
    return document.querySelector('#spice-screen, .spice-screen, #display, .noVNC_canvas, #noVNC_canvas') || document.body;
}

function focusTarget(el) {
    try { if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex', '0'); } catch (_) {}
    try { el.focus(); } catch (_) {}
}

function getMods() {
    var m = (typeof window.__iosModifiers === 'object' && window.__iosModifiers) || {};
    return { shift: !!m.shift, ctrl: !!m.ctrl, alt: !!m.alt, meta: !!m.meta };
}

function dispatchKey(el, type, key, code, keyCode, mods, withCharCode) {
    var evt = new KeyboardEvent(type, {
        bubbles: true, cancelable: true, composed: true, key: key, code: code,
        shiftKey: mods.shift, ctrlKey: mods.ctrl, altKey: mods.alt, metaKey: mods.meta
    });
    var props = withCharCode ? ['keyCode', 'which', 'charCode'] : ['keyCode', 'which'];
    props.forEach(function (prop) {
        try { Object.defineProperty(evt, prop, { get: function () { return keyCode; } }); } catch (_) {}
    });
    el.dispatchEvent(evt);
}

var MODIFIER_ORDER = ['shift', 'ctrl', 'alt', 'meta'];
var SPICE_MODIFIERS = { shift: 16, ctrl: 17, alt: 18, meta: 91 };
var VNC_MODIFIERS = { shift: 0xFFE1, ctrl: 0xFFE3, alt: 0xFFE9, meta: 0xFFE7 };

// Modifier drücken, Aktion ausführen, Modifier in umgekehrter Reihenfolge loslassen
function withModifiers(mods, codes, press, release, action) {
    var held = MODIFIER_ORDER.filter(function (name) { return mods[name]; });
    held.forEach(function (name) { try { press(codes[name]); } catch (_) {} });
    action();
    held.reverse().forEach(function (name) { try { release(codes[name]); } catch (_) {} });
}

function withSpiceModifiers(mods, action) {
    var kb = window.SpiceKeyboard;
    withModifiers(mods, SPICE_MODIFIERS,
        function (c) { if (kb.sendKeyDown) kb.sendKeyDown(c); },
        function (c) { if (kb.sendKeyUp) kb.sendKeyUp(c); },
        action);
}

function withVncModifiers(mods, action) {
    var kb = window.rfb._keyboard;
    withModifiers(mods, VNC_MODIFIERS,
        function (s) { kb.keyDown({ keysym: s }); },
        function (s) { kb.keyUp({ keysym: s }); },
        action);
}

function hasVncKeyboard(methods) {
    var kb = window.rfb && window.rfb._keyboard;
    return !!kb && methods.every(function (name) { return typeof kb[name] === 'function'; });
}
