//
//  loadJS.swift
//  OSVDIClient
//
//  Created by Lennard Siegel on 17.03.26.
//


import SwiftUI
import WebKit
import UIKit


// load js file and return WKUserScript
func JSLoader(fileName: String) -> WKUserScript  {
    if let path = Bundle.main.path(forResource: fileName, ofType: "js"),
       let jsString = try? String(contentsOfFile: path, encoding: .utf8) {
        let userScript = WKUserScript(
            source: jsString,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        return userScript
    }

    // Fallback: return an empty script so the function always returns a value
    let emptyScript = WKUserScript(
        source: "",
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: false
    )
    return emptyScript
}

