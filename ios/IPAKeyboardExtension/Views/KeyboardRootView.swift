import SwiftUI
import IPACore

struct KeyboardRootView: View {

    /// Called with the literal string to insert into the host text field.
    let onInsertText: (String) -> Void
    /// Called for backspace.
    let onDeleteBackward: () -> Void
    /// Called to advance to the next keyboard (globe button).
    let onAdvanceInputMode: () -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemGray6)
            Text("alpha layer WIP")
        }
    }
}
