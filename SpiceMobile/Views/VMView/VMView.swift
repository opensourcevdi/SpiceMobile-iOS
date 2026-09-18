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

enum VMConnectionQuality: String, Codable {
    case good
    case slow
    case bad
}

// MARK: - ContentView
struct VMView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showConnectionToast = false
    @State private var connectionToastTask: Task<Void, Never>?
    @State private var animate = false
    @State private var isLoading: Bool = true
    @State private var shouldForceLandscape: Bool = false
    @State private var cumulativeScale: CGFloat = 1.0
    @State private var transientScale: CGFloat = 1.0
    @State private var isPinching: Bool = false
    @State private var canPanAfterPinch: Bool = false
    
    @State private var isPanning: Bool = false
    @State private var contentOffset: CGSize = .zero
    @State private var transientOffset: CGSize = .zero
    
    @State private var isOverlayExpanded: Bool = false
    @State private var showCursorSettings: Bool = false
    @AppStorage("cursorSpeed") private var cursorSpeed: Double = 2.0
    @State private var tempCursorSpeed: Double = 2.0
    @AppStorage("isTouchMode") private var isTouchMode: Bool = true
    @FocusState private var keyboardFocus: Bool
    @State private var hiddenInput: String = ""
    @State private var typingBuffer: String = ""
    @State private var webViewID = UUID()  // jede Änderung erzeugt neue WebView
    
    @State private var currentURL: URL? = nil
    @State private var requestedURL: URL? = nil
    
    @State private var showDocumentPicker: Bool = false
    @State private var pickedFileURLs: [URL] = []
    
    @State private var connectionQuality: VMConnectionQuality = .good
    @State private var isOffline: Bool = false
    
    private var isOnAuthURL: Bool {
        guard let urlString = currentURL?.absoluteString else { return false }
        return urlString.hasPrefix("https://auth.dev.escience.uni-freiburg.de/realms/osvdi/protocol/openid-connect/")
    }
    
    
    
    var body: some View {
        VStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ZStack {
                    
                    WebView(urlString: currentURL?.absoluteString ?? "https://demo.osvdi.uni-freiburg.de/#/", isLoading: $isLoading, shouldForceLandscape: $shouldForceLandscape, currentURL: $currentURL, requestedURL: $requestedURL, typingBuffer: $typingBuffer, connectionQuality: Binding<WebView.ConnectionQuality>(
                        get: {
                            switch connectionQuality {
                            case .good:
                                return .good
                            case .slow:
                                return .slow
                            case .bad:
                                return .bad
                            }
                        },
                        set: { newValue in
                            switch newValue {
                            case .good:
                                connectionQuality = .good
                            case .slow:
                                connectionQuality = .slow
                            case .bad:
                                connectionQuality = .bad
                            }
                        }
                        ), cursorSpeed: cursorSpeed)
                        .scaleEffect(cumulativeScale * transientScale, anchor: .center)
                        .offset(x: contentOffset.width + transientOffset.width, y: contentOffset.height + transientOffset.height)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .opacity(isLoading ? 0 : 1)
                        .clipped()
                        .allowsHitTesting(!isPinching)
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
                                }
                                .padding(.top, 24)
                                .padding(.leading, 24)
                                
                                Spacer()
                                HStack {
                                    
                                    if isOverlayExpanded {
                                        
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
                                                .disabled(!isTouchMode)
                                                .padding(5)
                                            
                                            
                                        }
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                        
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
                                            .background(.clear, in: Capsule())
                                    }
                                }
                                
                                .padding(1)
                                .background(.ultraThinMaterial, in: Capsule())
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
            if showConnectionToast {
                ConnectionToast(
                    quality: connectionQuality,
                    isOffline: isOffline
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
            value: isOffline || connectionQuality != .good
        )
        .onChange(of: connectionQuality) { _, newQuality in
            guard newQuality != .good else {
                withAnimation {
                    showConnectionToast = false
                }
                return
            }

            withAnimation {
                showConnectionToast = true
            }

            Task {
                try? await Task.sleep(for: .seconds(3))

                withAnimation {
                    showConnectionToast = false
                }
            }
        }
        
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(allowedContentTypes: [.item], allowsMultipleSelection: true) { urls in
                pickedFileURLs = urls
                NotificationCenter.default.post(name: Notification.Name("WebViewUploadFiles"), object: urls)
            }
        }
        .onAppear {
            NetworkMonitor.shared.start { offline in
                DispatchQueue.main.async {
                    self.isOffline = offline
                    if offline {
                        self.connectionQuality = .bad
                    }
                }
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

final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private var started = false
    private init() {}
    func start(statusChanged: @escaping (Bool) -> Void) {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { path in
            statusChanged(!(path.status == .satisfied))
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
}

