import Foundation
import CoreGraphics

/// Pure posture geometry: joints -> scale-invariant metrics -> classification.
/// No AVFoundation, no Vision - fully unit-testable with synthetic coordinates.
public enum PostureMetrics {

    /// Minimum normalized shoulder width to trust a reading. Guards against degenerate
    /// near-zero widths (e.g. a side-on or barely-detected torso) that would explode the
    /// normalized ratios into nonsense.
    public static let minShoulderWidth: Double = 0.02

    /// Compute scale-invariant metrics from joints, or `nil` when the inputs are
    /// insufficient: both shoulders are required, at least one ear is required, and the
    /// shoulders must be more than `minShoulderWidth` apart.
    public static func metrics(from j: PostureJoints) -> SlouchMetrics? {
        guard let ls = j.leftShoulder, let rs = j.rightShoulder else { return nil }
        guard let earMid = midpoint(j.leftEar, j.rightEar) else { return nil }

        let shoulderMid = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
        let width = Double(hypot(ls.x - rs.x, ls.y - rs.y))
        guard width >= minShoulderWidth else { return nil }

        let forwardHead = Double(earMid.x - shoulderMid.x) / width
        let slump = Double(earMid.y - shoulderMid.y) / width
        return SlouchMetrics(forwardHead: forwardHead, slump: slump)
    }

    /// Classify one frame's metrics against the calibrated baseline.
    /// Slouch = head dropped (slump below baseline) OR head leaned (forwardHead off baseline).
    public static func classify(
        _ m: SlouchMetrics,
        baseline: Baseline,
        thresholds: PostureThresholds = .default
    ) -> PostureState {
        let slumpBad = m.slump < baseline.slump - thresholds.slumpDelta
        let leanBad = abs(m.forwardHead - baseline.forwardHead) > thresholds.forwardHeadDelta
        return (slumpBad || leanBad) ? .slouching : .upright
    }

    /// Midpoint of up to two optional points: nil if both nil, the single one if one nil.
    private static func midpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (a?, b?): return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil):    return nil
        }
    }
}
