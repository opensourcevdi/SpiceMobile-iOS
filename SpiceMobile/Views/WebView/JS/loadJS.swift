//
//  loadJS.swift
//  OSVDIClient
//
//  Created by Lennard Siegel on 17.03.26.
//


import SwiftUI
import WebKit

/// Lädt eine JS-Datei aus dem Bundle und gibt sie als WKUserScript zurück.
///
/// - Parameters:
///   - swiftVar: ersetzt den Platzhalter `__SWIFT_VALUE__`.
///   - variables: ersetzt beliebige weitere Platzhalter (z. B. `["__KEY_CODE__": "13"]`).
func JSLoader(fileName: String,
              swiftVar: String? = nil,
              variables: [String: String] = [:],
              forMainFrameOnly: Bool = false) -> WKUserScript {

    guard let path = Bundle.main.path(forResource: fileName, ofType: "js"),
          var jsString = try? String(contentsOfFile: path, encoding: .utf8) else {
        assertionFailure("JS-Datei \(fileName).js nicht im Bundle gefunden")
        return WKUserScript(source: "", injectionTime: .atDocumentEnd, forMainFrameOnly: forMainFrameOnly)
    }

    if let swiftVar {
        jsString = jsString.replacingOccurrences(of: "__SWIFT_VALUE__", with: swiftVar)
    }
    for (placeholder, value) in variables {
        jsString = jsString.replacingOccurrences(of: placeholder, with: value)
    }

    return WKUserScript(source: jsString, injectionTime: .atDocumentEnd, forMainFrameOnly: forMainFrameOnly)
}
