import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("IPA Keyboard") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("AppVersionValue")
                    }
                }
                Section("Privacy") {
                    Text("This app collects no data. It works entirely offline. No accounts, no analytics, no network.")
                        .font(.body)
                }
                Section("Open-source licenses") {
                    Text("No third-party code ships in IPA Keyboard.")
                        .font(.body)
                }
            }
            .navigationTitle("About")
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
