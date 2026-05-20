import SwiftUI
import UIKit




// Enhanced textfield (to detect backspace press)
struct EnhancedTextField: UIViewRepresentable {

    let placeholder: String
    @Binding var text: String
    let onBackspace: (Bool) -> Void // true if backspace on empty input
    let onReturn: () -> Void

    func makeCoordinator() -> EnhancedTextFieldCoordinator {
        EnhancedTextFieldCoordinator(textBinding: $text, onReturn: onReturn)
    }

    func makeUIView(context: Context) -> EnhancedUITextField {
        let view = EnhancedUITextField()
        view.placeholder = placeholder
        view.delegate = context.coordinator
        view.onBackspace = onBackspace
        view.onReturn = onReturn
        // Ensure first responder can be obtained when needed by SwiftUI focus
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: EnhancedUITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        uiView.onBackspace = onBackspace
        uiView.onReturn = onReturn
    }

    // custom UITextField subclass that detects backspace events
    class EnhancedUITextField: UITextField {
        var onBackspace: ((Bool) -> Void)?
        var onReturn: (() -> Void)?

        override var delegate: UITextFieldDelegate? {
            didSet {
                // Ensure delegate is always the coordinator to capture events
                // (This will override external delegate assignments)
                // Commented out because we set delegate only once in makeUIView
                // If needed, add logic here to protect delegate assignment
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.returnKeyType = .done
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.returnKeyType = .done
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
    let onReturn: () -> Void

    init(textBinding: Binding<String>, onReturn: @escaping () -> Void) {
        self.textBinding = textBinding
        self.onReturn = onReturn
    }
}

extension EnhancedTextFieldCoordinator: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        // Compute the resulting string safely

        let current = textField.text ?? ""
        if let swiftRange = Range(range, in: current) {
            let updated = current.replacingCharacters(in: swiftRange, with: string)
            DispatchQueue.main.async {
                self.textBinding.wrappedValue = updated
            }
        } else {
            DispatchQueue.main.async {
                self.textBinding.wrappedValue = current
            }
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn()
        return true
    }
}

