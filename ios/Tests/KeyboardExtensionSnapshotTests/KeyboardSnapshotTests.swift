import XCTest
import SwiftUI
import SnapshotTesting
import IPACore

final class KeyboardSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // isRecording = true    // Uncomment temporarily to regenerate baselines.
    }

    private func root() -> some View {
        KeyboardRootView(
            onInsertText: { _ in },
            onDeleteBackward: {},
            onAdvanceInputMode: {}
        )
    }

    func test_iPhone15_portrait_light() {
        let view = root().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPhone15_portrait_dark() {
        let view = root().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .dark)))
    }

    func test_iPhoneSE_portrait_light() {
        let view = root().frame(width: 320, height: 216)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhoneSe, traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPhone15_landscape_light() {
        let view = root().frame(width: 852, height: 200)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13(.landscape),
                                  traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPad_portrait_light() {
        let view = root().frame(width: 820, height: 320)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPadMini, traits: .init(userInterfaceStyle: .light)))
    }

    func test_iPad_floatingWidth_light() {
        let view = root().frame(width: 320, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(size: CGSize(width: 320, height: 260),
                                  traits: .init(userInterfaceStyle: .light)))
    }

    // MARK: - Numbers / symbols layers

    private func numbers() -> some View {
        NumbersLayerView(
            onInsertText: { _ in },
            onDeleteBackward: {},
            onSwitchToAlpha: {},
            onSwitchToSymbols: {}
        )
    }

    private func symbols() -> some View {
        SymbolsLayerView(
            onInsertText: { _ in },
            onDeleteBackward: {},
            onSwitchToAlpha: {},
            onSwitchToNumbers: {}
        )
    }

    func test_numbers_iPhone15_light() {
        let view = numbers().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    func test_numbers_iPhone15_dark() {
        let view = numbers().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .dark)))
    }

    func test_numbers_iPad_portrait_light() {
        let view = numbers().frame(width: 820, height: 320)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPadMini, traits: .init(userInterfaceStyle: .light)))
    }

    func test_symbols_iPhone15_light() {
        let view = symbols().frame(width: 393, height: 260)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .light)))
    }

    func test_symbols_iPad_portrait_light() {
        let view = symbols().frame(width: 820, height: 320)
        assertSnapshot(of: UIHostingController(rootView: view),
                       as: .image(on: .iPadMini, traits: .init(userInterfaceStyle: .light)))
    }
}
