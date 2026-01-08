//
//  ContentView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI

// MARK: - ContentView
struct ContentView: View {
    @State private var isLoading: Bool = true
    @State private var shouldForceLandscape: Bool = false
    @State private var cumulativeScale: CGFloat = 1.0
    @State private var transientScale: CGFloat = 1.0
    @State private var isPinching: Bool = false
    
    @State private var overlayExpanded: Bool = false
    @FocusState private var keyboardFocus: Bool
    @State private var hiddenInput: String = ""
    
    @State private var currentURL: URL? = nil
    @State private var requestedURL: URL? = nil
    private var isOnAuthURL: Bool {
        guard let urlString = currentURL?.absoluteString else { return false }
        return urlString.hasPrefix("https://auth.dev.escience.uni-freiburg.de/realms/osvdi/protocol/openid-connect/")
    }

    var body: some View {
        
        ZStack {
            Color.black.ignoresSafeArea()
            ZStack {
                WebView(urlString: "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape, currentURL: $currentURL, requestedURL: $requestedURL)
                    .background(Color.clear)
                    .opacity(isLoading ? 0 : 1)
                    .allowsHitTesting(!isPinching)
                    .clipped()
                    .highPriorityGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                withTransaction(Transaction(animation: nil)) {
                                    if !isPinching { isPinching = true }
                                    let proposed = value * cumulativeScale
                                    transientScale = min(max(proposed, 0.5), 1.0) / cumulativeScale
                                }
                            }
                            .onEnded { value in
                                withTransaction(Transaction(animation: nil)) {
                                    let proposed = value * cumulativeScale
                                    cumulativeScale = min(max(proposed, 0.5), 1.0)
                                    transientScale = 1.0
                                    isPinching = false
                                }
                            }
                    )
            }
            .scaleEffect((cumulativeScale * transientScale), anchor: .center)


            // Hidden TextField to trigger keyboard on demand
            TextField("", text: $hiddenInput)
                .focused($keyboardFocus)
                .keyboardType(.alphabet)
                .autocorrectionDisabled()
                .frame(width: 0, height: 0)
                .opacity(0.01)
                .disabled(false)
                .allowsHitTesting(false)

            if !isOnAuthURL {
                // Overlay controls (top-right)
                VStack {
                    
                    
                    if shouldForceLandscape {
                        HStack {
                            
                            HStack(spacing: 8) {
                                
                                
                                Button {
                                    // Navigate to home when arrow is pressed
                                    requestedURL = URL(string: "https://demo.osvdi.uni-freiburg.de")
                                } label: {
                                    Image(systemName: "chevron.backward.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .symbolRenderingMode(.hierarchical)
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                            
                            
                            .padding(.top, 24)
                            .padding(.leading, 24)
                            
                            Spacer()
                            HStack(spacing: 8) {
                                
                                
                                if overlayExpanded {
                                    // Keyboard button
                                    Button {
                                        if keyboardFocus {keyboardFocus = false} else {keyboardFocus = true}
                                    } label: {
                                        Image(systemName: "keyboard.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .symbolRenderingMode(.hierarchical)
                                            .padding(10)
                                            .background(.ultraThinMaterial, in: Capsule())
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                                
                                
                                // Arrow toggle button
                                Button {
                                    
                                    withAnimation(.snappy) {
                                        overlayExpanded.toggle()
                                        if !overlayExpanded { keyboardFocus = false }
                                    }
                                } label: {
                                    Image(systemName: overlayExpanded ? "minus.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .symbolRenderingMode(.hierarchical)
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                
                            }
                        }
                        .padding(.top, 24)
                        .padding(.trailing, 24)
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
            }

            if isLoading {
                ProgressView("Loading…")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.opacity)
            }
        }

        .ignoresSafeArea()
    }
    
}

#Preview {
    ContentView()
}
