import XCTest
@testable import PrimeEyeKit

final class NotchGeometryTests: XCTestCase {

    func testNotchPresent() {
        let r = NotchGeometry.notchRect(
            screenWidth: 1000, screenHeight: 600,
            safeAreaTop: 32, auxLeftWidth: 400, auxRightWidth: 400
        )
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.width, 200, accuracy: 0.001)
        XCTAssertEqual(r!.height, 32, accuracy: 0.001)
        XCTAssertEqual(r!.minX, 400, accuracy: 0.001)
        XCTAssertEqual(r!.minY, 568, accuracy: 0.001) // screenHeight - safeAreaTop
    }

    func testNoNotchReturnsNil() {
        XCTAssertNil(NotchGeometry.notchRect(
            screenWidth: 1440, screenHeight: 900,
            safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0
        ))
    }

    func testDegenerateWidthReturnsNil() {
        // aux areas consume the whole width -> no room for a notch
        XCTAssertNil(NotchGeometry.notchRect(
            screenWidth: 800, screenHeight: 600,
            safeAreaTop: 32, auxLeftWidth: 400, auxRightWidth: 400
        ))
    }

    func testNegativeAuxWidthReturnsNil() {
        // defensive: a negative aux width must not produce an off-screen rect
        XCTAssertNil(NotchGeometry.notchRect(
            screenWidth: 1000, screenHeight: 600,
            safeAreaTop: 32, auxLeftWidth: -10, auxRightWidth: 400
        ))
    }

    func testAsymmetricAuxAreas() {
        let r = NotchGeometry.notchRect(
            screenWidth: 1000, screenHeight: 600,
            safeAreaTop: 30, auxLeftWidth: 300, auxRightWidth: 500
        )
        XCTAssertNotNil(r)
        XCTAssertEqual(r!.minX, 300, accuracy: 0.001)
        XCTAssertEqual(r!.width, 200, accuracy: 0.001)
    }
}
