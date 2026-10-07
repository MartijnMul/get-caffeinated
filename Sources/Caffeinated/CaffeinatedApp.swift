import SwiftUI

@main
struct CaffeinatedApp: App {
    @StateObject private var keeper = AwakeKeeper()
    @StateObject private var loginItem = LoginItem()
    @StateObject private var untilTimes = UntilTimes()

    var body: some Scene {
        MenuBarExtra {
            if let until = keeper.activeUntil {
                Text("Awake until \(until.formatted(date: .omitted, time: .shortened))")
            } else if keeper.isActive {
                Text("Awake indefinitely")
            } else {
                Text("Not caffeinated")
            }
            Divider()
            Button("15 minutes") { keeper.start(for: 15 * 60) }
            Button("1 hour") { keeper.start(for: 60 * 60) }
            Button("3 hours") { keeper.start(for: 3 * 60 * 60) }
            Button("8 hours") { keeper.start(for: 8 * 60 * 60) }
            Menu("Until") {
                ForEach(untilTimes.times, id: \.self) { time in
                    Button(time.formatted(date: .omitted, time: .shortened)) {
                        keeper.start(until: time)
                    }
                }
            }
            Button("Indefinitely") { keeper.start(for: nil) }
            Divider()
            Toggle("Keep screen on", isOn: $keeper.keepsScreenOn)
            Toggle("Launch at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            Divider()
            Button("Stop") { keeper.stop() }
                .disabled(!keeper.isActive)
            Divider()
            Button("Quit Caffeinated") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(nsImage: keeper.isActive ? MenuBarIcon.awake : MenuBarIcon.idle)
        }
    }
}
