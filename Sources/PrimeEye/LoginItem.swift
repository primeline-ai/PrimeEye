import ServiceManagement

/// Launch-at-login via `SMAppService` (macOS 13+). Registers the app itself as a login item.
@MainActor
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Toggle registration. Best-effort: failures are logged, never crash (e.g. running from a
    /// non-bundle dev path where SMAppService refuses).
    static func toggle() {
        do {
            if isEnabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("PrimeEye: login-item toggle failed: \(error.localizedDescription)")
        }
    }
}
