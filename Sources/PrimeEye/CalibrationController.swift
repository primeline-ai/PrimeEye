import Foundation
import PrimeEyeKit

/// Drives the short "sit up straight" capture: accumulates upright metrics until enough
/// frames are collected, then derives a `Baseline` + jitter-adaptive thresholds.
/// Pure decision logic lives in `CalibrationAccumulator` (PrimeEyeKit); this only
/// orchestrates the start/feed/finish lifecycle. Main-actor (driven by the UI/service).
@MainActor
final class CalibrationController {
    private var accumulator = CalibrationAccumulator()
    private(set) var isCalibrating = false

    /// Called on the main actor when a baseline is ready.
    var onComplete: (@MainActor (Baseline, PostureThresholds) -> Void)?

    func begin() {
        accumulator = CalibrationAccumulator()
        isCalibrating = true
    }

    /// Feed a metrics sample arriving from `PostureMonitor` while calibrating.
    /// Ignores nil samples (joints not visible) so calibration only learns real upright poses.
    func feed(_ metrics: SlouchMetrics?) {
        guard isCalibrating, let metrics else { return }
        accumulator.add(metrics)
        if accumulator.isReady { finish() }
    }

    private func finish() {
        guard isCalibrating, let baseline = accumulator.baseline() else { return }
        isCalibrating = false
        // Fixed, sensible sensitivity (not variance-derived) so the nudge fires promptly.
        onComplete?(baseline, .default)
    }
}
