import Foundation

/// Collects upright samples during the first-run "sit up straight" capture and derives a
/// `Baseline` (mean face geometry). Pure and unit-testable; the camera orchestration that
/// feeds it lives in the executable target.
public struct CalibrationAccumulator: Sendable {
    public private(set) var count: Int = 0
    private var sumSize: Double = 0
    private var sumCenterY: Double = 0

    /// Minimum samples before the baseline is trusted (~3s at 3fps).
    public let minSamples: Int

    public init(minSamples: Int = 10) {
        self.minSamples = minSamples
    }

    public mutating func add(_ m: SlouchMetrics) {
        count += 1
        sumSize += m.faceSize
        sumCenterY += m.faceCenterY
    }

    public var isReady: Bool { count >= minSamples }

    /// Mean baseline, or nil if no samples were collected.
    public func baseline() -> Baseline? {
        guard count > 0 else { return nil }
        let n = Double(count)
        return Baseline(faceSize: sumSize / n, faceCenterY: sumCenterY / n)
    }
}
