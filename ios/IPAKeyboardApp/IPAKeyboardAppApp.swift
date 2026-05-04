import SwiftUI

@main
struct IPAKeyboardAppApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ResetSetupForUITests") {
            let d = UserDefaults.standard
            d.removeObject(forKey: AppState.Keys.hasConfirmedSetup)
            d.removeObject(forKey: AppState.Keys.sawIpaCharacterInTestField)
        }
    }
    var body: some Scene {
        WindowGroup { RootTabView() }
    }
}
