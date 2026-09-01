//
//  ExternalDisplaySceneDelegate.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.09.26.
//

import UIKit
import SwiftUI

final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)

        let hostingController = UIHostingController(
            rootView: ExternalDisplayView()
        )

        window.rootViewController = hostingController
        self.window = window

        window.makeKeyAndVisible()
    }
}


// MARK: - External Display View

struct ExternalDisplayView: View {

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Text("EXTERNAL DISPLAY")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
