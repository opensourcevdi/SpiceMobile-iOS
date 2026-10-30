//
//  disableUserScalable.js
//  OSVDIClient
//
//  Created by Lennard Siegel on 30.10.26.
//

(function(){
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'user-scalable=no';
    document.getElementsByTagName('head')[0].appendChild(meta);
})();
