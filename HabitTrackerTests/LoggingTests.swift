import XCTest
@testable import HabitTracker

final class LoggingTests: XCTestCase {
    private func steps(_ goal: Double, _ tracking: TrackingType = .amount) -> [Double] {
        Habit(name: "x", category: .health, tracking: tracking, dailyGoal: goal).logSteps
    }

    func testStepsScaleWithTheGoal() {
        XCTAssertEqual(steps(8), [1])
        XCTAssertEqual(steps(10), [1, 5])
        XCTAssertEqual(steps(20), [1, 5])
        XCTAssertEqual(steps(50), [1, 10])
        XCTAssertEqual(steps(250), [10, 50])
        XCTAssertEqual(steps(1000), [10, 100])
        XCTAssertEqual(steps(2000), [100, 500])
        XCTAssertEqual(steps(8000), [100, 1000])
        XCTAssertEqual(steps(10000), [100, 1000])
        XCTAssertEqual(steps(5000), [100, 1000])
        XCTAssertEqual(steps(30, .time), [1, 5, 15])
        XCTAssertEqual(steps(180, .time), [5, 15, 60])
    }

    func testTypedAmountsParse() {
        XCTAssertEqual(AmountEntryAlert.parse("8000"), 8000)
        XCTAssertEqual(AmountEntryAlert.parse("8 000"), 8000)
        XCTAssertEqual(AmountEntryAlert.parse("2,5"), 2.5)
        XCTAssertEqual(AmountEntryAlert.parse("2.5"), 2.5)
        XCTAssertNil(AmountEntryAlert.parse(""))
        XCTAssertNil(AmountEntryAlert.parse("abc"))
        XCTAssertNil(AmountEntryAlert.parse("-3"))
    }
}
