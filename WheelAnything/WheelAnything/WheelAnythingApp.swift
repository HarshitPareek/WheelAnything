//
//  WheelAnythingApp.swift
//  WheelAnything
//
//  Created by Harshit  Pareek on 28/10/26.
//

import SwiftUI
import WheelCore

@main
struct WheelAnythingApp: App {
    #if DEBUG
    // Stage 0 feasibility spikes (Spikes/). Debug builds only; replaced by the real
    // app shell in Stage 1.
    @NSApplicationDelegateAdaptor(SpikeAppDelegate.self) private var spikeDelegate

    init() {
        SpikeRunner.runHeadlessSpikeIfRequested()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
