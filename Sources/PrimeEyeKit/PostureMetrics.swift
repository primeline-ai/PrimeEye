import Foundation
import CoreGraphics

/// Pure posture geometry: face rectangle -> metrics -> classification.
/// No AVFoundation, no Vision - fully unit-testable with synthetic values.
public enum PostureMetrics {

    /// Minimum face height to trust a reading - guards against a spurious tiny detection.
    public static let minFaceSize: Double = 0.02

    /// Build metrics from a detected face bounding box (Vision-normalized, origin bottom-left),
    /// or nil if the box is too small to trust.
    public static func metrics(faceSize: Double, faceCenterY: Double) -> SlouchMetrics? {
        guard faceSize >= minFaceSize else { return nil }
        return SlouchMetrics(faceSize: faceSize, faceCenterY: faceCenterY)
    }

    /// Convenience overload taking the raw normalized bounding box.
    public static func metrics(faceBoundingBox box: CGRect) -> SlouchMetrics? {
        metrics(faceSize: Double(box.height), faceCenterY: Double(box.midY))
    }

    /// Classify one frame against the calibrated upright baseline.
    /// Slouch = leaned in (face grew past baseline) OR head dropped (center fell below baseline).
    public static func classify(
        _ m: SlouchMetrics,
        baseline: Baseline,
        thresholds: PostureThresholds = .default
    ) -> PostureState {
        let leanedIn = m.faceSize > baseline.faceSize + thresholds.sizeDelta
        let dropped = m.faceCenterY < baseline.faceCenterY - thresholds.dropDelta
        return (leanedIn || dropped) ? .slouching : .upright
    }
}
