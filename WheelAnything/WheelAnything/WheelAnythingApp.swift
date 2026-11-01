//
//  WheelAnythingApp.swift
//  WheelAnything
//
//  Created by Harshit  Pareek on 28/10/26.
//

import SwiftUI
import WheelCore

#if DEBUG
    import Carbon.HIToolbox
#endif

@main
struct WheelAnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    #if DEBUG
        init() {
            // Stage 0 headless spikes run with `-spike <name>` and exit before any UI appears.
            SpikeRunner.runHeadlessSpikeIfRequested()
        }
    #endif

    var body: some Scene {
        // The app has no Dock icon (LSUIElement), so the menu bar item is how users reach
        // Open Wheel, Settings and Quit (PLAN.md §2).
        MenuBarExtra("WheelAnything", systemImage: "circle.lefthalf.filled") {
            AppMenu(wheel: appDelegate.wheel)
        }
        #if DEBUG
            // Release builds have no Settings window until it has real content (step 14).
            Settings {
                Text("Settings: not built yet (Stage 1 step 14).")
                    .padding(40)
            }
        #endif
    }
}

/// Owns the app's long-lived objects and starts the pill panel at launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let wheel = WheelModel(catalog: ActionCatalog(entitlements: FreeTierEntitlements()), detector: FileDetector())
    private var pillPanel: PillPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let pillPanel = PillPanelController(model: wheel)
        pillPanel.show()
        self.pillPanel = pillPanel
        #if DEBUG
            // Stage 0 hot-key spike until the real shortcut service lands (step 13).
            HotKeySpike.onPress = { [weak wheel] _ in wheel?.send(.openRequested) }
            HotKeySpike.register(
                id: 1, keyCode: kVK_ANSI_W, modifiers: cmdKey | optionKey | controlKey, label: "⌃⌥⌘W")
        #endif
    }
}
