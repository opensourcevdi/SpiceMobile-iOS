//
//  fileUplaod.js
//  SpiceMobile
//
//  Created by Lennard Siegel on 31.07.26.
//

(function(){
    function b64ToUint8Array(b64){
        const bin = atob(b64);
        const len = bin.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i);
        return bytes;
    }

    // Build File[] from descriptor array
    var filesData = __SWIFT_VALUE__;
    var fileObjs = filesData.map(function(f){
        var bytes = b64ToUint8Array(f.base64);
        var blob = new Blob([bytes], {type: f.mime});
        return new File([blob], f.name, {type: f.mime});
    });

    // 1) Explicit integration hook
    if (typeof window.receiveNativeFiles === 'function') {
        try { window.receiveNativeFiles(fileObjs); return; } catch(_){}
    }

    // 2) Try to find a reasonable drop target commonly used by SPICE/VNC UIs
    function findPrimaryTarget(){
        var selectors = [
            'canvas',
            '#spice-screen', '.spice-screen',
            '#display',
            '.noVNC_canvas', '#noVNC_canvas', 'canvas#noVNC_canvas',
            '[data-drop-zone]', '.dropzone', '#dropzone'
        ];
        for (var i = 0; i < selectors.length; i++){
            var el = document.querySelector(selectors[i]);
            if (el) return el;
        }
        return document.body;
    }

    var target = findPrimaryTarget();

    // 3) Create a DataTransfer and attach Files
    var dataTransfer = new DataTransfer();
    fileObjs.forEach(function(file){ dataTransfer.items.add(file); });

    // 4) Helper to create proper DragEvent with dataTransfer
    function createDragEvent(type, dt){
        var evt;
        try {
            evt = new DragEvent(type, {
                bubbles: true,
                cancelable: true,
                composed: true,
                dataTransfer: dt
            });
        } catch (e) {
            // Safari fallback: construct then assign
            evt = document.createEvent('DragEvent');
            evt.initEvent(type, true, true);
            try { Object.defineProperty(evt, 'dataTransfer', { value: dt }); } catch(_){ evt.dataTransfer = dt; }
        }
        return evt;
    }

    function dispatchDragSequence(el, dt){
        var enter = createDragEvent('dragenter', dt);
        var over  = createDragEvent('dragover', dt);
        var drop  = createDragEvent('drop', dt);
        el.dispatchEvent(enter);
        el.dispatchEvent(over);
        el.dispatchEvent(drop);
    }

    // 5) Give the page a tick to attach listeners if needed, then dispatch
    requestAnimationFrame(function(){
        try { dispatchDragSequence(target, dataTransfer); } catch(_){ }
    });

    // 6) Fallback: try a visible file input (cannot set files programmatically for security, but we can at least click)
    var fileInput = document.querySelector('input[type=file]:not([disabled])');
    if (fileInput && typeof fileInput.click === 'function') {
        try { fileInput.focus(); fileInput.click(); } catch(_){ }
    }
})();
