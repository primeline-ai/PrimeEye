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
        acc.add(SlouchMetrics(faceSize: 0.30, faceCenterY: 0.60))
        acc.add(SlouchMetrics(faceSize: 0.32, faceCenterY: 0.62))
        acc.add(SlouchMetrics(faceSize: 0.34, faceCenterY: 0.64))
        let b = acc.baseline()!
        XCTAssertEqual(b.faceSize, 0.32, accuracy: 1e-9)
        XCTAssertEqual(b.faceCenterY, 0.62, accuracy: 1e-9)
        XCTAssertTrue(acc.isReady)
    }

    func testIsReadyTracksMinSamples() {
        var acc = CalibrationAccumulator(minSamples: 2)
        acc.add(SlouchMetrics(faceSize: 0.3, faceCenterY: 0.6))
        XCTAssertFalse(acc.isReady)
        acc.add(SlouchMetrics(faceSize: 0.3, faceCenterY: 0.6))
        XCTAssertTrue(acc.isReady)
    }
}
