import SwiftUI
import UIKit
import IPACore

struct SetupView: View {
    @EnvironmentObject var state: AppState
    @State private var showingTroubleshooting = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !state.hasConfirmedSetup {
                            header
                            instructions
                            Divider()
                            tryItField
                            iveDoneThisButton
                        } else {
                            collapsedBanner
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 180) // room for sticky CTA
                }
                stickyCTA
            }
        }
        .sheet(isPresented: $showingTroubleshooting) {
            TroubleshootingSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STEP 1 OF 1 · ACTIVATE KEYBOARD")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .tracking(0.8)
            Text("Enable IPA Keyboard")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Follow these steps in the Settings app:")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 16) {
            instructionRow(n: 1, text: "Open Settings")
            instructionRow(n: 2, text: "Go to General → Keyboard → Keyboards")
            instructionRow(n: 3, text: "Tap \"Add New Keyboard…\" → IPA Keyboard")
        }
    }

    private func instructionRow(n: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .accessibilityLabel("Step \(n). \(text)")
            Spacer()
        }
    }

    private var tryItField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it here")
                .font(.headline)
            TextField("", text: Binding(
                get: { state.testFieldText },
                set: { state.noteTextFieldChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .serif))
            .autocorrectionDisabled(true)
            .accessibilityLabel("Test keyboard input")

            Text(helperText)
                .font(.footnote)
                .foregroundColor(helperColor)
                .animation(.easeIn(duration: 0.2), value: state.sawIpaCharacterInTestField)
        }
    }

    private var helperText: String {
        state.sawIpaCharacterInTestField
            ? "Looks like it’s working ✓"
            : "Tap the globe 🌐 to switch to IPA Keyboard"
    }

    private var helperColor: Color {
        state.sawIpaCharacterInTestField ? .green : .secondary
    }

    private var iveDoneThisButton: some View {
        Button("I’ve done this") {
            state.confirmSetup()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private var collapsedBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 28))
                Text("Setup complete — keyboard ready to use")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Button("Show steps again") { state.showStepsAgain() }
                .buttonStyle(.bordered)
        }
    }

    private var stickyCTA: some View {
        VStack(spacing: 10) {
            Divider()
            Button {
                openSettings()
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)

            Button("Keyboard not appearing in Settings? →") {
                showingTroubleshooting = true
            }
            .font(.footnote)
            .padding(.bottom, 12)
        }
        .background(.thinMaterial)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok {
                // Spec §7.2: alert fallback if openSettings fails.
                let alert = UIAlertController(
                    title: "Couldn't open Settings",
                    message: "Please open Settings manually and go to General → Keyboard → Keyboards.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                if let root = UIApplication.shared.connectedScenes
                    .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                    .first {
                    root.present(alert, animated: true)
                }
            }
        }
    }
}
