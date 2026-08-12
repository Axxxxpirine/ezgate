import SwiftUI

@main
struct EZgateApp: App {
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        Task { @MainActor in await model.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(model)
        } label: {
            Label("EZgate", systemImage: model.filteringPaused ? "network.slash" : "network")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .frame(minWidth: 680, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
    }
}
