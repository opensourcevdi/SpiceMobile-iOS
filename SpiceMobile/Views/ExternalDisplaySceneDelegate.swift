//
//  ExternalDisplaySceneDelegate.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.09.26.
//

import UIKit
import SwiftUI

// MARK: - External Display Manager

/// Verwaltet den externen Bildschirm. Solange einer verbunden ist, steht dessen Host-View bereit,
/// in die die WebView (VM-Anzeige) verschoben werden kann.
@MainActor
@Observable
final class ExternalDisplayManager {

    static let shared = ExternalDisplayManager()

    private(set) var isConnected = false
    @ObservationIgnored private(set) weak var hostView: UIView?

    private init() {}

    func connect(hostView: UIView) {
        self.hostView = hostView
        isConnected = true
    }

    func disconnect() {
        hostView = nil
        isConnected = false
    }
}

// MARK: - Scene Accessory (iOS 27+)

/// Registriert ab iOS 27 das Scene Accessory, ohne das keine externe Scene mehr geliefert wird.
/// Das Accessory ist nur aktiv, solange `isEnabled` gesetzt ist; sonst bleibt das normale Mirroring.
struct ExternalDisplayAccessoryModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.sceneAccessory {
                ExternalNonInteractiveAccessory(isEnabled: .constant(isEnabled)) {
                    ExternalDisplayHostView()
                        .ignoresSafeArea()
                }
                .onAvailabilityChange { isAvailable in
                    print("[ExternalDisplay] accessory available: \(isAvailable)")
                }
            }
        } else {
            content
        }
    }
}

// Inhalt des Accessories: eine schwarze Host-View, in die die WebView verschoben wird.
private struct ExternalDisplayHostView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        print("[ExternalDisplay] accessory content created")
        let view = UIView()
        view.backgroundColor = .black
        DispatchQueue.main.async {
            ExternalDisplayManager.shared.connect(hostView: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        ExternalDisplayManager.shared.disconnect()
    }
}

// MARK: - Scene Delegate (iOS 26 und älter)

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        print("[ExternalDisplay] willConnectTo: \(scene)")

        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)

        let viewController = UIViewController()
        viewController.view.backgroundColor = .black

        window.rootViewController = viewController
        self.window = window

        window.makeKeyAndVisible()

        ExternalDisplayManager.shared.connect(hostView: viewController.view)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        ExternalDisplayManager.shared.disconnect()
        window = nil
    }
}
