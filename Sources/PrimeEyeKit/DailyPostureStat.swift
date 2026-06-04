import Foundation

/// One day's posture accounting. `unknown` frames are excluded from the ratio, so
/// stepping away from the desk does not deflate the "good %" figure.
public struct DailyPostureStat: Equatable, Sendable, Codable {
    /// Calendar start-of-day key this stat belongs to.
    public var dayStart: Date
    public var uprightFrames: Int
    public var countedFrames: Int   // upright + slouching (excludes unknown)
    public var nudges: Int

    public init(dayStart: Date, uprightFrames: Int = 0, countedFrames: Int = 0, nudges: Int = 0) {
        self.dayStart = dayStart
        self.uprightFrames = uprightFrames
        self.countedFrames = countedFrames
        self.nudges = nudges
    }

    /// Upright percentage 0...100, or nil if nothing has been counted yet.
    public var goodPercent: Int? {
        guard countedFrames > 0 else { return nil }
        return Int((Double(uprightFrames) / Double(countedFrames) * 100).rounded())
    }
}

/// Accumulates daily posture stats with an automatic reset at local midnight.
/// The current date is injected on every call, so midnight rollover is unit-testable
/// without waiting for actual midnight.
public struct DailyStatTracker: Sendable {
    public private(set) var stat: DailyPostureStat
    private let calendar: Calendar

    /// Start fresh for the day containing `now`.
    public init(now: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        self.stat = DailyPostureStat(dayStart: calendar.startOfDay(for: now))
    }

    /// Resume from a persisted stat (e.g. loaded from disk on launch).
    public init(stat: DailyPostureStat, calendar: Calendar = .current) {
        self.calendar = calendar
        self.stat = stat
    }

    private mutating func rolloverIfNeeded(_ now: Date) {
        let today = calendar.startOfDay(for: now)
        if today != stat.dayStart {
            stat = DailyPostureStat(dayStart: today)
        }
    }

    public mutating func record(_ state: PostureState, at now: Date) {
        rolloverIfNeeded(now)
        switch state {
        case .upright:
            stat.uprightFrames += 1
            stat.countedFrames += 1
        case .slouching:
            stat.countedFrames += 1
        case .unknown, .presentUnmeasured:
            break   // not a measured posture frame -> excluded from the daily ratio
        }
    }

    public mutating func recordNudge(at now: Date) {
        rolloverIfNeeded(now)
        stat.nudges += 1
    }
}
