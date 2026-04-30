import Foundation

/// Policy for the first-run coach-mark banner — pulled out of the view layer
/// so the rule is testable. The view consults `shouldShow(forActivationCount:)`
/// every time the keyboard activates and uses `autoDismissDelay` for the
/// auto-fade timer.
public enum CoachMarkPolicy {
    /// Show the banner on the first N keyboard activations.
    public static let showThreshold: Int = 3

    /// Auto-dismiss the banner after this many seconds if the user has not
    /// already dismissed it by tapping a key.
    public static let autoDismissDelay: TimeInterval = 4.0

    /// Returns `true` for activation counts in `1...showThreshold`. Zero or
    /// negative counts (defensive: should not occur in practice) return
    /// `false` so a misread UserDefaults value doesn't repeatedly flash the
    /// banner.
    public static func shouldShow(forActivationCount count: Int) -> Bool {
        (1...showThreshold).contains(count)
    }
}
