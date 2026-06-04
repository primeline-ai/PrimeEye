import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private var notchController: NotchWindowController?
    private var menuController: MenuBarController?
    private var postureService: PostureService?
    private var hudProvider: ExampleDataProvider?
    private var postureEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app: live in the menu bar + notch, no Dock icon, never steal focus.
        NSApp.setActivationPolicy(.accessory)

        let menu = MenuBarController()
        menu.onRecalibrate = { [weak self] in self?.postureService?.recalibrate() }
        menu.onTogglePosture = { [weak self] in self?.togglePosture() }
        menu.onToggleLogin = { LoginItem.toggle() }
        menuController = menu

        notchController = NotchWindowController(state: appState)
        notchController?.show()

        // HUD: example data source (swap in your own - see README). Read-only.
        let provider = ExampleDataProvider(state: appState)
        provider.start()
        hudProvider = provider

        // Posture monitoring (Phase 3). Requests camera access on first launch; the green
        // camera LED stays on while monitoring (accepted, spec C5).
        let service = PostureService(state: appState)
        service.start()
        postureService = service

        // Reposition if the display configuration changes (resolution / external monitor).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func togglePosture() {
        postureEnabled.toggle()
        if postureEnabled { postureService?.start() } else { postureService?.stop() }
    }

    @objc private func screensChanged() {
        notchController?.show()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
