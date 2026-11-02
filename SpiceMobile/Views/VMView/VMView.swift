//
//  VMView.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 01.12.25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Endpoints

private enum Endpoint {
    static let home = "https://bwlehrpool.osvdi.uni-freiburg.de/"
    static let start = "https://bwlehrpool.osvdi.uni-freiburg.de/"
    static let authPrefix = "https://auth.dev.escience.uni-freiburg.de/realms/osvdi/protocol/openid-connect/"
}

// MARK: - VMView

struct VMView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var networkMonitor = NetworkMonitor()
    private let externalDisplay = ExternalDisplayManager.shared

    // WebView
    @State private var isLoading = true
    @State private var shouldForceLandscape = false
    @State private var webViewID = UUID()  // Neue ID erzwingt, dass SwiftUI die WebView neu aufbaut
    @State private var currentURL: URL?
    @State private var requestedURL: URL?
    @State private var typingBuffer = ""

    // Pinch-to-Zoom / Pan
    // Rein visuell (scaleEffect/offset), die WebView selbst ändert ihre Größe nie.
    // Pannen geht erst, wenn hineingezoomt wurde (cumulativeScale > 1).
    @State private var cumulativeScale: CGFloat = 1.0
    @State private var transientScale: CGFloat = 1.0
    @State private var isPinching = false
    @State private var contentOffset: CGSize = .zero
    @State private var transientOffset: CGSize = .zero

    // Overlay-Steuerung (Home-Button und Control Bar lassen sich unabhängig verschieben)
    @State private var isOverlayExpanded = false
    @State private var controlBarPosition: CGSize = .zero
    @State private var isDraggingControlBar = false
    @State private var homePosition: CGSize = .zero
    @State private var isDraggingHome = false

    // Im Layout-Edit-Mode lassen sich die Buttons verschieben, Taps werden ignoriert.
    @State private var isLayoutEditMode = false

    @State private var showCursorSettings = false
    @State private var showDocumentPicker = false
    @AppStorage("cursorSpeed") private var cursorSpeed: Double = 2.0
    @AppStorage("isTouchMode") private var isTouchMode: Bool = true
    @FocusState private var keyboardFocus: Bool

    private var isOnAuthURL: Bool {
        currentURL?.absoluteString.hasPrefix(Endpoint.authPrefix) ?? false
    }

    /// Controller-Modus: externes Display verbunden und eine VM-Session (Landscape) aktiv.
    /// Die VM wird dann auf dem externen Display gezeigt, das Gerät dient als Fernbedienung.
    private var isControllerMode: Bool {
        externalDisplay.isConnected && shouldForceLandscape
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            webView

            if isControllerMode {
                controllerBackground

                // Touchpad für die Gesten; liegt unter den Overlay-Buttons und ist im Layout-Edit-Mode aus
                TouchpadView()
                    .ignoresSafeArea()
                    .allowsHitTesting(!isLayoutEditMode)
            }

            if isLayoutEditMode {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            keyboardInput

            if !isOnAuthURL {
                overlayControls
            }

            if isLoading {
                LoadingPulse()
            }
        }
        .sheet(isPresented: $showCursorSettings) {
            CursorSettingsSheet(
                initialSpeed: cursorSpeed,
                onCancel: { showCursorSettings = false },
                onDone: { speed in
                    cursorSpeed = speed
                    showCursorSettings = false
                    webViewID = UUID()
                }
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(allowedContentTypes: [.item], allowsMultipleSelection: true) { urls in
                NotificationCenter.default.post(name: .webViewUploadFiles, object: urls)
            }
        }
        .overlay(alignment: .top) {
            if networkMonitor.isOffline {
                ConnectionToast(isOffline: true)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Externes Display nur während einer VM-Session übernehmen, sonst bleibt es beim Mirroring
        .modifier(ExternalDisplayAccessoryModifier(isEnabled: shouldForceLandscape))
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isOffline)
        .animation(.easeInOut(duration: 0.25), value: isLayoutEditMode)
        .onChange(of: isControllerMode) { _, _ in
            // Zoom/Pan der lokalen Anzeige beim Moduswechsel zurücksetzen
            cumulativeScale = 1.0
            transientScale = 1.0
            contentOffset = .zero
            transientOffset = .zero
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) { _, newPhase in
            // Zurück im Vordergrund: laufende Session durch Neuaufbau der WebView neu laden
            if newPhase == .active && shouldForceLandscape {
                webViewID = UUID()
            }
        }
    }

    // MARK: WebView

    private var webView: some View {
        WebView(
            urlString: currentURL?.absoluteString ?? Endpoint.start,
            isLoading: $isLoading,
            shouldForceLandscape: $shouldForceLandscape,
            currentURL: $currentURL,
            requestedURL: $requestedURL,
            typingBuffer: $typingBuffer,
            cursorSpeed: cursorSpeed,
            isPresentedExternally: isControllerMode
        )
        .scaleEffect(cumulativeScale * transientScale, anchor: .center)
        .offset(x: contentOffset.width + transientOffset.width,
                y: contentOffset.height + transientOffset.height)
        .contentShape(Rectangle())
        .opacity(isLoading ? 0 : 1)
        .clipped()
        // Solange gezoomt wird, steuern Touches Zoom/Pan statt Maus-Eingaben an die Remote-Session
        .allowsHitTesting(!isPinching && cumulativeScale <= 1.0)
        .blur(radius: isLayoutEditMode ? 8 : 0)
        .id(webViewID)
        .onChange(of: isTouchMode) { _, _ in
            // Touch-Mode wird beim Aufbau der WebView ausgewertet
            webViewID = UUID()
        }
        .simultaneousGesture(pinchGesture)
        .simultaneousGesture(panGesture)
    }

    /// Hintergrund im Controller-Modus; die VM selbst läuft auf dem externen Display.
    private var controllerBackground: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "tv.and.mediabox")
                    .font(.system(size: 48))
                Text("Controller Mode")
                    .font(.headline)
                Text("The virtual machine is shown on the external display.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isPinching = true
                transientScale = clampedScale(cumulativeScale * value) / cumulativeScale
            }
            .onEnded { value in
                cumulativeScale = clampedScale(cumulativeScale * value)
                transientScale = 1.0
                isPinching = false
                if cumulativeScale <= 1.0 {
                    // Beim vollständigen Herauszoomen das Pannen zurücksetzen
                    contentOffset = .zero
                    transientOffset = .zero
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard cumulativeScale > 1.0 else { return }
                transientOffset = value.translation
            }
            .onEnded { value in
                guard cumulativeScale > 1.0 else { return }
                contentOffset.width += value.translation.width
                contentOffset.height += value.translation.height
                transientOffset = .zero
            }
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 1.0), 4.0)
    }

    // MARK: Keyboard

    /// Unsichtbares Textfeld, das die Bildschirmtastatur bei Bedarf öffnet.
    private var keyboardInput: some View {
        EnhancedTextField(placeholder: "", text: $typingBuffer, onBackspace: { _ in
            NotificationCenter.default.post(name: .webViewSendBackspace, object: nil)
        }, onReturn: {
            NotificationCenter.default.post(name: .webViewSendEnter, object: nil)
            keyboardFocus = false
        })
        .focused($keyboardFocus)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .frame(width: 0, height: 0)
        .opacity(0.01)
        .allowsHitTesting(false)
    }

    // MARK: Overlay controls

    private var overlayControls: some View {
        VStack {
            if shouldForceLandscape {
                HStack {
                    homeButton
                    Spacer()
                    controlBar
                }
                .padding(.top, 24)
                .padding(.trailing, 24)
            }
            Spacer()
        }
    }

    private var homeButton: some View {
        Button {
            cumulativeScale = 1.0
            requestedURL = URL(string: Endpoint.home)
            keyboardFocus = false
            withAnimation(.snappy) {
                isOverlayExpanded = false
            }
        } label: {
            OverlayIcon(name: "house.fill", resizable: false, padding: 10)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .disabled(isDraggingHome || isLayoutEditMode)
        .padding(.top, 24)
        .padding(.leading, 24)
        .layoutDraggable(isEnabled: isLayoutEditMode, position: $homePosition, isDragging: $isDraggingHome)
    }

    private var controlBar: some View {
        HStack {
            if isOverlayExpanded {
                // Layout-Edit-Toggle: bleibt auch im Edit-Mode bedienbar, um ihn wieder zu verlassen
                controlButton(disabledInEditMode: false) {
                    withAnimation(.snappy) {
                        isLayoutEditMode.toggle()
                        if isLayoutEditMode {
                            isOverlayExpanded = true
                        }
                    }
                } icon: {
                    OverlayIcon(name: isLayoutEditMode ? "checkmark.circle.fill" : "arrow.up.and.down.and.arrow.left.and.right",
                                resizable: false,
                                tint: isLayoutEditMode ? .green : .blue)
                }

                controlButton {
                    showCursorSettings = true
                } icon: {
                    OverlayIcon(name: "gearshape.fill")
                        .padding(.leading, 5)
                }

                controlButton(isDisabled: !isTouchMode) {
                    isTouchMode.toggle()
                } icon: {
                    OverlayIcon(name: "hand.tap.fill")
                        .opacity(isTouchMode ? 1.0 : 0.6)
                }

                controlButton {
                    showDocumentPicker = true
                } icon: {
                    OverlayIcon(name: "folder.badge.plus.fill")
                }

                controlButton {
                    keyboardFocus.toggle()
                } icon: {
                    OverlayIcon(name: "keyboard.fill")
                }
            }

            // Control Bar ein-/ausklappen
            Button {
                withAnimation(.snappy) {
                    if isOverlayExpanded { keyboardFocus = false }
                    isOverlayExpanded.toggle()
                }
            } label: {
                OverlayIcon(name: isOverlayExpanded ? "minus.circle.fill" : "plus.circle.fill",
                            resizable: false,
                            padding: 10)
            }
            .disabled(isDraggingControlBar || isLayoutEditMode)
        }
        .padding(1)
        .background(.ultraThinMaterial, in: Capsule())
        .layoutDraggable(isEnabled: isLayoutEditMode, position: $controlBarPosition, isDragging: $isDraggingControlBar)
    }

    /// Button der aufgeklappten Control Bar; im Layout-Edit-Mode oder beim Verschieben deaktiviert.
    private func controlButton<Icon: View>(disabledInEditMode: Bool = true,
                                           isDisabled: Bool = false,
                                           action: @escaping () -> Void,
                                           @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            icon()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .disabled(isDraggingControlBar || (disabledInEditMode && isLayoutEditMode) || isDisabled)
    }
}

// MARK: - Overlay icon

private struct OverlayIcon: View {
    let name: String
    var resizable = true
    var tint: Color?
    var padding: CGFloat = 5

    var body: some View {
        icon
            .scaledToFit()
            .frame(width: 28, height: 28)
            .scaleEffect(0.9)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
            .symbolRenderingMode(.hierarchical)
            .padding(padding)
    }

    @ViewBuilder
    private var icon: some View {
        if resizable {
            Image(systemName: name).resizable()
        } else {
            Image(systemName: name)
        }
    }
}

// MARK: - Layout dragging

private extension View {
    /// Macht die View im Layout-Edit-Mode per Drag verschiebbar.
    func layoutDraggable(isEnabled: Bool, position: Binding<CGSize>, isDragging: Binding<Bool>) -> some View {
        modifier(LayoutDraggable(isEnabled: isEnabled, position: position, isDragging: isDragging))
    }
}

private struct LayoutDraggable: ViewModifier {
    let isEnabled: Bool
    @Binding var position: CGSize
    @Binding var isDragging: Bool
    @State private var translation: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .offset(x: position.width + translation.width, y: position.height + translation.height)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        isDragging = true
                        translation = value.translation
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        position.width += translation.width
                        position.height += translation.height
                        translation = .zero
                        isDragging = false
                    }
            )
    }
}

// MARK: - Loading indicator

private struct LoadingPulse: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(lineWidth: 2)
                    .scaleEffect(animate ? 2 : 0)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5)
                            .repeatForever()
                            .delay(Double(index) * 0.5),
                        value: animate
                    )
            }
        }
        .frame(width: 40, height: 40)
        .onAppear { animate.toggle() }
    }
}

// MARK: - Cursor settings

private struct CursorSettingsSheet: View {
    let onCancel: () -> Void
    let onDone: (Double) -> Void
    @State private var speed: Double

    init(initialSpeed: Double, onCancel: @escaping () -> Void, onDone: @escaping (Double) -> Void) {
        self._speed = State(initialValue: initialSpeed)
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
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
                    Slider(value: $speed, in: 0.5...10.0, step: 0.01)
                    Image(systemName: "hare.fill")
                }
                Text(String(format: "%.1fx", speed))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Done") { onDone(speed) }
                    .buttonStyle(.borderedProminent)
            }
            .frame(minHeight: 240)
            .background(Color(.systemBackground))
            .transaction { $0.disablesAnimations = true }
            .padding()
            .presentationDetents([.medium])
            .presentationBackgroundInteraction(.disabled)
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
        .preferredColorScheme(.dark)
}
