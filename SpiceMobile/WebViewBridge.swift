import Foundation
import SwiftUI

/// An observable bridge class to facilitate communication between SwiftUI and an underlying WebView.
/// 
/// This class exposes a published property `lastSentText` that tracks the latest input text sent,
/// useful for debugging and previews. It provides a public method `sendTextInput(_:)` to send text
/// data to the web content, ensuring updates happen on the main thread.
/// 
/// To extend this to communicate with an underlying `WKWebView`, implement the forwarding logic inside
/// `sendTextInput(_:)`, for example by calling `evaluateJavaScript` or posting messages through
/// a message handler.
/// 
/// Example:
/// ```swift
/// webView?.evaluateJavaScript("handleInput('\(text)')", completionHandler: nil)
/// ```
///
/// This class is marked as `@MainActor` to guarantee UI-related publishes happen on the main thread.
@MainActor
final class WebViewBridge: ObservableObject {
    /// The most recent text input sent through this bridge.
    @Published public private(set) var lastSentText: String = ""
    
    /// Sends text input to the underlying web view.
    ///
    /// - Parameter text: The string to send.
    /// 
    /// This method updates the `lastSentText` property and should forward the text to the web view.
    /// Forwarding logic should be added here as needed.
    public func sendTextInput(_ text: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.sendTextInput(text)
            }
            return
        }
        lastSentText = text
        
        // Placeholder for forwarding the text input to the WKWebView:
        // webView?.evaluateJavaScript("handleInput('\(text)')", completionHandler: nil)
    }
}

extension WebViewBridge {
    // Uncomment and import WebKit in this file if you want to keep a direct reference to WKWebView here
    // to forward messages.
    //
    // import WebKit
    //
    // weak var webView: WKWebView?
}
