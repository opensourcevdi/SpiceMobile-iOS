import SwiftUI
import UIKit

struct PinchBridgeView: UIViewRepresentable {
    var onBegin: ((CGFloat, CGPoint) -> Void)?
    var onChange: ((CGFloat, CGPoint) -> Void)?
    var onEnd: ((CGFloat, CGPoint) -> Void)?
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBegin: ((CGFloat, CGPoint) -> Void)?
        var onChange: ((CGFloat, CGPoint) -> Void)?
        var onEnd: ((CGFloat, CGPoint) -> Void)?
        
        init(
            onBegin: ((CGFloat, CGPoint) -> Void)?,
            onChange: ((CGFloat, CGPoint) -> Void)?,
            onEnd: ((CGFloat, CGPoint) -> Void)?
        ) {
            self.onBegin = onBegin
            self.onChange = onChange
            self.onEnd = onEnd
        }
        
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let scale = recognizer.scale
            let location = recognizer.location(in: view)
            
            switch recognizer.state {
            case .began:
                onBegin?(scale, location)
            case .changed:
                onChange?(scale, location)
            case .ended, .cancelled, .failed:
                onEnd?(scale, location)
            default:
                break
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onBegin: onBegin, onChange: onChange, onEnd: onEnd)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = context.coordinator
        
        view.addGestureRecognizer(pinchRecognizer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
