import CoreGraphics

/// Body-pose joints PrimeEye needs for posture, in a normalized coordinate space
/// (Vision's: origin bottom-left, x/y in 0...1, y increasing upward).
/// A joint is `nil` when it was not detected with sufficient confidence.
public struct PostureJoints: Equatable, Sendable {
    public var nose: CGPoint?
    public var leftEar: CGPoint?
    public var rightEar: CGPoint?
    public var leftShoulder: CGPoint?
    public var rightShoulder: CGPoint?

    public init(
        nose: CGPoint? = nil,
        leftEar: CGPoint? = nil,
        rightEar: CGPoint? = nil,
        leftShoulder: CGPoint? = nil,
        rightShoulder: CGPoint? = nil
    ) {
        self.nose = nose
        self.leftEar = leftEar
        self.rightEar = rightEar
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
    }
}

/// Scale-invariant posture metrics (normalized by shoulder width, so distance to the
/// camera does not change them). The discriminative power of the exact thresholds is
/// validated on real hardware (plan A3/K2); this type only defines the geometry.
public struct SlouchMetrics: Equatable, Sendable, Codable {
    /// Signed lateral offset of the ear-midpoint from the shoulder-midpoint, / shoulder width.
    /// Drifts when the head tilts/leans to one side relative to the calibrated pose.
    public var forwardHead: Double
    /// Vertical gap from the shoulder-midpoint up to the ear-midpoint, / shoulder width.
    /// Large = head held high (upright); small = head dropped toward shoulders (slump).
    public var slump: Double

    public init(forwardHead: Double, slump: Double) {
        self.forwardHead = forwardHead
        self.slump = slump
    }
}

/// Calibrated upright reference for one user (mean of metrics captured while sitting up).
public struct Baseline: Equatable, Sendable, Codable {
    public var forwardHead: Double
    public var slump: Double

    public init(forwardHead: Double, slump: Double) {
        self.forwardHead = forwardHead
        self.slump = slump
    }
}

/// How far from baseline counts as a slouch. Tunable - plan K2 allows two tuning rounds
/// on hardware before falling back to stats-only mode.
public struct PostureThresholds: Equatable, Sendable, Codable {
    /// Allowed absolute deviation of `forwardHead` from baseline before flagging.
    public var forwardHeadDelta: Double
    /// Allowed drop of `slump` below baseline before flagging.
    public var slumpDelta: Double

    public init(forwardHeadDelta: Double = 0.18, slumpDelta: Double = 0.18) {
        self.forwardHeadDelta = forwardHeadDelta
        self.slumpDelta = slumpDelta
    }

    public static let `default` = PostureThresholds()
}

/// Classified posture for one frame.
public enum PostureState: Equatable, Sendable {
    case upright
    case slouching
    case unknown   // joints not visible / confidence too low / not calibrated yet
}
