import Foundation
import PrimeEyeKit

/// Example HUD data source. PrimeEye's notch HUD just renders whatever is in `AppState`; how
/// those fields get filled is up to you. This shipped provider sets static sample values so the
/// HUD renders out of the box - replace it with your own (poll files, hit an API, read system
/// metrics, whatever you want to glance at). See README "Wire your own HUD data".
///
/// The whole posture warner works without any of this; the HUD is the optional second half.
@MainActor
final class ExampleDataProvider {
    private weak var state: AppState?

    init(state: AppState) { self.state = state }

    func start() {
        guard let state else { return }
        state.intents = 3
        state.dominantDomain = "demo"
        state.fitness = 0.80
        state.priorityItem = "[DEMO] wire your own data source"
        state.usageLabel = "example"
        state.dataLive = true
        state.dataStale = false
    }

    func stop() {}
}
