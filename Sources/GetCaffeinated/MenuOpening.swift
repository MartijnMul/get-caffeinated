import AppKit

/// Publishes the moment the menu opens. SwiftUI builds a menu bar menu once
/// and does not rebuild it on opening, so anything that changes on its own
/// (the time, the login item state in System Settings) would go stale.
/// Publishing here makes SwiftUI rebuild the menu before it is shown.
@MainActor
final class MenuOpening: ObservableObject {
    @Published private(set) var openedAt = Date()

    private var observer: NSObjectProtocol?

    init() {
        // No queue: the block runs right away on the main thread, before the
        // menu is drawn, instead of waiting for the next run loop pass.
        observer = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.openedAt = Date() }
        }
    }
}
