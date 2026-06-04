import SwiftUI
import PrimeEyeKit

/// Single source of truth the SwiftUI view binds to.
/// The HUD half binds to these fields; a data provider fills them (see ExampleDataProvider).
/// `@MainActor`: because a background provider (PostureMonitor) exists, off-main writes are a
/// compile-time error - every mutation must hop to main first.
@MainActor
final class AppState: ObservableObject {
    @Published var display: NotchDisplayState = .collapsed

    // Notch geometry, published so the view re-renders without rebuilding the host (RC P1 #2).
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 32

    // Placeholder HUD data, overwritten by a data provider (see ExampleDataProvider).
    @Published var intents: Int = 2
    @Published var dominantDomain: String = "code_review"
    @Published var fitness: Double = 0.83
    @Published var priorityItem: String = "[M-1] example item"
    @Published var usageLabel: String = "ctx 41%"

    // Honesty flags: stay false until a provider supplies real data, so placeholder
    // numbers can never be mistaken for real measurements.
    @Published var dataLive: Bool = false       // -> true once a data provider has filled real values
    @Published var dataStale: Bool = false      // -> true when the source data is older than your freshness window
    @Published var pulseUpdated: Date? = nil     // last data-source update timestamp (freshness)
    @Published var postureActive: Bool = false  // -> true once PostureService starts the camera
    @Published var postureOK: Bool = true
    @Published var userPresent: Bool = true     // false when no body seen for a few seconds (away from Mac)
    @Published var posturePercentToday: Int = 92
    @Published var postureMeasured: Bool = false  // -> true once a real % has been computed today
    @Published var nudgesToday: Int = 0

    // Posture escalation stage, driven by WarningCoordinator via PostureService.
    @Published var warningStage: WarningStage = .none
}
