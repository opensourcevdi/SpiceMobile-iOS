//
//  SpiceMobileApp.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import CoreData
import UIKit


// main
@main
struct SpiceMobileClient: App {
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
                .preferredColorScheme(.dark)

        }
    }
}

