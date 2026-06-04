import CoreGraphics

/// Scale/position posture metrics derived from the detected FACE rectangle - the only thing
/// a MacBook camera reliably sees at desk distance. Body-pose was dropped: at a laptop the
/// torso is out of frame, so shoulders are never detected (measured: 0/57 frames).
///
/// Unlike the old shoulder metric, these are deliberately NOT scale-invariant - distance IS
/// the signal: as you slump/crane toward the screen your face grows and drops in the frame.
public struct SlouchMetrics: Equatable, Sendable, Codable {
    /// Face bounding-box height, 0...1 of frame. Bigger = you leaned in / craned forward.
    public var faceSize: Double
    /// Face bounding-box vertical center, 0...1 (Vision origin bottom-left, so higher = head up).
    /// Smaller = head dropped toward the desk.
    public var faceCenterY: Double

    public init(faceSize: Double, faceCenterY: Double) {
        self.faceSize = faceSize
        self.faceCenterY = faceCenterY
    }
}

/// Calibrated upright reference for one user (mean face geometry while sitting up straight).
public struct Baseline: Equatable, Sendable, Codable {
    public var faceSize: Double
    public var faceCenterY: Double

    public init(faceSize: Double, faceCenterY: Double) {
        self.faceSize = faceSize
        self.faceCenterY = faceCenterY
    }
}

/// How far from baseline counts as a slouch. Fixed, sensible defaults (not variance-derived)
/// so the warning fires promptly - calibration sets the baseline, these set the sensitivity.
public struct PostureThresholds: Equatable, Sendable, Codable {
    /// How much the face may GROW (lean-in) past baseline before flagging. Fraction of frame.
    public var sizeDelta: Double
    /// How far the face center may DROP below baseline before flagging. Fraction of frame.
    public var dropDelta: Double

    public init(sizeDelta: Double = 0.045, dropDelta: Double = 0.040) {
        self.sizeDelta = sizeDelta
        self.dropDelta = dropDelta
    }

    public static let `default` = PostureThresholds()
}

/// Classified posture for one frame.
public enum PostureState: Equatable, Sendable {
    case upright
    case slouching
    /// A person IS in frame (face detected) but posture can't be measured this frame -
    /// e.g. no baseline yet. Counts as "present" but is never nudged and never scored.
    case presentUnmeasured
    case unknown   // no face detected at all (away from the Mac)
}
