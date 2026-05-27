//
//  sendEnter.js
//  SpiceMobile
//
//  Created by Lennard Siegel on 25.05.26.
//

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
  function dispatchKey(el, type, key, code, keyCode){
    var evt = new KeyboardEvent(type, { bubbles: true, cancelable: true, key: key, code: code, composed: true });
    try { Object.defineProperty(evt, 'keyCode', { get: function(){ return keyCode; } }); } catch(_){ }
    try { Object.defineProperty(evt, 'which', { get: function(){ return keyCode; } }); } catch(_){ }
    try { Object.defineProperty(evt, 'charCode', { get: function(){ return keyCode; } }); } catch(_){ }
    el.dispatchEvent(evt);
  }
  function sendViaSpiceAPIKey(key){
    try { if (window.SpiceKeyboard && typeof window.SpiceKeyboard.sendKey === 'function') { window.SpiceKeyboard.sendKey(key); return true; } } catch(_) {}
    try { if (window.rfb && window.rfb._keyboard && typeof window.rfb._keyboard.keyPress === 'function') { window.rfb._keyboard.keyPress(key); return true; } } catch(_) {}
    return false;
  }
  var target = findSpiceTarget();
  focusTarget(target);
  var key = 'Enter';
  var code = 'Enter';
  var keyCode = 13;
  dispatchKey(target, 'keydown', key, code, keyCode);
  dispatchKey(target, 'keyup', key, code, keyCode);
  sendViaSpiceAPIKey(key);
})();
