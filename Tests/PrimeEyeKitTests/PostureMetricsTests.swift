import XCTest
import CoreGraphics
@testable import PrimeEyeKit

final class PostureMetricsTests: XCTestCase {

    // Helper: an "upright" pose - ears well above shoulders, head centered.
    private func uprightJoints() -> PostureJoints {
        PostureJoints(
            leftEar: CGPoint(x: 0.45, y: 0.80),
            rightEar: CGPoint(x: 0.55, y: 0.80),
            leftShoulder: CGPoint(x: 0.35, y: 0.50),
            rightShoulder: CGPoint(x: 0.65, y: 0.50)
        )
    }

    func testMetricsNilWhenShouldersMissing() {
        let j = PostureJoints(leftEar: CGPoint(x: 0.5, y: 0.8))
        XCTAssertNil(PostureMetrics.metrics(from: j))
    }

    func testMetricsNilWhenEarsMissing() {
        let j = PostureJoints(
            leftShoulder: CGPoint(x: 0.35, y: 0.5),
            rightShoulder: CGPoint(x: 0.65, y: 0.5)
        )
        XCTAssertNil(PostureMetrics.metrics(from: j))
    }

    func testMetricsNilWhenShouldersCoincide() {
        let j = PostureJoints(
            leftEar: CGPoint(x: 0.5, y: 0.8),
            rightEar: CGPoint(x: 0.5, y: 0.8),
            leftShoulder: CGPoint(x: 0.5, y: 0.5),
            rightShoulder: CGPoint(x: 0.5, y: 0.5)  // zero width -> untrustworthy
        )
        XCTAssertNil(PostureMetrics.metrics(from: j))
    }

    func testOneEarIsEnough() {
        let j = PostureJoints(
            leftEar: CGPoint(x: 0.45, y: 0.80),
            leftShoulder: CGPoint(x: 0.35, y: 0.50),
            rightShoulder: CGPoint(x: 0.65, y: 0.50)
        )
        XCTAssertNotNil(PostureMetrics.metrics(from: j))
    }

    func testUprightMetricsAreScaleInvariant() {
        // Same pose, person twice as close (all coords scaled about center) -> same metrics.
        let near = uprightJoints()
        func scaled(_ p: CGPoint, by k: CGFloat) -> CGPoint {
            CGPoint(x: 0.5 + (p.x - 0.5) * k, y: 0.5 + (p.y - 0.5) * k)
        }
        let far = PostureJoints(
            leftEar: scaled(CGPoint(x: 0.45, y: 0.80), by: 0.5),
            rightEar: scaled(CGPoint(x: 0.55, y: 0.80), by: 0.5),
            leftShoulder: scaled(CGPoint(x: 0.35, y: 0.50), by: 0.5),
            rightShoulder: scaled(CGPoint(x: 0.65, y: 0.50), by: 0.5)
        )
        let mNear = PostureMetrics.metrics(from: near)!
        let mFar = PostureMetrics.metrics(from: far)!
        XCTAssertEqual(mNear.slump, mFar.slump, accuracy: 1e-9)
        XCTAssertEqual(mNear.forwardHead, mFar.forwardHead, accuracy: 1e-9)
    }

    func testClassifyUprightAtBaseline() {
        let m = PostureMetrics.metrics(from: uprightJoints())!
        let baseline = Baseline(forwardHead: m.forwardHead, slump: m.slump)
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .upright)
    }

    func testClassifySlouchWhenHeadDrops() {
        let baselineMetrics = PostureMetrics.metrics(from: uprightJoints())!
        let baseline = Baseline(forwardHead: baselineMetrics.forwardHead, slump: baselineMetrics.slump)
        // Head dropped: ears much closer to shoulders vertically -> slump shrinks.
        let slouched = PostureJoints(
            leftEar: CGPoint(x: 0.45, y: 0.56),
            rightEar: CGPoint(x: 0.55, y: 0.56),
            leftShoulder: CGPoint(x: 0.35, y: 0.50),
            rightShoulder: CGPoint(x: 0.65, y: 0.50)
        )
        let m = PostureMetrics.metrics(from: slouched)!
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .slouching)
    }

    func testClassifySlouchWhenHeadLeans() {
        let baselineMetrics = PostureMetrics.metrics(from: uprightJoints())!
        let baseline = Baseline(forwardHead: baselineMetrics.forwardHead, slump: baselineMetrics.slump)
        // Head leaned far to one side: ear midpoint x shifts well past the shoulder midpoint.
        let leaned = PostureJoints(
            leftEar: CGPoint(x: 0.70, y: 0.80),
            rightEar: CGPoint(x: 0.80, y: 0.80),
            leftShoulder: CGPoint(x: 0.35, y: 0.50),
            rightShoulder: CGPoint(x: 0.65, y: 0.50)
        )
        let m = PostureMetrics.metrics(from: leaned)!
        XCTAssertEqual(PostureMetrics.classify(m, baseline: baseline), .slouching)
    }
}
