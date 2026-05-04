import Foundation
import Combine
import IPACore

enum Tab: String {
    case setup, reference, about
}

final class AppState: ObservableObject {
    @Published private(set) var hasConfirmedSetup: Bool
    @Published private(set) var sawIpaCharacterInTestField: Bool
    @Published var testFieldText: String = ""    // bound by SetupView

    private let defaults: UserDefaults

    enum Keys {
        static let hasConfirmedSetup = "ipa.hasConfirmedSetup"
        static let sawIpaCharacterInTestField = "ipa.sawIpaCharacterInTestField"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasConfirmedSetup = defaults.bool(forKey: Keys.hasConfirmedSetup)
        self.sawIpaCharacterInTestField = defaults.bool(forKey: Keys.sawIpaCharacterInTestField)
    }

    var defaultTab: Tab {
        hasConfirmedSetup ? .reference : .setup
    }

    func confirmSetup() {
        hasConfirmedSetup = true
        defaults.set(true, forKey: Keys.hasConfirmedSetup)
        defaults.synchronize()
    }

    func showStepsAgain() {
        hasConfirmedSetup = false
        defaults.set(false, forKey: Keys.hasConfirmedSetup)
        defaults.synchronize()
    }

    func noteTextFieldChanged(_ text: String) {
        testFieldText = text
        if !sawIpaCharacterInTestField && SymbolDetector.containsIPA(text) {
            sawIpaCharacterInTestField = true
            defaults.set(true, forKey: Keys.sawIpaCharacterInTestField)
        }
    }
}
