import UIKit

final class HapticsService {
    static let shared = HapticsService()
    private init() {}
    private let generator = UISelectionFeedbackGenerator()
    private var isAvailable: Bool {
        // Low Power Mode and older hardware quietly no-op.
        !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    func selection() {
        guard isAvailable else { return }
        generator.selectionChanged()
    }
}
