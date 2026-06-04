import XCTest
@testable import PrimeEyeKit

/// The escalation state machine is the highest-value unit-test target (plan P3): all
/// timing is driven by an injected clock, so every transition is deterministic.
final class WarningCoordinatorTests: XCTestCase {

    func testStaysNoneBeforeGlowDelay() {
        var c = WarningCoordinator()
        XCTAssertEqual(c.update(.slouching, at: 0), .none)
        XCTAssertEqual(c.update(.slouching, at: 4.9), .none)
        XCTAssertEqual(c.nudgeCount, 0)
    }

    func testGlowAtFiveSeconds() {
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        XCTAssertEqual(c.update(.slouching, at: 5), .glow)
        XCTAssertEqual(c.nudgeCount, 1)
    }

    func testMessageAtTwentySeconds() {
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        c.update(.slouching, at: 5)            // glow
        XCTAssertEqual(c.update(.slouching, at: 20), .message)
        XCTAssertEqual(c.nudgeCount, 1, "escalating glow->message is the same episode, one nudge")
    }

    func testRecoveryNeedsSustainedUpright() {
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        c.update(.slouching, at: 5)            // glow
        // Brief straighten (< recoveryHold) holds the glow (hysteresis, no flapping).
        XCTAssertEqual(c.update(.upright, at: 6), .glow)
        XCTAssertEqual(c.update(.upright, at: 8), .glow)
        // Sustained upright >= 3s clears it.
        XCTAssertEqual(c.update(.upright, at: 9), .none)
    }

    func testBriefStraightenDoesNotResetSlouchTimer() {
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        c.update(.slouching, at: 4)            // not yet glow
        c.update(.upright, at: 5)              // brief straighten, < recoveryHold
        // Back to slouch; original slouchStart (0) is preserved, so 5s elapsed -> glow.
        XCTAssertEqual(c.update(.slouching, at: 5.5), .glow)
        XCTAssertEqual(c.nudgeCount, 1)
    }

    func testFullRecoveryThenNewEpisodeCountsSecondNudge() {
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        c.update(.slouching, at: 5)            // glow (nudge 1)
        c.update(.upright, at: 6)
        c.update(.upright, at: 9)              // sustained upright -> none
        XCTAssertEqual(c.stage, .none)
        // New slouch episode.
        c.update(.slouching, at: 20)
        XCTAssertEqual(c.update(.slouching, at: 25), .glow)
        XCTAssertEqual(c.nudgeCount, 2)
    }

    func testUnknownRecoversLikeUpright() {
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        c.update(.slouching, at: 5)            // glow
        // Person leaves frame (unknown) for >= recoveryHold -> glow should clear.
        c.update(.unknown, at: 6)
        XCTAssertEqual(c.update(.unknown, at: 9), .none)
    }

    func testAwayStreamNeverNudges() {
        // No body detected for a long time (user away from the Mac) must never warn.
        var c = WarningCoordinator()
        for t in stride(from: 0.0, through: 120.0, by: 3.0) {
            XCTAssertEqual(c.update(.unknown, at: t), .none)
        }
        XCTAssertEqual(c.nudgeCount, 0)
    }

    func testDirectJumpToMessageCountsOneNudge() {
        // Large gap between samples (e.g. wake from sleep) lands straight past messageDelay.
        var c = WarningCoordinator()
        c.update(.slouching, at: 0)
        XCTAssertEqual(c.update(.slouching, at: 25), .message)
        XCTAssertEqual(c.nudgeCount, 1)
    }
}
