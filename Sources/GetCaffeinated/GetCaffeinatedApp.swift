import LidAwakeShared
import SwiftUI

@main
struct GetCaffeinatedApp: App {
    @StateObject private var keeper = AwakeKeeper()
    @StateObject private var menu = MenuOpening()

    var body: some Scene {
        MenuBarExtra {
            if keeper.staysAwakeWithLidClosed, let until = keeper.activeUntil {
                Text("Awake with lid closed until \(label(for: until))")
            } else if let until = keeper.activeUntil {
                Text("Awake until \(label(for: until))")
            } else if keeper.endsWhenUnplugged {
                Text("Awake until unplugged")
            } else if keeper.endsWhenLidCloses {
                Text("Awake until the lid closes")
            } else if keeper.endsOnLeavingNetwork {
                Text("Awake until you leave this network")
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
                let times = UntilTimes.times(from: menu.openedAt)
                let today = times.filter { !isTomorrow($0) }
                let tomorrow = times.filter(isTomorrow)
                ForEach(today, id: \.self, content: untilButton)
                if !tomorrow.isEmpty {
                    if !today.isEmpty { Divider() }
                    Text("Tomorrow")
                    ForEach(tomorrow, id: \.self, content: untilButton)
                }
            }
            if PowerSource.hasBattery {
                Button("Until unplugged") { keeper.startUntilUnplugged() }
                    .disabled(!PowerSource.isOnAC)
            }
            if Lid.exists {
                Button("Until lid closed") { keeper.startUntilLidClosed() }
                    .disabled(Lid.isClosed)
            }
            Button("Until I leave") { keeper.startUntilLeavingNetwork() }
                .disabled(NetworkSignature.current.isEmpty)
            Button("Indefinitely") { keeper.start(for: nil) }
            if LidAwakeClient.isAvailable {
                // A session of its own, never open-ended: the Mac will not
                // sleep in a closed bag, so it always runs on a short timer.
                Divider()
                Menu("Awake with lid closed") {
                    ForEach(LidAwake.menuMinutes, id: \.self) { minutes in
                        Button("\(minutes) minutes") {
                            Task { await keeper.startLidClosed(minutes: minutes) }
                        }
                    }
                }
            }
            Divider()
            Toggle("Keep screen on", isOn: $keeper.keepsScreenOn)
            Toggle("Launch at login", isOn: Binding(
                get: { LoginItem.isEnabled },
                set: { LoginItem.setEnabled($0) }
            ))
            Divider()
            Button("Stop") { keeper.stop() }
                .disabled(!keeper.isActive)
            Divider()
            Button("Quit Get Caffeinated") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(nsImage: keeper.isActive ? MenuBarIcon.awake : MenuBarIcon.idle)
        }
    }

    private func untilButton(_ time: Date) -> some View {
        Button(time.formatted(date: .omitted, time: .shortened)) {
            keeper.start(until: time)
        }
    }

    /// Whether `date` falls on a later day than the moment the menu opened.
    /// Sessions last at most 8 hours, so that can only be tomorrow.
    private func isTomorrow(_ date: Date) -> Bool {
        !Calendar.current.isDate(date, inSameDayAs: menu.openedAt)
    }

    /// "17:30", or "00:30 tomorrow" after midnight.
    private func label(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        return isTomorrow(date) ? "\(time) tomorrow" : time
    }
}
