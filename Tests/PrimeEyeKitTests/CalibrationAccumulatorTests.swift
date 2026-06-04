import XCTest
@testable import PrimeEyeKit

final class CalibrationAccumulatorTests: XCTestCase {

    func testBaselineNilWithNoSamples() {
        let acc = CalibrationAccumulator()
        XCTAssertNil(acc.baseline())
        XCTAssertFalse(acc.isReady)
    }

    func testBaselineIsMeanOfSamples() {
        var acc = CalibrationAccumulator(minSamples: 3)
        acc.add(SlouchMetrics(forwardHead: 0.0, slump: 1.0))
        acc.add(SlouchMetrics(forwardHead: 0.2, slump: 1.2))
        acc.add(SlouchMetrics(forwardHead: 0.4, slump: 1.4))
        let b = acc.baseline()!
        XCTAssertEqual(b.forwardHead, 0.2, accuracy: 1e-9)
        XCTAssertEqual(b.slump, 1.2, accuracy: 1e-9)
        XCTAssertTrue(acc.isReady)
    }

    func testIsReadyTracksMinSamples() {
        var acc = CalibrationAccumulator(minSamples: 2)
        acc.add(SlouchMetrics(forwardHead: 0, slump: 1))
        XCTAssertFalse(acc.isReady)
        acc.add(SlouchMetrics(forwardHead: 0, slump: 1))
        XCTAssertTrue(acc.isReady)
    }

    func testSuggestedThresholdsNilBelowTwoSamples() {
        var acc = CalibrationAccumulator()
        acc.add(SlouchMetrics(forwardHead: 0, slump: 1))
        XCTAssertNil(acc.suggestedThresholds())
    }

    func testSuggestedThresholdsNeverBelowFloor() {
        // Zero variance (identical samples) -> thresholds clamp to the floor.
        var acc = CalibrationAccumulator()
        for _ in 0..<10 { acc.add(SlouchMetrics(forwardHead: 0.1, slump: 1.0)) }
        let t = acc.suggestedThresholds(k: 3, floor: .default)!
        XCTAssertEqual(t.forwardHeadDelta, PostureThresholds.default.forwardHeadDelta, accuracy: 1e-9)
        XCTAssertEqual(t.slumpDelta, PostureThresholds.default.slumpDelta, accuracy: 1e-9)
    }

    func testSuggestedThresholdsWidenWithJitter() {
        // High variance on the slump axis -> slump threshold rises above the floor.
        var acc = CalibrationAccumulator()
        acc.add(SlouchMetrics(forwardHead: 0.1, slump: 0.4))
        acc.add(SlouchMetrics(forwardHead: 0.1, slump: 1.6))
        let t = acc.suggestedThresholds(k: 3, floor: .default)!
        XCTAssertGreaterThan(t.slumpDelta, PostureThresholds.default.slumpDelta)
    }
}
