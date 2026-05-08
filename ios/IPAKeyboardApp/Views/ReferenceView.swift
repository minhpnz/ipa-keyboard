import SwiftUI
import IPACore

struct ReferenceView: View {
    @StateObject private var controller = ToastController()

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
                            Button(action: { controller.copy(symbol) }) {
                                row(symbol: symbol)
                            }
                            .accessibilityLabel("\(symbol), \(displayName(for: symbol))")
                            .accessibilityHint("Copies the symbol to the clipboard")
                        }
                    }
                }
            }
            .navigationTitle("Reference")
        }
        .ipaToast(message: controller.message)
    }

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
}
