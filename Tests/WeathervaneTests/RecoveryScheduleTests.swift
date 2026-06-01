import XCTest
@testable import Weathervane

final class RecoveryScheduleTests: XCTestCase {
    func testRecoveryDelayBacksOffExponentially() {
        XCTAssertEqual(WeathervaneState.recoveryDelay(forAttempt: 0), 30)
        XCTAssertEqual(WeathervaneState.recoveryDelay(forAttempt: 1), 60)
        XCTAssertEqual(WeathervaneState.recoveryDelay(forAttempt: 2), 120)
    }
}
