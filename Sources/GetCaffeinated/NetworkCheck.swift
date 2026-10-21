/// What "Until I leave" does when the network changes, apart from the timers
/// and system calls around it so it can be tested.
enum NetworkCheck: Equatable {
    /// Still on a network the session started on.
    case stay
    /// On another network: end the session straight away.
    case leave
    /// No network at all: wait for the grace period, in case the old one
    /// comes back.
    case wait

    static func decide(current: Set<String>, start: Set<String>) -> NetworkCheck {
        if !current.isDisjoint(with: start) { return .stay }
        return current.isEmpty ? .wait : .leave
    }
}
