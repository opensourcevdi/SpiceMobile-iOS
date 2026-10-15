//
//  VMView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import UniformTypeIdentifiers
import Network
import Combine

// MARK: - ContentView
struct VMView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var networkMonitor = NetworkMonitor()

    // MARK: WebView content
    @State private var isLoading: Bool = true
    @State private var shouldForceLandscape: Bool = false
    @State private var webViewID = UUID()  // Changing this forces SwiftUI to rebuild the WebView
    @State private var currentURL: URL? = nil
    @State private var requestedURL: URL? = nil
    @State private var typingBuffer: String = ""

    // MARK: Pinch-to-zoom / pan (gesture is currently disabled below, state kept for the scaleEffect/offset modifiers)
    @State private var cumulativeScale: CGFloat = 1.0
    @State private var transientScale: CGFloat = 1.0
    @State private var isPinching: Bool = false
    @State private var contentOffset: CGSize = .zero
    @State private var transientOffset: CGSize = .zero

    // MARK: Overlay control bar (settings / touch mode / file / keyboard / expand toggle)
    // Dragged independently from the home button via its own position/gesture state.
    @State private var isOverlayExpanded: Bool = false
    @State private var controlBarPosition: CGSize = .zero
    @State private var controlBarStartPosition: CGSize = .zero
    @State private var isDraggingControlBar: Bool = false

    // MARK: Home button
    // Dragged independently from the control bar via its own position/gesture state.
    @State private var homePosition: CGSize = .zero
    @State private var homeStartPosition: CGSize = .zero
    @State private var isDraggingHome: Bool = false

    // MARK: Layout edit mode
    // While active, the home button and control bar can be dragged (and stop reacting to taps);
    // while inactive, dragging is ignored and the buttons behave normally.
    @State private var isLayoutEditMode: Bool = false

    // MARK: Cursor settings sheet
    @State private var showCursorSettings: Bool = false
    @AppStorage("cursorSpeed") private var cursorSpeed: Double = 2.0
    @State private var tempCursorSpeed: Double = 2.0

    // MARK: Touch mode & on-screen keyboard
    @AppStorage("isTouchMode") private var isTouchMode: Bool = true
    @FocusState private var keyboardFocus: Bool

    // MARK: Misc
    @State private var animate = false
    @State private var showDocumentPicker: Bool = false

    private var isOnAuthURL: Bool {
        guard let urlString = currentURL?.absoluteString else { return false }
        return urlString.hasPrefix("https://auth.dev.escience.uni-freiburg.de/realms/osvdi/protocol/openid-connect/")
    }
    
    
    
    var body: some View {
        VStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ZStack {
                    
                    WebView(urlString: currentURL?.absoluteString ?? "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape, currentURL: $currentURL, requestedURL: $requestedURL, typingBuffer: $typingBuffer, cursorSpeed: cursorSpeed)
                        .scaleEffect(cumulativeScale * transientScale, anchor: .center)
                        .offset(x: contentOffset.width + transientOffset.width, y: contentOffset.height + transientOffset.height)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .opacity(isLoading ? 0 : 1)
                        .clipped()
                        .allowsHitTesting(!isPinching)
                        .blur(radius: isLayoutEditMode ? 8 : 0)
                        .id(webViewID) // SwiftUI baut neue WebView, wenn id sich ändert
                        .onChange(of: isTouchMode) { _, _ in
                            // Force rebuild bei TouchMode-Update
                            webViewID = UUID()
                        }
                    /*
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    // Pinch kann parallel zu Pan laufen
                                    isPinching = true
                                    let proposed = cumulativeScale * value
                                    let clamped = min(max(proposed, 0.5), 3.0)
                                    transientScale = clamped / cumulativeScale
                                }
                                .onEnded { value in
                                    let proposed = cumulativeScale * value
                                    let clamped = min(max(proposed, 0.5), 3.0)
                                    cumulativeScale = clamped
                                    transientScale = 1.0
                                    isPinching = false
                                    // Pan bleibt erlaubt, solange gezoomt ist
                                }
                        )
                     */


                }

                // Dims the background while the layout edit mode is active
                if isLayoutEditMode {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Hidden TextField to trigger keyboard on demand
                EnhancedTextField(placeholder: "", text: $typingBuffer, onBackspace: { isEmpty in
                    NotificationCenter.default.post(name: Notification.Name("WebViewSendBackspace"), object: nil)
                }, onReturn: {
                    // handle Enter/Return here
                    NotificationCenter.default.post(name: Notification.Name("WebViewSendEnter"), object: nil)
                    keyboardFocus = false
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
                                // Home button - drags independently from the control bar below
                                HStack {
                                    Button {
                                        // Navigate to home when arrow is pressed
                                        cumulativeScale = 1.0
                                        requestedURL = URL(string: "https://demo.osvdi.uni-freiburg.de")
                                        keyboardFocus = false
                                        withAnimation(.snappy) {
                                            isOverlayExpanded = false
                                        }

                                    } label: {
                                        Image(systemName: "house.fill")
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
                                    .disabled(isDraggingHome || isLayoutEditMode)
                                }
                                .padding(.top, 24)
                                .padding(.leading, 24)
                                .offset(x: homePosition.width, y: homePosition.height)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard isLayoutEditMode else { return }
                                            isDraggingHome = true
                                            homePosition = CGSize(
                                                width: homeStartPosition.width + value.translation.width,
                                                height: homeStartPosition.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            guard isLayoutEditMode else { return }
                                            homeStartPosition = homePosition
                                            isDraggingHome = false
                                        }
                                )

                                Spacer()

                                // Control bar - drags independently from the home button above
                                HStack {
                                    
                                    if isOverlayExpanded {
                                        
                                        // Layout edit mode toggle - always visible (even collapsed) so it's
                                        // reachable as the way back out. Turns green while active.
                                        Button {
                                            withAnimation(.snappy) {
                                                isLayoutEditMode.toggle()
                                                if isLayoutEditMode {
                                                    isOverlayExpanded = true
                                                }
                                            }
                                        } label: {
                                            Image(systemName: isLayoutEditMode ? "checkmark.circle.fill" : "arrow.up.and.down.and.arrow.left.and.right")
                                                .scaledToFit()
                                                .frame(width: 28, height: 28)
                                                .scaleEffect(0.9)
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(isLayoutEditMode ? .green : .blue)
                                                .symbolRenderingMode(.hierarchical)
                                                .padding(5)
                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                        .disabled(isDraggingControlBar)
                                        
                                        
                                        // Cursor settings button
                                        Button {
                                            showCursorSettings = true
                                        } label: {
                                            Image(systemName: "gearshape.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 28, height: 28)
                                                .scaleEffect(0.9)
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(.primary)
                                                .symbolRenderingMode(.hierarchical)
                                                .padding(5)
                                                .padding(.leading, 5)
                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                        .disabled(isDraggingControlBar || isLayoutEditMode)

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
                                                .opacity(isTouchMode ? 1.0 : 0.6)
                                                .padding(5)


                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                        .disabled(isDraggingControlBar || isLayoutEditMode || !isTouchMode)
                                        
                                        // File picker button
                                        Button {
                                            showDocumentPicker = true
                                        } label: {
                                            Image(systemName: "folder.badge.plus.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 28, height: 28)
                                                .scaleEffect(0.9)
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(.primary)
                                                .symbolRenderingMode(.hierarchical)
                                                .padding(5)
                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                        .disabled(isDraggingControlBar || isLayoutEditMode)

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
                                                .padding(5)
                                            
                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                        .disabled(isDraggingControlBar || isLayoutEditMode)
                                    }


                                    // Arrow toggle button (expand/collapse control bar)
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
                                            .background(.clear, in: Capsule())
                                    }
                                    .disabled(isDraggingControlBar || isLayoutEditMode)
                                }
                                .padding(1)
                                .background(.ultraThinMaterial, in: Capsule())
                                .offset(x: controlBarPosition.width, y: controlBarPosition.height)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard isLayoutEditMode else { return }
                                            isDraggingControlBar = true
                                            controlBarPosition = CGSize(
                                                width: controlBarStartPosition.width + value.translation.width,
                                                height: controlBarStartPosition.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            guard isLayoutEditMode else { return }
                                            controlBarStartPosition = controlBarPosition
                                            isDraggingControlBar = false
                                        }
                                )
                            }
                            .padding(.top, 24)
                            .padding(.trailing, 24)
                        }

                        Spacer()
                    }

                    .allowsHitTesting(true)
                }
                
                if isLoading {
                    ZStack {
                          ForEach(0..<3) { i in
                              Circle()
                                  .stroke(lineWidth: 2)
                                  .scaleEffect(animate ? 2 : 0)
                                  .opacity(animate ? 0 : 1)
                                  .animation(
                                      .easeOut(duration: 1.5)
                                          .repeatForever()
                                          .delay(Double(i) * 0.5),
                                      value: animate
                                  )
                          }
                      }
                      .frame(width: 40, height: 40)
                      .onAppear { animate.toggle() }
                }
            }
        }
        .sheet(isPresented: $showCursorSettings) {
            ZStack {
                VStack{
                    HStack {
                        Spacer()
                        Button {
                            // Cancel: discard changes and close
                            showCursorSettings = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(.secondary)
                                .padding(20)
                        }
                    }
                    .padding(.top, 4)
                    Spacer()
                }
    
                VStack(spacing: 16) {
                    Text("Mouse-Cursor Speed")
                        .font(.headline)
                    HStack {
                        Image(systemName: "tortoise.fill")
                        Slider(value: $tempCursorSpeed, in: 0.5...10.0, step: 0.01)
                        Image(systemName: "hare.fill")
                    }
                    Text(String(format: "%.1fx", tempCursorSpeed))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Done") {
                        // Commit: apply changes and reload web view
                        cursorSpeed = tempCursorSpeed
                        showCursorSettings = false
                        webViewID = UUID()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .onAppear {
                    // Initialize temp value when sheet appears
                    tempCursorSpeed = cursorSpeed 
                }
                .frame(minHeight: 240)
                .background(Color(.systemBackground))
                .transaction { txn in
                    txn.disablesAnimations = true
                }
                .padding()
                .presentationDetents([.medium])
                .presentationBackgroundInteraction(.disabled)
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
            }
        }
        
        .overlay(alignment: .top) {
            
            if networkMonitor.isOffline {
                ConnectionToast(
                    isOffline: true
                )
                .padding(.top, 12)
                .transition(
                    .move(edge: .top)
                        .combined(with: .opacity)
                )
            }
 
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: networkMonitor.isOffline
        )
        .animation(.easeInOut(duration: 0.25), value: isLayoutEditMode)


        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(allowedContentTypes: [.item], allowsMultipleSelection: true) { urls in
                NotificationCenter.default.post(name: Notification.Name("WebViewUploadFiles"), object: urls)
            }
        }

        .ignoresSafeArea()
        // Called when the scene phase changes (e.g., the app returns to the foreground from the background)
        .onChange(of: scenePhase) { oldValue, newValue in
            // Detect that the app is active again (in the foreground); in landscape mode, the WebView is reloaded
            if newValue == .active && shouldForceLandscape == true {
                // Assign a new identifier to force SwiftUI to rebuild the WebView hierarchy (effectively reloads the WebView)
                webViewID = UUID()
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
        .preferredColorScheme(.dark)
}

