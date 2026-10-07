import SwiftUI

@main
struct CaffeinatedApp: App {
    @StateObject private var keeper = AwakeKeeper()

    var body: some Scene {
        MenuBarExtra("Caffeinated", systemImage: keeper.isActive ? "cup.and.saucer.fill" : "cup.and.saucer") {
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
            Button("Indefinitely") { keeper.start(for: nil) }
            Divider()
            Button("Stop") { keeper.stop() }
                .disabled(!keeper.isActive)
            Divider()
            Button("Quit Caffeinated") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
