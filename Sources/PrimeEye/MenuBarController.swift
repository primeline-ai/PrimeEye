import AppKit

/// Menu-bar status item: the escape hatch (and the home base on no-notch Macs).
/// Posture controls route back to `PostureService` via the injected closures.
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem

    var onRecalibrate: (() -> Void)?
    var onTogglePosture: (() -> Void)?
    var onToggleLogin: (() -> Void)?
    private let loginItem = NSMenuItem(title: "Start at login", action: nil, keyEquivalent: "")

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "\u{1F441}" // eye

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PrimeEye", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let recal = NSMenuItem(title: "Recalibrate posture", action: #selector(recalibrate), keyEquivalent: "r")
        recal.target = self
        menu.addItem(recal)

        let toggle = NSMenuItem(title: "Toggle posture monitoring", action: #selector(togglePosture), keyEquivalent: "p")
        toggle.target = self
        menu.addItem(toggle)

        loginItem.action = #selector(toggleLogin)
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit PrimeEye",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    @objc private func recalibrate() { onRecalibrate?() }
    @objc private func togglePosture() { onTogglePosture?() }
    @objc private func toggleLogin() {
        onToggleLogin?()
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }
}
