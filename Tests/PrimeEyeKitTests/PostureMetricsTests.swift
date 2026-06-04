import XCTest
import CoreGraphics
@testable import PrimeEyeKit

final class PostureMetricsTests: XCTestCase {

    func testMetricsNilWhenFaceTooSmall() {
        XCTAssertNil(PostureMetrics.metrics(faceSize: 0.01, faceCenterY: 0.5))
    }

    func testMetricsFromBoundingBox() {
        let box = CGRect(x: 0.4, y: 0.5, width: 0.2, height: 0.3)  // midY = 0.65, height = 0.3
        let m = PostureMetrics.metrics(faceBoundingBox: box)!
        XCTAssertEqual(m.faceSize, 0.3, accuracy: 1e-9)
        XCTAssertEqual(m.faceCenterY, 0.65, accuracy: 1e-9)
    }

    func testClassifyUprightAtBaseline() {
        let baseline = Baseline(faceSize: 0.30, faceCenterY: 0.60)
        let m = SlouchMetrics(faceSize: 0.30, faceCenterY: 0.60)
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .upright)
    }

    func testClassifySlouchWhenLeaningIn() {
        // Face grew well past baseline (craned toward the screen) -> slouch.
        let baseline = Baseline(faceSize: 0.30, faceCenterY: 0.60)
        let m = SlouchMetrics(faceSize: 0.30 + PostureThresholds.default.sizeDelta + 0.02, faceCenterY: 0.60)
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .slouching)
    }

    func testClassifySlouchWhenHeadDrops() {
        // Face center fell below baseline (head dropped toward the desk) -> slouch.
        let baseline = Baseline(faceSize: 0.30, faceCenterY: 0.60)
        let m = SlouchMetrics(faceSize: 0.30, faceCenterY: 0.60 - PostureThresholds.default.dropDelta - 0.02)
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .slouching)
    }

    func testSmallWobbleStaysUpright() {
        // Movement within the tolerance band must NOT flag (no nagging on tiny shifts).
        let baseline = Baseline(faceSize: 0.30, faceCenterY: 0.60)
        let m = SlouchMetrics(faceSize: 0.31, faceCenterY: 0.59)
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .upright)
    }
}
