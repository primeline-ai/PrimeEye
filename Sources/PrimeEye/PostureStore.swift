import Foundation
import PrimeEyeKit

/// On-disk persistence for the calibrated baseline and the daily posture stat, under
/// `~/Library/Application Support/PrimeEye/`. Reads/writes are best-effort: a missing or
/// corrupt file simply yields nil (the app re-calibrates / starts a fresh day) and never crashes.
enum PostureStore {
    private static var dir: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrimeEye", isDirectory: true)
    }
    private static var baselineURL: URL { dir.appendingPathComponent("baseline.json") }
    private static var statURL: URL { dir.appendingPathComponent("daily-stat.json") }

    private struct SavedBaseline: Codable {
        var baseline: Baseline
        var thresholds: PostureThresholds
    }

    private static func ensureDir() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    static func loadBaseline() -> (Baseline, PostureThresholds)? {
        guard let data = try? Data(contentsOf: baselineURL),
              let saved = try? JSONDecoder().decode(SavedBaseline.self, from: data) else { return nil }
        return (saved.baseline, saved.thresholds)
    }

    static func saveBaseline(_ baseline: Baseline, _ thresholds: PostureThresholds) {
        ensureDir()
        guard let data = try? JSONEncoder().encode(SavedBaseline(baseline: baseline, thresholds: thresholds)) else { return }
        try? data.write(to: baselineURL, options: .atomic)
    }

    static func loadStat() -> DailyPostureStat? {
        guard let data = try? Data(contentsOf: statURL) else { return nil }
        return try? JSONDecoder().decode(DailyPostureStat.self, from: data)
    }

    static func saveStat(_ stat: DailyPostureStat) {
        ensureDir()
        guard let data = try? JSONEncoder().encode(stat) else { return }
        try? data.write(to: statURL, options: .atomic)
    }
}
