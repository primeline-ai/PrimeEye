import AppKit

// PrimeEye entry point. Agent app (no Dock icon): activation policy set in AppDelegate.
// `@main` + `@MainActor static main()` gives the whole launch path main-actor isolation,
// so constructing the @MainActor AppDelegate/AppState needs no assumeIsolated dance.
@main
enum PrimeEyeMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
