//
//  loadJS.swift
//  OSVDIClient
//
//  Created by Lennard Siegel on 17.03.26.
//


import SwiftUI
import WebKit

// Load JS file and return WKUserScript
func JSLoader(fileName: String, swiftVar: String? = nil) -> WKUserScript {
    
    if let path = Bundle.main.path(forResource: fileName, ofType: "js"),
       var jsString = try? String(contentsOfFile: path, encoding: .utf8) {
        
        // Optional replacement
           if let swiftVar = swiftVar {
            jsString = jsString.replacingOccurrences(
                of: "__SWIFT_VALUE__",
                with: swiftVar
            )
        }
        
        return WKUserScript(
            source: jsString,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }

    // Fallback
    return WKUserScript(
        source: "",
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: false
    )
}
