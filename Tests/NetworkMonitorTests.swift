import XCTest
@testable import MiniMax_Status_Bar

final class NetworkMonitorTests: XCTestCase {
    func testDoesNotFireOnInitialSatisfied() {
        let sut = NetworkMonitor()
        let exp = expectation(description: "should not fire")
        exp.isInverted = true

        sut.handleStatusChange(satisfied: true, onReachabilityRestored: { exp.fulfill() })
        wait(for: [exp], timeout: 0.2)
    }

    func testFiresWhenRestoredFromUnsatisfiedToSatisfied() {
        let sut = NetworkMonitor()
        let exp = expectation(description: "should fire")

        sut.handleStatusChange(satisfied: false, onReachabilityRestored: { exp.fulfill() }) // initial
        sut.handleStatusChange(satisfied: true, onReachabilityRestored: { exp.fulfill() })  // restored

        wait(for: [exp], timeout: 0.5)
    }

    func testDoesNotFireWhenStillUnsatisfied() {
        let sut = NetworkMonitor()
        let exp = expectation(description: "should not fire")
        exp.isInverted = true

        sut.handleStatusChange(satisfied: false, onReachabilityRestored: { exp.fulfill() }) // initial
        sut.handleStatusChange(satisfied: false, onReachabilityRestored: { exp.fulfill() }) // still down

        wait(for: [exp], timeout: 0.2)
    }
}

