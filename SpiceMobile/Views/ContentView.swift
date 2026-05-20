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
    
    @State private var isOverlayExpanded: Bool = false
    @AppStorage("isTouchMode") private var isTouchMode: Bool = true
    @FocusState private var keyboardFocus: Bool
    @State private var hiddenInput: String = ""
    @State private var typingBuffer: String = ""
    @State private var webViewID = UUID()  // jede Änderung erzeugt neue WebView
    
    
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
                
                
                WebView(urlString: currentURL?.absoluteString ?? "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape, currentURL: $currentURL, requestedURL: $requestedURL, typingBuffer: $typingBuffer)
                    .background(Color.clear)
                    .opacity(isLoading ? 0 : 1)
                    .allowsHitTesting(!(isPinching && shouldForceLandscape))
                    .clipped()
                    .id(webViewID) // SwiftUI baut neue WebView, wenn id sich ändert
                    .onChange(of: isTouchMode) { _, _ in
                        // Force rebuild bei TouchMode-Update
                        webViewID = UUID()
                    }
                  
                    .highPriorityGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if !shouldForceLandscape {
                                    // Ignore pinch updates when not in landscape
                                    return
                                }
                                withTransaction(Transaction(animation: nil)) {
                                    if !isPinching { isPinching = true }
                                    let proposed = value * cumulativeScale
                                    transientScale = min(max(proposed, 0.5), 1.0) / cumulativeScale
                                }
                            }
                            .onEnded { value in
                                if !shouldForceLandscape {
                                    // Reset transient pinch state if any and ignore end when not in landscape
                                    withTransaction(Transaction(animation: nil)) {
                                        transientScale = 1.0
                                        isPinching = false
                                    }
                                    return
                                }
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
            EnhancedTextField(placeholder: "", text: $typingBuffer, onBackspace: { isEmpty in
                NotificationCenter.default.post(name: .WebViewSendBackspace, object: nil)
                
            }, onReturn: {
                // handle Enter/Return here
                NotificationCenter.default.post(name: .WebViewSendEnter, object: nil)
            })
            .focused($keyboardFocus)
            .textInputAutocapitalization(.never)
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
                                    keyboardFocus = false
                                    withAnimation(.snappy) {
                                        isOverlayExpanded = false
                                    }
                                    
                                } label: {
                                    Image(systemName: "chevron.backward.circle.fill")
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .scaleEffect(0.9)
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
                                
                                
                                if isOverlayExpanded {
                                    
                                    // touch-mode button
                                    Button {
                                        isTouchMode.toggle()
                                        
                                    } label: {
                                        Image(systemName: "hand.tap.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                            .scaleEffect(0.9)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .symbolRenderingMode(.hierarchical)
                                            .padding(10)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .opacity(isTouchMode ? 1.0 : 0.6)
                                            .disabled(!isTouchMode)
                                        
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                    
                                    // Keyboard button
                                    Button {
                                        keyboardFocus.toggle()
                                    } label: {
                                        Image(systemName: "keyboard.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                            .scaleEffect(0.9)
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
                                        if isOverlayExpanded { keyboardFocus = false }
                                        isOverlayExpanded.toggle()
                                    }
                                } label: {
                                    Image(systemName: isOverlayExpanded ? "minus.circle.fill" : "plus.circle.fill")
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .scaleEffect(0.9)
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
