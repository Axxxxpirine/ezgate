import SwiftUI

@main
struct EZgateApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(model)
                .task { await model.start() }
        } label: {
            Label("EZgate", systemImage: model.filteringPaused ? "network.slash" : "network")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .frame(minWidth: 680, minHeight: 480)
                .task { await model.start() }
        }
        .windowResizability(.contentMinSize)
    }
}

