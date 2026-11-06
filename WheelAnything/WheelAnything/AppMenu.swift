import SwiftUI
import WheelCore

/// The menu bar item's menu: Open Wheel, Settings…, Quit (PLAN.md §2).
struct AppMenu: View {
    let wheel: WheelModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open Wheel") { wheel.send(.openRequested) }
        #if DEBUG
            Button("Settings…") {
                // An agent app must activate itself, or the Settings window opens behind other apps.
                NSApp.activate()
                openSettings()
            }
            .keyboardShortcut(",")
            Menu("Spikes (Debug)") {
                Button("Grant folder access…") { _ = OutputSpike.grantFolder() }
                Button("Test saved folder bookmark") { OutputSpike.useSavedBookmark() }
                Button("Retry write next to last drop (via bookmark)") {
                    OutputSpike.useSavedBookmark(nextTo: lastDroppedURL)
                }
                Button("Test purchase (StoreKit)") { Task { await StoreKitSpike.purchasePro() } }
            }
        #endif
        Divider()
        Button("Quit WheelAnything") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    #if DEBUG
        private var lastDroppedURL: URL? {
            guard case .filesSelected(let selection) = wheel.state else { return nil }
            return selection.files.first?.url ?? selection.rejected.first?.url
        }
    #endif
}
