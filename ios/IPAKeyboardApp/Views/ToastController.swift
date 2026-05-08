import Foundation
import UIKit
import IPACore

@MainActor
final class ToastController: ObservableObject {
    static let toastDuration: TimeInterval = 2.0

    @Published private(set) var message: String?

    private var debouncer = ClipboardDebouncer()
    private var hideTask: Task<Void, Never>?

    func copy(_ symbol: String) {
        guard debouncer.accept(value: symbol, at: Date().timeIntervalSinceReferenceDate) else {
            return
        }
        UIPasteboard.general.string = symbol
        show("Copied \(symbol)")
    }

    private func show(_ msg: String) {
        hideTask?.cancel()
        message = msg
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.toastDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
