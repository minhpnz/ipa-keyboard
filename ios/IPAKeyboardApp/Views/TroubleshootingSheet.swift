import SwiftUI

struct TroubleshootingSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Keyboard not appearing in Settings?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)

                    bullet("Make sure you’re on iOS 17 or later. IPA Keyboard requires iOS 17+ — check Settings → General → About.")
                    bullet("Fully quit the Settings app (swipe up from the bottom and flick Settings away), then reopen it. iOS sometimes caches the keyboards list.")
                    bullet("Restart your iPhone. After a fresh install, iOS can take a moment to register the new keyboard extension.")
                    bullet("Still not working? Delete IPA Keyboard, reinstall from the App Store, and try again.")

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•").font(.body)
            Text(text).font(.body).multilineTextAlignment(.leading)
        }
    }
}

#Preview { TroubleshootingSheet() }
