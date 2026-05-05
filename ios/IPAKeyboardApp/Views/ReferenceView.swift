import SwiftUI
import UIKit
import IPACore

struct ReferenceView: View {
    @State private var debouncer = ClipboardDebouncer()
    @State private var toast: String? = nil
    @State private var hideTask: DispatchWorkItem? = nil

    /// Symbol → example, derived once from the flat SymbolReferenceData.rows.
    private static let exampleBySymbol: [String: String] = Dictionary(
        SymbolReferenceData.rows.map { ($0.symbol, $0.example) },
        uniquingKeysWith: { first, _ in first }
    )

    var body: some View {
        NavigationStack {
            List {
                ForEach(IPAMapping.dottedKeys, id: \.self) { key in
                    let variants = IPAMapping.variants[key] ?? []
                    Section(header: Text("Long-press the \(String(key)) key on the IPA Keyboard")) {
                        ForEach(variants, id: \.self) { symbol in
                            Button(action: { tap(symbol) }) {
                                row(symbol: symbol)
                            }
                            .accessibilityLabel("Copy \(symbol), \(displayName(for: symbol))")
                            .accessibilityHint("Double-tap to copy the symbol to the clipboard")
                        }
                    }
                }
            }
            .navigationTitle("Reference")
        }
        .ipaToast(message: $toast)
    }

    @ViewBuilder
    private func row(symbol: String) -> some View {
        HStack(spacing: 14) {
            Text(symbol)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundColor(.primary)
                .frame(minWidth: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: symbol))
                    .font(.body)
                if let example = Self.exampleBySymbol[symbol], !example.isEmpty {
                    Text(example)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "doc.on.doc")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
    }

    private func displayName(for symbol: String) -> String {
        LocalizedSymbolNames.english[symbol] ?? symbol
    }

    private func tap(_ symbol: String) {
        guard debouncer.accept(value: symbol, at: Date().timeIntervalSinceReferenceDate) else { return }
        UIPasteboard.general.string = symbol
        showToast("Copied \(symbol)")
    }

    private func showToast(_ msg: String) {
        hideTask?.cancel()
        toast = msg
        let task = DispatchWorkItem {
            toast = nil
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }
}
