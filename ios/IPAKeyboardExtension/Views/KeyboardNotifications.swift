import Foundation

extension Notification.Name {
    /// Posted by `KeyboardViewController` on lifecycle events that should
    /// cancel any in-flight long-press gesture (rotation, dismiss, Control
    /// Center, etc.). `KeyboardRootView` observes this and clears popover +
    /// touch state.
    ///
    /// Lives in `Views/` so the snapshot-test target — which compiles only
    /// `Views/` and `Services/`, not the VC — can see the symbol when it
    /// builds `KeyboardRootView`.
    static let ipaKeyboardShouldCancelGesture = Notification.Name("ipa.gesture.cancel")
}
