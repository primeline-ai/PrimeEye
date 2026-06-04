import CoreGraphics

/// The three visual states of the notch UI.
public enum NotchDisplayState: Equatable, Sendable {
    case collapsed   // idle, hugs the notch
    case peek        // hover: compact HUD bar
    case expanded    // click: full panel
}

/// User input the interaction state machine reacts to.
public enum NotchInputEvent: Equatable, Sendable {
    case mouseMoved(inTriggerZone: Bool, inPanelBounds: Bool)
    case click(inPanelBounds: Bool)
}

/// Pure, unit-testable state machine for the notch UI. No AppKit.
public enum NotchInteraction {
    public static func next(from state: NotchDisplayState, on event: NotchInputEvent) -> NotchDisplayState {
        switch (state, event) {
        case (.collapsed, .mouseMoved(let inTrigger, _)):
            return inTrigger ? .peek : .collapsed
        case (.peek, .mouseMoved(let inTrigger, let inPanel)):
            return (inTrigger || inPanel) ? .peek : .collapsed
        case (.expanded, .mouseMoved):
            return .expanded // hover never collapses an expanded panel
        case (.collapsed, .click(let inPanel)):
            return inPanel ? .expanded : .collapsed
        case (.peek, .click(let inPanel)):
            return inPanel ? .expanded : .peek
        case (.expanded, .click(let inPanel)):
            return inPanel ? .expanded : .collapsed // click outside collapses
        }
    }
}

/// Shared layout constants so the view and the window controller agree on sizes.
public enum NotchLayout {
    public static let cornerRadius: CGFloat = 14
    public static let collapsedHeightExtra: CGFloat = 6 // how far the idle strip peeks below the notch
    public static let peekWidth: CGFloat = 330
    public static let peekHeight: CGFloat = 46
    public static let expandedWidth: CGFloat = 380
    public static let expandedHeight: CGFloat = 200
}
