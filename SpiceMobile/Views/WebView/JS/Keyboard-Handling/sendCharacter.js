//
//  sendCharacter.js
//  SpiceMobile
//
//  Created by Lennard Siegel on 30.10.26.
//

(function(){
    __KEYBOARD_HELPERS__

    // Taste (DOM-code, US-keyCode) -> Zeichen ohne Modifier, mit Shift, mit AltGr
    var GERMAN_LAYOUT = [
        ['Backquote',    192, '^', '°', ''],
        ['Digit1',        49, '1', '!', ''],
        ['Digit2',        50, '2', '"', '²'],
        ['Digit3',        51, '3', '§', '³'],
        ['Digit4',        52, '4', '$', ''],
        ['Digit5',        53, '5', '%', ''],
        ['Digit6',        54, '6', '&', ''],
        ['Digit7',        55, '7', '/', '{'],
        ['Digit8',        56, '8', '(', '['],
        ['Digit9',        57, '9', ')', ']'],
        ['Digit0',        48, '0', '=', '}'],
        ['Minus',        189, 'ß', '?', '\\'],
        ['Equal',        187, '´', '`', ''],
        ['BracketLeft',  219, 'ü', 'Ü', ''],
        ['BracketRight', 221, '+', '*', '~'],
        ['Backslash',    220, '#', "'", ''],
        ['Semicolon',    186, 'ö', 'Ö', ''],
        ['Quote',        222, 'ä', 'Ä', ''],
        ['Comma',        188, ',', ';', ''],
        ['Period',       190, '.', ':', ''],
        ['Slash',        191, '-', '_', ''],
        ['IntlBackslash',226, '<', '>', '|'],
        ['Space',         32, ' ', ' ', '']
    ];

    // Buchstaben liegen auf der gleichen Taste wie im US-Layout, nur Y und Z sind vertauscht
    'abcdefghijklmnopqrstuvwxyz'.split('').forEach(function (letter) {
        var position = letter === 'y' ? 'Z' : letter === 'z' ? 'Y' : letter.toUpperCase();
        var altGr = letter === 'q' ? '@' : letter === 'e' ? '€' : letter === 'm' ? 'µ' : '';
        GERMAN_LAYOUT.push(['Key' + position, position.charCodeAt(0), letter, letter.toUpperCase(), altGr]);
    });

    // Tote Tasten: erst nach einem folgenden Leerzeichen erscheint das Zeichen
    var DEAD_KEYS = '^´`';

    function keyInfoForCharacter(c) {
        for (var i = 0; i < GERMAN_LAYOUT.length; i++) {
            var row = GERMAN_LAYOUT[i];
            for (var level = 2; level <= 4; level++) {
                if (row[level] === c) {
                    return { code: row[0], keyCode: row[1], shift: level === 3, altGr: level === 4, dead: DEAD_KEYS.indexOf(c) !== -1 };
                }
            }
        }
        return null;
    }

    // Taste samt Shift/AltGr drücken. AltGr wird als Strg+Alt gesendet.
    function tapKey(target, info, mods) {
        var held = [];
        if (info.shift && !mods.shift) held.push(['Shift', 'ShiftLeft', 16]);
        if (info.altGr) held.push(['Control', 'ControlLeft', 17], ['Alt', 'AltLeft', 18]);

        var active = { shift: mods.shift || info.shift, ctrl: mods.ctrl || info.altGr, alt: mods.alt || info.altGr, meta: mods.meta };

        held.forEach(function (m) { dispatchKey(target, 'keydown', m[0], m[1], m[2], active); });
        dispatchKey(target, 'keydown', ch, info.code, info.keyCode, active);
        dispatchKey(target, 'keypress', ch, info.code, ch.charCodeAt(0), active, true);
        dispatchKey(target, 'keyup', ch, info.code, info.keyCode, active);
        held.slice().reverse().forEach(function (m) { dispatchKey(target, 'keyup', m[0], m[1], m[2], mods); });
    }

    var ch = __CHARACTER__;
    var target = findTarget();
    focusTarget(target);
    var mods = getMods();

    var sent = false;
    try {
        var kb = window.SpiceKeyboard;
        if (kb && typeof kb.sendChar === 'function') {
            withSpiceModifiers(mods, function () { kb.sendChar(ch); });
            sent = true;
        }
    } catch (_) {}

    if (!sent) {
        try {
            if (hasVncKeyboard(['keyPress'])) {
                withVncModifiers(mods, function () { window.rfb._keyboard.keyPress(ch); });
                sent = true;
            }
        } catch (_) {}
    }

    if (!sent) {
        var info = keyInfoForCharacter(ch);
        if (info) {
            tapKey(target, info, mods);
            if (info.dead) {
                // Totes Zeichen mit Leerzeichen "abschließen"
                ch = ' ';
                tapKey(target, keyInfoForCharacter(' '), mods);
            }
        }
    }
})();
