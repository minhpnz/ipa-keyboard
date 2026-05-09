import SwiftUI

@main
struct IPAKeyboardAppApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-ResetSetupForUITests") {
            let d = UserDefaults.standard
            d.removeObject(forKey: AppState.Keys.hasConfirmedSetup)
            d.removeObject(forKey: AppState.Keys.sawIpaCharacterInTestField)
        }
        if ProcessInfo.processInfo.arguments.contains("-SkipSetupForUITests") {
            UserDefaults.standard.set(true, forKey: AppState.Keys.hasConfirmedSetup)
        }
    }
    var body: some Scene {
        WindowGroup { RootTabView() }
    }
}
