//
//  disableInteractions.js
//  OSVDIClient
//
//  Created by Lennard Siegel on 17.03.26.
//



/*
 disableInteractions.js
 - Disables selection, context menu, gestures, and drag & drop. Observes DOM changes to re-apply.
*/


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
