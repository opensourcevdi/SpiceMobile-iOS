//
//  TouchpadView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 02.11.26.
//

import SwiftUI
import UIKit

/// Touchpad für den Controller-Modus: Die VM läuft auf dem externen Display, die Touches auf dem
/// Handy werden an die Touch-zu-Maus-Brücke der WebView weitergereicht (Tap, Long-Press-Drag,
/// Zwei-Finger-Rechtsklick und -Scrollen).
struct TouchpadView: UIViewRepresentable {

    func makeUIView(context: Context) -> TouchpadUIView {
        TouchpadUIView()
    }

    func updateUIView(_ uiView: TouchpadUIView, context: Context) {}
}

final class TouchpadUIView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        send("touchstart", changed: touches, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        send("touchmove", changed: touches, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        send("touchend", changed: touches, event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        send("touchcancel", changed: touches, event: event)
    }

    /// `touches` enthält wie im DOM nur die noch aufliegenden Finger, `changed` die betroffenen.
    private func send(_ type: String, changed: Set<UITouch>, event: UIEvent?) {
        let active = (event?.allTouches ?? changed).filter { $0.phase != .ended && $0.phase != .cancelled }

        NotificationCenter.default.post(
            name: .webViewInjectTouch,
            object: nil,
            userInfo: [
                "type": type,
                "touches": active.map(points),
                "changed": changed.map(points)
            ]
        )
    }

    private func points(of touch: UITouch) -> [Double] {
        let location = touch.location(in: self)
        return [Double(location.x), Double(location.y)]
    }
}
