import SwiftUI

struct RootTabView: View {
    @StateObject private var state = AppState()
    @State private var selection: IPAKeyboardApp.Tab = .setup

    var body: some View {
        TabView(selection: $selection) {
            SetupView()
                .environmentObject(state)
                .tabItem { Label("Setup", systemImage: "checklist") }
                .tag(IPAKeyboardApp.Tab.setup)

            ReferenceView()
                .environmentObject(state)
                .tabItem { Label("Reference", systemImage: "text.book.closed") }
                .tag(IPAKeyboardApp.Tab.reference)

            AboutView()
                .environmentObject(state)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(IPAKeyboardApp.Tab.about)
        }
        .onAppear { selection = state.defaultTab }
    }
}

#Preview { RootTabView() }
