import UIKit
import SwiftUI
import IPACore

final class KeyboardViewController: UIInputViewController {

    /// Per-install counter for the coach-mark banner. Lives in the extension's
    /// own UserDefaults — no App Group, so the container app can't read this
    /// (and doesn't need to: the banner is purely a keyboard-side hint).
    static let activationCountKey = "ipa.activationCount"

    private var hostingController: UIHostingController<KeyboardRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let root = KeyboardRootView(
            onInsertText: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onDeleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onAdvanceInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController = hosting
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let count = bumpActivationCount()
        NotificationCenter.default.post(
            name: .ipaKeyboardActivationCountChanged,
            object: nil,
            userInfo: ["count": count]
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.post(name: .ipaKeyboardShouldCancelGesture, object: nil)
    }

    /// Increment and persist the per-install activation count. Returns the
    /// new value.
    private func bumpActivationCount() -> Int {
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: Self.activationCountKey) + 1
        defaults.set(next, forKey: Self.activationCountKey)
        return next
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        NotificationCenter.default.post(name: .ipaKeyboardShouldCancelGesture, object: nil)
        super.viewWillTransition(to: size, with: coordinator)
    }
}
