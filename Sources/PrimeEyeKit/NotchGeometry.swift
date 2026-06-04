import CoreGraphics

/// Pure geometry for placing a window at the MacBook notch.
/// No AppKit, no display required - fully unit-testable.
public enum NotchGeometry {

    /// Computes the notch rectangle in AppKit screen-local coordinates (origin bottom-left,
    /// relative to a screen whose own origin is (0,0)). Callers translate by the screen's frame origin.
    ///
    /// - Returns: the notch rect, or `nil` if the screen has no notch
    ///   (`safeAreaTop <= 0`) or the geometry is degenerate (notch width <= 0).
    public static func notchRect(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        safeAreaTop: CGFloat,
        auxLeftWidth: CGFloat,
        auxRightWidth: CGFloat
    ) -> CGRect? {
        guard safeAreaTop > 0 else { return nil }
        guard auxLeftWidth >= 0, auxRightWidth >= 0 else { return nil }
        let notchWidth = screenWidth - auxLeftWidth - auxRightWidth
        guard notchWidth > 0 else { return nil }
        // The notch sits between the two auxiliary menu-bar areas, hugging the top edge.
        let originX = auxLeftWidth
        let originY = screenHeight - safeAreaTop
        return CGRect(x: originX, y: originY, width: notchWidth, height: safeAreaTop)
    }
}
