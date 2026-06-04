import Foundation

/// Collects upright samples during the first-run "sit up straight" capture and derives
/// a `Baseline` (mean of metrics) plus optional jitter-adaptive thresholds. Pure and
/// unit-testable; the camera orchestration that feeds it lives in the executable target.
public struct CalibrationAccumulator: Sendable {
    public private(set) var count: Int = 0
    private var sumForwardHead: Double = 0
    private var sumSlump: Double = 0
    private var sumSqForwardHead: Double = 0
    private var sumSqSlump: Double = 0

    /// Minimum samples before the baseline is trusted (~5s at 3fps).
    public let minSamples: Int

    public init(minSamples: Int = 15) {
        self.minSamples = minSamples
    }

    public mutating func add(_ m: SlouchMetrics) {
        count += 1
        sumForwardHead += m.forwardHead
        sumSlump += m.slump
        sumSqForwardHead += m.forwardHead * m.forwardHead
        sumSqSlump += m.slump * m.slump
    }

    public var isReady: Bool { count >= minSamples }

    /// Mean baseline, or nil if no samples were collected.
    public func baseline() -> Baseline? {
        guard count > 0 else { return nil }
        let n = Double(count)
        return Baseline(forwardHead: sumForwardHead / n, slump: sumSlump / n)
    }

    /// Suggested thresholds = max(floor, k * stddev) per axis, so a fidgety user gets a
    /// wider tolerance than a still one. Returns nil with fewer than 2 samples (no variance).
    /// Uses Bessel-corrected (sample) variance so small calibration windows are not
    /// under-estimated (RC Med-4); the `count >= 2` guard keeps the `n - 1` denominator > 0.
    public func suggestedThresholds(k: Double = 3, floor: PostureThresholds = .default) -> PostureThresholds? {
        guard count >= 2 else { return nil }
        let n = Double(count)
        let varF = max(0, (sumSqForwardHead - sumForwardHead * sumForwardHead / n) / (n - 1))
        let varS = max(0, (sumSqSlump - sumSlump * sumSlump / n) / (n - 1))
        return PostureThresholds(
            forwardHeadDelta: max(floor.forwardHeadDelta, k * sqrt(varF)),
            slumpDelta: max(floor.slumpDelta, k * sqrt(varS))
        )
    }
}
