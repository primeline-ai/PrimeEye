import AppKit
import SwiftUI
import CoreGraphics
import PrimeEyeKit

/// Hosts the SwiftUI notch UI in a borderless non-activating panel and drives the
/// collapsed/peek/expanded state machine from global mouse monitors.
/// Phase 1: the panel is non-interactive (ignoresMouseEvents) so clicks pass through
/// everywhere; all interaction is inferred from global hover/click. Phase 4 will make
/// the expanded panel interactive for real buttons.
/// `@MainActor` (Phase 3): all AppKit + AppState access is main-thread; the global mouse
/// monitor hops back onto the main actor before touching state.
@MainActor
final class NotchWindowController {
    private let state: AppState
    private var panel: NSPanel?
    private var hosting: NSHostingView<NotchRootView>?
    private var monitor: Any?
    private var notchRect: NSRect = .zero
    private weak var screenRef: NSScreen?

    init(state: AppState) { self.state = state }

    func show() {
        // Prefer a screen with a real notch; otherwise fall back to the main screen with a
        // faux top-center "notch" so the HUD still works on non-notch Macs (spec §10 / K1 fallback).
        guard let screen = Self.notchScreen() ?? NSScreen.main else {
            panel?.orderOut(nil)
            return
        }
        screenRef = screen
        var rect = Self.notchGlobalRect(for: screen)
        if rect == .zero {
            let f = screen.frame
            let w: CGFloat = 200, h: CGFloat = 32
            rect = NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
        }
        notchRect = rect
        let frame = panelFrame(for: screen)

        // Push geometry into state so the existing host re-renders (no rebuild, RC P1 #2).
        state.notchWidth = notchRect.width
        state.notchHeight = notchRect.height

        let panel = self.panel ?? makePanel(initialFrame: frame)
        panel.setFrame(frame, display: true)

        if hosting == nil {
            let host = NSHostingView(rootView: NotchRootView(state: state))
            host.autoresizingMask = [.width, .height]
            hosting = host
            panel.contentView = host
        }
        hosting?.frame = NSRect(origin: .zero, size: frame.size)
        panel.orderFrontRegardless()
        self.panel = panel

        installMonitor()
    }

    private func makePanel(initialFrame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        return panel
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] ev in
            // The closure is nonisolated; capture only Sendable data (the event kind) and
            // hop onto the main actor to touch AppState (@MainActor since Phase 3).
            let isClick = ev.type == .leftMouseDown
            Task { @MainActor in self?.handle(isClick: isClick) }
        }
    }

    private func handle(isClick: Bool) {
        guard screenRef != nil else { return }
        let p = NSEvent.mouseLocation
        let inTrigger = notchRect.insetBy(dx: -10, dy: -10).contains(p)
        let inPanel = visibleRect(for: state.display).contains(p)
        let event: NotchInputEvent = isClick
            ? .click(inPanelBounds: inPanel)
            : .mouseMoved(inTriggerZone: inTrigger, inPanelBounds: inPanel)
        let next = NotchInteraction.next(from: state.display, on: event)
        if next != state.display { state.display = next }
    }

    /// Visible card rect (global), top-centered under the notch, sized per state.
    private func visibleRect(for s: NotchDisplayState) -> NSRect {
        guard let screen = screenRef else { return .zero }
        let f = screen.frame
        let size: CGSize
        switch s {
        case .collapsed:
            size = CGSize(width: notchRect.width, height: notchRect.height + NotchLayout.collapsedHeightExtra)
        case .peek:
            size = CGSize(width: NotchLayout.peekWidth, height: notchRect.height + NotchLayout.peekHeight)
        case .expanded:
            size = CGSize(width: NotchLayout.expandedWidth, height: notchRect.height + NotchLayout.expandedHeight)
        }
        return NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
    }

    // MARK: geometry

    static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    static func notchGlobalRect(for screen: NSScreen) -> NSRect {
        let f = screen.frame
        let auxL = screen.auxiliaryTopLeftArea?.width ?? 0
        let auxR = screen.auxiliaryTopRightArea?.width ?? 0
        guard let local = NotchGeometry.notchRect(
            screenWidth: f.width, screenHeight: f.height,
            safeAreaTop: screen.safeAreaInsets.top, auxLeftWidth: auxL, auxRightWidth: auxR
        ) else { return .zero }
        return NSRect(x: f.minX + local.minX, y: f.minY + local.minY, width: local.width, height: local.height)
    }

    /// Panel footprint = the tallest card (expanded) plus the notch dead-zone on top.
    private func panelFrame(for screen: NSScreen) -> NSRect {
        let f = screen.frame
        let w = NotchLayout.expandedWidth
        let h = notchRect.height + NotchLayout.expandedHeight
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
