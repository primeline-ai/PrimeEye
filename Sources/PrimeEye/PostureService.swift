import Foundation
import QuartzCore
import PrimeEyeKit

/// Ties the posture pipeline together on the main actor:
///   PostureMonitor (camera) -> WarningCoordinator (escalation) -> DailyStatTracker -> AppState
/// and routes calibration metrics into CalibrationController.
///
/// Demo path: set `PRIMEEYE_DEMO_STAGE=glow|message` to drive the notch UI without a camera
/// (used for headless visual verification - EPT leg 2). No camera is started in demo mode.
@MainActor
final class PostureService {
    private let monitor = PostureMonitor()
    private let calibration = CalibrationController()
    // Snappy escalation: glow ~2.5s after you slouch, message ~6s, recover after ~2s upright.
    // (Was 5s/20s - far too slow to be useful as a live posture nudge.)
    private var coordinator = WarningCoordinator(glowDelay: 2.5, messageDelay: 6, recoveryHold: 2)
    private var tracker: DailyStatTracker
    private weak var state: AppState?
    private var framesSinceSave = 0
    private var hasPersistedBaseline = false
    private var lastPresentAt: CFTimeInterval = CACurrentMediaTime()
    private let presenceGrace: CFTimeInterval = 3   // declare "away" after 3s with no body detected

    init(state: AppState) {
        self.state = state
        self.tracker = PostureStore.loadStat().map { DailyStatTracker(stat: $0) }
            ?? DailyStatTracker(now: Date())

        // Load the baseline once and remember the result, so start() decides calibration from
        // this fact rather than re-reading disk (a second read could disagree and clobber a
        // valid baseline with a fresh calibration - RC High-2).
        if let (baseline, thresholds) = PostureStore.loadBaseline() {
            monitor.setBaseline(baseline, thresholds: thresholds)
            hasPersistedBaseline = true
        }

        calibration.onComplete = { [weak self] baseline, thresholds in
            self?.monitor.setBaseline(baseline, thresholds: thresholds)
            PostureStore.saveBaseline(baseline, thresholds)
        }
        monitor.setOnSample { [weak self] postureState, metrics in
            self?.handle(postureState, metrics)
        }
        pushStat()
    }

    func start() {
        if let demo = ProcessInfo.processInfo.environment["PRIMEEYE_DEMO_STAGE"] {
            startDemo(stage: demo)
            return
        }
        state?.postureActive = true
        monitor.requestAccessAndStart()
        // Calibration is now ALWAYS deliberate - never auto-run on launch (that silently
        // captured whatever pose the user happened to be in). With no saved baseline the app
        // sits in presentUnmeasured ("measuring") until the user triggers Recalibrate (menu
        // bar) or drops the ~/.primeeye-recalibrate flag.
    }

    func stop() {
        monitor.stop()
        state?.postureActive = false
        state?.warningStage = .none
        PostureStore.saveStat(tracker.stat)
    }

    func recalibrate() {
        calibration.begin()
    }

    // MARK: pipeline

    private func handle(_ postureState: PostureState, _ metrics: SlouchMetrics?) {
        // Operator-triggered recalibration: drop a `~/.primeeye-recalibrate` file and the next
        // ~10 frames become the new upright baseline. Lets calibration be a deliberate, observed
        // step (the silent auto-calibrate-on-first-frames was the "calibrated me as a shrimp" bug).
        if Self.consumeRecalibrateFlag() {
            hasPersistedBaseline = false
            state?.postureMeasured = false
            calibration.begin()
        }

        // While calibrating, frames train the baseline and do not warn or count toward stats.
        if calibration.isCalibrating {
            calibration.feed(metrics)
            return
        }

        // Presence: an .unknown frame = no body detected. If we've seen no body for >3s, the
        // user is away from the Mac - surface "away" so it reads as paused, not a warning.
        // (The nudge + daily-% are already suppressed because .unknown never escalates and is
        // excluded from the counted frames - this only makes that state visible.)
        let mono = CACurrentMediaTime()
        if postureState != .unknown { lastPresentAt = mono }
        state?.userPresent = (mono - lastPresentAt) < presenceGrace

        let nudgesBefore = coordinator.nudgeCount
        let stage = coordinator.update(postureState, at: mono)
        let now = Date()
        if coordinator.nudgeCount > nudgesBefore { tracker.recordNudge(at: now) }
        tracker.record(postureState, at: now)

        state?.warningStage = stage
        state?.postureOK = (postureState != .slouching)
        pushStat()

        framesSinceSave += 1
        if framesSinceSave >= 30 {   // persist roughly every ~10s at 3fps
            framesSinceSave = 0
            PostureStore.saveStat(tracker.stat)
        }
    }

    private func pushStat() {
        // Only claim a percentage once real frames have been counted; before that the UI shows
        // "measuring" rather than a fake 100% (honesty: never let placeholder look measured).
        if let pct = tracker.stat.goodPercent {
            state?.posturePercentToday = pct
            state?.postureMeasured = true
        }
        state?.nudgesToday = tracker.stat.nudges
    }

    /// True exactly once after a `~/.primeeye-recalibrate` flag appears (then deletes it).
    private static func consumeRecalibrateFlag() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".primeeye-recalibrate")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        try? FileManager.default.removeItem(at: url)
        return true
    }

    private func startDemo(stage: String) {
        state?.postureActive = true
        switch stage.lowercased() {
        case "glow":
            state?.warningStage = .glow
            state?.postureOK = false
        case "message":
            state?.warningStage = .message
            state?.postureOK = false
        default:
            state?.warningStage = .none
            state?.postureOK = true
        }
        state?.posturePercentToday = 87
        state?.postureMeasured = true
        state?.userPresent = true
        state?.nudgesToday = 3
    }
}
