import XCTest
@testable import PrimeEyeKit

final class NotchInteractionTests: XCTestCase {

    func testHoverIntoTriggerExpandsToPeek() {
        XCTAssertEqual(
            NotchInteraction.next(from: .collapsed, on: .mouseMoved(inTriggerZone: true, inPanelBounds: false)),
            .peek
        )
    }

    func testHoverOutsideStaysCollapsed() {
        XCTAssertEqual(
            NotchInteraction.next(from: .collapsed, on: .mouseMoved(inTriggerZone: false, inPanelBounds: false)),
            .collapsed
        )
    }

    func testPeekCollapsesWhenCursorLeaves() {
        XCTAssertEqual(
            NotchInteraction.next(from: .peek, on: .mouseMoved(inTriggerZone: false, inPanelBounds: false)),
            .collapsed
        )
    }

    func testPeekStaysWhileInsidePanel() {
        XCTAssertEqual(
            NotchInteraction.next(from: .peek, on: .mouseMoved(inTriggerZone: false, inPanelBounds: true)),
            .peek
        )
    }

    func testClickInsidePeekExpands() {
        XCTAssertEqual(
            NotchInteraction.next(from: .peek, on: .click(inPanelBounds: true)),
            .expanded
        )
    }

    func testClickInsideCollapsedExpands() {
        XCTAssertEqual(
            NotchInteraction.next(from: .collapsed, on: .click(inPanelBounds: true)),
            .expanded
        )
    }

    func testHoverDoesNotCollapseExpanded() {
        XCTAssertEqual(
            NotchInteraction.next(from: .expanded, on: .mouseMoved(inTriggerZone: false, inPanelBounds: false)),
            .expanded
        )
    }

    func testClickOutsideExpandedCollapses() {
        XCTAssertEqual(
            NotchInteraction.next(from: .expanded, on: .click(inPanelBounds: false)),
            .collapsed
        )
    }
}
