import Foundation

/// The escalation level the notch UI should currently show.
public enum WarningStage: Equatable, Sendable {
    case none      // posture ok / within hysteresis
    case glow      // gentle nudge: notch edges glow amber
    case message   // escalated: "sit up straight" message
}

/// Pure, deterministic escalation state machine. The caller supplies a monotonic
/// timestamp (seconds) with every sample, so tests inject a clock and there is no
/// hidden dependency on wall time.
///
/// Lifecycle of one slouch episode:
///   ok -> slouch sustained `glowDelay`s  -> .glow
///       -> slouch sustained `messageDelay`s -> .message
///   recovery: "not slouching" (upright OR no-person) sustained `recoveryHold`s -> .none
///
/// Hysteresis: a brief straighten (< `recoveryHold`) does NOT drop the stage, and the
/// slouch timer keeps running, so flapping cannot spam nudges. A "nudge" is counted once
/// per episode, at the moment it first reaches `.glow` (the first visible nudge).
public struct WarningCoordinator: Equatable, Sendable {
    public var glowDelay: TimeInterval
    public var messageDelay: TimeInterval
    public var recoveryHold: TimeInterval

    public private(set) var stage: WarningStage = .none
    public private(set) var nudgeCount: Int = 0

    private var slouchStart: TimeInterval?
    private var notSlouchingStart: TimeInterval?

    public init(glowDelay: TimeInterval = 5, messageDelay: TimeInterval = 20, recoveryHold: TimeInterval = 3) {
        self.glowDelay = glowDelay
        self.messageDelay = messageDelay
        self.recoveryHold = recoveryHold
    }

    /// Feed one classified sample observed at time `now` (monotonic seconds).
    /// Returns the resulting stage.
    @discardableResult
    public mutating func update(_ state: PostureState, at now: TimeInterval) -> WarningStage {
        switch state {
        case .slouching:
            notSlouchingStart = nil
            let start = slouchStart ?? now
            slouchStart = start
            let elapsed = now - start
            let target: WarningStage =
                elapsed >= messageDelay ? .message :
                elapsed >= glowDelay    ? .glow    : .none
            advance(to: target)

        case .upright, .unknown, .presentUnmeasured:
            // All count as "not slouching" for recovery. unknown (person left) and
            // presentUnmeasured (here but shoulders not visible) both recover the UI rather
            // than freezing an amber glow - we never nudge on a frame we couldn't measure.
            let start = notSlouchingStart ?? now
            notSlouchingStart = start
            if now - start >= recoveryHold {
                slouchStart = nil
                advance(to: .none)
            }
            // else: still inside the hysteresis window -> hold the current stage.
        }
        return stage
    }

    private mutating func advance(to target: WarningStage) {
        // Count one nudge per episode: when an episode first escalates away from .none.
        // Covers both the normal none->glow path and a direct none->message jump that can
        // happen if a large gap separates two samples.
        if stage == .none && target != .none {
            nudgeCount += 1
        }
        stage = target
    }
}
