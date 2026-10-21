import Testing
@testable import GetCaffeinated

struct NetworkCheckTests {
    private let home: Set = ["IPv4.Router=192.168.1.1;IPv4.RouterHardwareAddress=aa:aa:aa:aa:aa:aa"]
    private let office: Set = ["IPv4.Router=10.0.0.1;IPv4.RouterHardwareAddress=bb:bb:bb:bb:bb:bb"]

    @Test func staysOnTheSameNetwork() {
        #expect(NetworkCheck.decide(current: home, start: home) == .stay)
    }

    @Test func staysWhenAnotherNetworkIsAdded() {
        #expect(NetworkCheck.decide(current: home.union(office), start: home) == .stay)
    }

    @Test func staysWhenOneOfTheStartNetworksRemains() {
        #expect(NetworkCheck.decide(current: home, start: home.union(office)) == .stay)
    }

    @Test func leavesOnAnotherNetwork() {
        #expect(NetworkCheck.decide(current: office, start: home) == .leave)
    }

    @Test func waitsWithoutANetwork() {
        #expect(NetworkCheck.decide(current: [], start: home) == .wait)
    }
}
