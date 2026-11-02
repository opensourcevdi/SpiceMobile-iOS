//
//  SpiceMobileApp.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import CoreData
import UIKit


// MARK: - App Delegate

/// Liefert die Scene-Konfiguration für das externe Display explizit (zusätzlich zur Info.plist).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        print("[ExternalDisplay] Scene requested, role: \(connectingSceneSession.role.rawValue)")

        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        // Bis iOS 26 wird die externe Scene automatisch angeboten; ab iOS 27 nur über ein Scene Accessory
        // (siehe ExternalDisplayAccessoryModifier), das seinen Inhalt selbst mitbringt.
        if #unavailable(iOS 27), connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
        }
        return configuration
    }
}

// main
@main
struct SpiceMobileClient: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @AppStorage("cursorSpeed") private var cursorSpeed: Double = 2.0
    @AppStorage("hasInitializedCursorSpeed") private var hasInitializedCursorSpeed: Bool = false

    // let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    if !hasInitializedCursorSpeed {
                        #if os(iOS)
                        let isPad = UIDevice.current.userInterfaceIdiom == .pad
                        cursorSpeed = isPad ? 6.0 : 2.0
                        #else
                        cursorSpeed = 2.0
                        #endif
                        hasInitializedCursorSpeed = true
                    }
                }
                .preferredColorScheme(.light)

        }
    }
}

