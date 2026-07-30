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
            self.inputAccessoryView = buildFunctionKeysAccessory()
            self.autocorrectionType = .no
            self.spellCheckingType = .no
            if #available(iOS 11.0, *) {
                self.smartInsertDeleteType = .no
            }
            self.smartQuotesType = .no
            self.smartDashesType = .no
            if #available(iOS 10.0, *) {
                self.textContentType = .none
            }
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.returnKeyType = .done
            self.inputAccessoryView = buildFunctionKeysAccessory()
            self.autocorrectionType = .no
            self.spellCheckingType = .no
            if #available(iOS 11.0, *) {
                self.smartInsertDeleteType = .no
            }
            self.smartQuotesType = .no
            self.smartDashesType = .no
            if #available(iOS 10.0, *) {
                self.textContentType = .none
            }
        }

        override func deleteBackward() {
            onBackspace?(text?.isEmpty == true)
            super.deleteBackward()
        }

        private func buildFunctionKeysAccessory() -> UIView {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))

            let scroll = UIScrollView(frame: container.bounds)
            scroll.showsHorizontalScrollIndicator = false
            scroll.alwaysBounceHorizontal = true

            let stack = UIStackView()
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fillProportionally
            stack.spacing = 8

            let leftInset = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
            leftInset.widthAnchor.constraint(equalToConstant: 8).isActive = true
            stack.addArrangedSubview(leftInset)

            for i in 1...12 {
                let button = UIButton(type: .system)
                button.setTitle("F\(i)", for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
                button.setContentHuggingPriority(.required, for: .horizontal)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
                button.layer.cornerRadius = 12
                button.layer.masksToBounds = true
                button.backgroundColor = UIColor.secondarySystemBackground
                if #available(iOS 15.0, *) {
                    var config = UIButton.Configuration.plain()
                    config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                    button.configuration = config
                } else {
                    button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
                }
                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.tertiaryLabel.cgColor
                button.tintColor = UIColor.label
                button.tag = i
                button.addTarget(self, action: #selector(didTapFunctionKey(_:)), for: .touchUpInside)
                stack.addArrangedSubview(button)
            }

            let rightInset = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 1))
            rightInset.widthAnchor.constraint(equalToConstant: 8).isActive = true
            stack.addArrangedSubview(rightInset)

            stack.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(stack)
            container.addSubview(scroll)

            scroll.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: container.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
            ])

            return container
        }

        @objc private func didTapFunctionKey(_ sender: UIButton) {
            let n = sender.tag
            NotificationCenter.default.post(name: Notification.Name("WebViewSendFunctionKey"), object: n)
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

