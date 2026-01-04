//
//  ContentView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import CoreData

// MARK: - ContentView
struct ContentView: View {
    @State private var isLoading: Bool = true
    @State private var shouldForceLandscape: Bool = false
    
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            
            // Feste Desktop-Zielauflösung
            let targetWidth: CGFloat = 1000
            let targetHeight: CGFloat = 562.5 // 16:9
            
            // Nach Rotation: Desktop-Höhe (targetHeight) wird zur Breite, Desktop-Breite (targetWidth) wird zur Höhe
            let horizontalScale = size.width / targetHeight
            let verticalScale = size.height / targetWidth
            let scale = shouldForceLandscape ? min(horizontalScale, verticalScale) : 1
            
            ZStack {
                WebView(urlString: "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape)
                    .background(Color.clear)
                    .opacity(isLoading ? 0 : 1)
                // Nur im Landscape-Force-Modus in Desktop-Auflösung rendern
                    .frame(width: shouldForceLandscape ? targetWidth : nil,
                           height: shouldForceLandscape ? targetHeight : nil)
                    .rotationEffect(.degrees(shouldForceLandscape ? 90 : 0))
                    .scaleEffect(shouldForceLandscape ? scale : 1, anchor: .center)
                    .frame(width: size.width, height: size.height)
                    .position(x: size.width / 2, y: size.height / 2)
                
                
                if isLoading {
                    
                    // Simple loading overlay
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("Loading…")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.opacity)
                    
                }
            }

        }
        
    }
    
}


private struct ConditionalPosition: ViewModifier {
    let centerWhen: Bool
    let size: CGSize
    func body(content: Content) -> some View {
        if centerWhen {
            content.position(x: size.width / 2, y: size.height / 2)
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
}

