import XCTest
@testable import PrimeEyeKit

final class DailyPostureStatTests: XCTestCase {

    // Deterministic calendar: fixed UTC so startOfDay is stable across machines/timezones.
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        comps.timeZone = TimeZone(identifier: "UTC")!
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    func testGoodPercentNilBeforeAnyFrames() {
        let t = DailyStatTracker(now: date(2026, 6, 4), calendar: utc)
        XCTAssertNil(t.stat.goodPercent)
    }

    func testGoodPercentExcludesUnknown() {
        var t = DailyStatTracker(now: date(2026, 6, 4), calendar: utc)
        let now = date(2026, 6, 4)
        for _ in 0..<7 { t.record(.upright, at: now) }
        for _ in 0..<3 { t.record(.slouching, at: now) }
        for _ in 0..<100 { t.record(.unknown, at: now) }  // away from desk - must not count
        XCTAssertEqual(t.stat.countedFrames, 10)
        XCTAssertEqual(t.stat.goodPercent, 70)
    }

    func testMidnightRolloverResetsStat() {
        var t = DailyStatTracker(now: date(2026, 6, 4), calendar: utc)
        t.record(.upright, at: date(2026, 6, 4, 23))
        t.recordNudge(at: date(2026, 6, 4, 23))
        XCTAssertEqual(t.stat.countedFrames, 1)
        XCTAssertEqual(t.stat.nudges, 1)

        // Next day's first frame resets everything.
        t.record(.slouching, at: date(2026, 6, 5, 1))
        XCTAssertEqual(t.stat.uprightFrames, 0)
        XCTAssertEqual(t.stat.countedFrames, 1)
        XCTAssertEqual(t.stat.nudges, 0)
        XCTAssertEqual(t.stat.dayStart, utc.startOfDay(for: date(2026, 6, 5, 1)))
    }

    func testResumeFromPersistedStat() {
        let saved = DailyPostureStat(
            dayStart: utc.startOfDay(for: date(2026, 6, 4)),
            uprightFrames: 5, countedFrames: 5, nudges: 2
        )
        var t = DailyStatTracker(stat: saved, calendar: utc)
        t.record(.upright, at: date(2026, 6, 4, 14))   // same day -> accumulates
        XCTAssertEqual(t.stat.uprightFrames, 6)
        XCTAssertEqual(t.stat.nudges, 2)
    }

    func testStatRoundTripsThroughCodable() throws {
        let stat = DailyPostureStat(
            dayStart: utc.startOfDay(for: date(2026, 6, 4)),
            uprightFrames: 9, countedFrames: 10, nudges: 1
        )
        let data = try JSONEncoder().encode(stat)
        let back = try JSONDecoder().decode(DailyPostureStat.self, from: data)
        XCTAssertEqual(stat, back)
        XCTAssertEqual(back.goodPercent, 90)
    }
}
