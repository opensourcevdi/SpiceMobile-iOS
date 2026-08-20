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
        
        override func becomeFirstResponder() -> Bool {
            let became = super.becomeFirstResponder()
            if became {
                // Ensure global modifier state is initialized on first keyboard open
                NotificationCenter.default.post(name: Notification.Name("WebViewSetModifiers"), object: nil, userInfo: [
                    "shift": false,
                    "control": false,
                    "option": false,
                    "command": false
                ])
            }
            return became
        }

        override func deleteBackward() {
            onBackspace?(text?.isEmpty == true)
            super.deleteBackward()
        }

        override func resignFirstResponder() -> Bool {
            let resigned = super.resignFirstResponder()
            if resigned {
                // Reset modifier buttons visual state when keyboard closes
                clearModifierButtonsVisuals()
                // Also notify WebView to clear modifier state
                NotificationCenter.default.post(name: Notification.Name("WebViewClearModifiers"), object: nil)
            }
            return resigned
        }

        private func clearModifierButtonsVisuals() {
            guard let scroll = self.inputAccessoryView?.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else { return }
            guard let stack = scroll.subviews.first(where: { $0 is UIStackView }) as? UIStackView else { return }
            for case let btn as UIButton in stack.arrangedSubviews {
                if let id = btn.accessibilityIdentifier, id.hasPrefix("modifier_") {
                    btn.backgroundColor = UIColor.secondarySystemBackground
                    btn.setTitleColor(UIColor.label, for: .normal)
                }
            }
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

            // Modifier buttons (sticky)
            let modifiers: [(title: String, name: String, action: Selector)] = [
                ("⇧", "shift", #selector(didTapShift)),
                ("⌃", "control", #selector(didTapControl)),
                ("⌥", "option", #selector(didTapOption)),
                ("⌘", "command", #selector(didTapCommand))
            ]

            for mod in modifiers {
                let button = UIButton(type: .system)
                button.setTitle(mod.title, for: .normal)
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
                button.accessibilityIdentifier = "modifier_\(mod.name)"
                button.addTarget(self, action: mod.action, for: .touchUpInside)
                stack.addArrangedSubview(button)
            }


            // Separator spacer
            let sep = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
            sep.widthAnchor.constraint(equalToConstant: 12).isActive = true
            stack.addArrangedSubview(sep)
            
            // super/windows key button
            let superButton = UIButton(type: .system)
            superButton.setTitle("⊞", for: .normal)
            superButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            superButton.layer.cornerRadius = 12
            superButton.layer.masksToBounds = true
            superButton.backgroundColor = UIColor.secondarySystemBackground
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                superButton.configuration = config
            } else {
                superButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            }
            superButton.layer.borderWidth = 1
            superButton.layer.borderColor = UIColor.tertiaryLabel.cgColor
            superButton.tintColor = UIColor.label
            superButton.accessibilityIdentifier = "key_super"
            superButton.addTarget(self, action: #selector(didTapSuper), for: .touchUpInside)
            stack.addArrangedSubview(superButton)
            
            let tabButton = UIButton(type: .system)
            tabButton.setTitle("⇥", for: .normal)
            tabButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            tabButton.layer.cornerRadius = 12
            tabButton.layer.masksToBounds = true
            tabButton.backgroundColor = UIColor.secondarySystemBackground
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                tabButton.configuration = config
            } else {
                tabButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            }
            tabButton.layer.borderWidth = 1
            tabButton.layer.borderColor = UIColor.tertiaryLabel.cgColor
            tabButton.tintColor = UIColor.label
            tabButton.accessibilityIdentifier = "key_tab"
            tabButton.addTarget(self, action: #selector(didTapTab), for: .touchUpInside)
            stack.addArrangedSubview(tabButton)


            // Arrow keys and Tab / Super
            let arrowLeft = UIButton(type: .system)
            arrowLeft.setTitle("←", for: .normal)
            arrowLeft.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            arrowLeft.layer.cornerRadius = 12
            arrowLeft.layer.masksToBounds = true
            arrowLeft.backgroundColor = UIColor.secondarySystemBackground
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                arrowLeft.configuration = config
            } else {
                arrowLeft.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            }
            arrowLeft.layer.borderWidth = 1
            arrowLeft.layer.borderColor = UIColor.tertiaryLabel.cgColor
            arrowLeft.tintColor = UIColor.label
            arrowLeft.accessibilityIdentifier = "arrow_left"
            arrowLeft.addTarget(self, action: #selector(didTapArrowLeft), for: .touchUpInside)
            stack.addArrangedSubview(arrowLeft)

            let arrowUp = UIButton(type: .system)
            arrowUp.setTitle("↑", for: .normal)
            arrowUp.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            arrowUp.layer.cornerRadius = 12
            arrowUp.layer.masksToBounds = true
            arrowUp.backgroundColor = UIColor.secondarySystemBackground
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                arrowUp.configuration = config
            } else {
                arrowUp.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            }
            arrowUp.layer.borderWidth = 1
            arrowUp.layer.borderColor = UIColor.tertiaryLabel.cgColor
            arrowUp.tintColor = UIColor.label
            arrowUp.accessibilityIdentifier = "arrow_up"
            arrowUp.addTarget(self, action: #selector(didTapArrowUp), for: .touchUpInside)
            stack.addArrangedSubview(arrowUp)

            let arrowDown = UIButton(type: .system)
            arrowDown.setTitle("↓", for: .normal)
            arrowDown.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            arrowDown.layer.cornerRadius = 12
            arrowDown.layer.masksToBounds = true
            arrowDown.backgroundColor = UIColor.secondarySystemBackground
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                arrowDown.configuration = config
            } else {
                arrowDown.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            }
            arrowDown.layer.borderWidth = 1
            arrowDown.layer.borderColor = UIColor.tertiaryLabel.cgColor
            arrowDown.tintColor = UIColor.label
            arrowDown.accessibilityIdentifier = "arrow_down"
            arrowDown.addTarget(self, action: #selector(didTapArrowDown), for: .touchUpInside)
            stack.addArrangedSubview(arrowDown)

            let arrowRight = UIButton(type: .system)
            arrowRight.setTitle("→", for: .normal)
            arrowRight.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            arrowRight.layer.cornerRadius = 12
            arrowRight.layer.masksToBounds = true
            arrowRight.backgroundColor = UIColor.secondarySystemBackground
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
                arrowRight.configuration = config
            } else {
                arrowRight.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            }
            arrowRight.layer.borderWidth = 1
            arrowRight.layer.borderColor = UIColor.tertiaryLabel.cgColor
            arrowRight.tintColor = UIColor.label
            arrowRight.accessibilityIdentifier = "arrow_right"
            arrowRight.addTarget(self, action: #selector(didTapArrowRight), for: .touchUpInside)
            stack.addArrangedSubview(arrowRight)

            // F1..F12 buttons
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

        private func toggleButtonAppearance(_ button: UIButton) {
            // Toggle selection look
            let selected = !(button.backgroundColor == UIColor.systemBlue)
            if selected {
                button.backgroundColor = UIColor.systemBlue
                button.setTitleColor(.white, for: .normal)
            } else {
                button.backgroundColor = UIColor.secondarySystemBackground
                button.setTitleColor(UIColor.label, for: .normal)
            }
        }

        @objc private func didTapShift(_ sender: UIButton) {
            toggleButtonAppearance(sender)
            NotificationCenter.default.post(name: Notification.Name("WebViewToggleShift"), object: nil)
        }
        @objc private func didTapControl(_ sender: UIButton) {
            toggleButtonAppearance(sender)
            NotificationCenter.default.post(name: Notification.Name("WebViewToggleControl"), object: nil)
        }
        @objc private func didTapOption(_ sender: UIButton) {
            toggleButtonAppearance(sender)
            NotificationCenter.default.post(name: Notification.Name("WebViewToggleOption"), object: nil)
        }
        @objc private func didTapCommand(_ sender: UIButton) {
            toggleButtonAppearance(sender)
            NotificationCenter.default.post(name: Notification.Name("WebViewToggleCommand"), object: nil)
        }
        @objc private func didTapClearModifiers(_ sender: UIButton) {
            // Reset all modifier button visuals
            if let stack = sender.superview as? UIStackView ?? sender.superview?.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
                for case let btn as UIButton in stack.arrangedSubviews {
                    if let id = btn.accessibilityIdentifier, id.hasPrefix("modifier_") {
                        btn.backgroundColor = UIColor.secondarySystemBackground
                        btn.setTitleColor(UIColor.label, for: .normal)
                    }
                }
            }
            NotificationCenter.default.post(name: Notification.Name("WebViewClearModifiers"), object: nil)
        }

        @objc private func didTapArrowLeft(_ sender: UIButton) { NotificationCenter.default.post(name: Notification.Name("WebViewSendArrowKey"), object: "left") }
        @objc private func didTapArrowRight(_ sender: UIButton) { NotificationCenter.default.post(name: Notification.Name("WebViewSendArrowKey"), object: "right") }
        @objc private func didTapArrowUp(_ sender: UIButton) { NotificationCenter.default.post(name: Notification.Name("WebViewSendArrowKey"), object: "up") }
        @objc private func didTapArrowDown(_ sender: UIButton) { NotificationCenter.default.post(name: Notification.Name("WebViewSendArrowKey"), object: "down") }
        @objc private func didTapTab(_ sender: UIButton) { NotificationCenter.default.post(name: Notification.Name("WebViewSendTab"), object: nil) }
        @objc private func didTapSuper(_ sender: UIButton) { NotificationCenter.default.post(name: Notification.Name("WebViewSendSuper"), object: nil) }
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

