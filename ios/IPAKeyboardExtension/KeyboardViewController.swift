import UIKit

final class KeyboardViewController: UIInputViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.text = "IPA Keyboard (stub)"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: 260)
        ])
    }
}
