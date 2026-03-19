import SwiftUI
import UIKit




// Enhanced textfield (to detect backspace press)
struct EnhancedTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let onBackspace: (Bool) -> Void // true if backspace on empty input

    func makeCoordinator() -> EnhancedTextFieldCoordinator {
        EnhancedTextFieldCoordinator(textBinding: $text)
    }

    func makeUIView(context: Context) -> EnhancedUITextField {
        let view = EnhancedUITextField()
        view.placeholder = placeholder
        view.delegate = context.coordinator
        // Ensure first responder can be obtained when needed by SwiftUI focus
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: EnhancedUITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        uiView.onBackspace = onBackspace
    }

    // custom UITextField subclass that detects backspace events
    class EnhancedUITextField: UITextField {
        var onBackspace: ((Bool) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func deleteBackward() {
            onBackspace?(text?.isEmpty == true)
            super.deleteBackward()
        }
    }
}

// Coordinator maps text changes back to the binding
class EnhancedTextFieldCoordinator: NSObject {
    let textBinding: Binding<String>

    init(textBinding: Binding<String>) {
        self.textBinding = textBinding
    }
}

extension EnhancedTextFieldCoordinator: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        // Compute the resulting string safely
        
        let current = textField.text ?? ""
        if let swiftRange = Range(range, in: current) {
            let updated = current.replacingCharacters(in: swiftRange, with: string)
            textBinding.wrappedValue = updated
        } else {
            // Fallback: keep current text
            textBinding.wrappedValue = current
        }
        return true
    }
}
