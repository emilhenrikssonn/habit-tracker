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

    func testTypedAmountsRejectValuesThatCannotBeShown() {
        XCTAssertNil(AmountEntryAlert.parse("inf"))
        XCTAssertNil(AmountEntryAlert.parse("nan"))
        XCTAssertNil(AmountEntryAlert.parse("1e400"))
        XCTAssertNil(AmountEntryAlert.parse("99999999999999999999"))
        XCTAssertEqual(AmountEntryAlert.parse("10000000"), 10_000_000)
        XCTAssertNil(AmountEntryAlert.parse("10000001"))
    }

    func testFormatDoesNotTrapOnHugeValues() {
        let habit = Habit(name: "x", category: .health, tracking: .amount, dailyGoal: 8)
        XCTAssertEqual(habit.format(8), "8")
        XCTAssertEqual(habit.format(2.5), "2.5")
        XCTAssertEqual(habit.format(.infinity), "inf")
        XCTAssertEqual(habit.format(1e20), "100000000000000000000")
    }

    func testTypedTextIsCleanedBeforeSaving() {
        XCTAssertEqual("  Read  ".cleanedInput(maxLength: 60), "Read")
        XCTAssertEqual("Read\nbooks\u{0}".cleanedInput(maxLength: 60), "Read books")
        XCTAssertEqual("👨‍👩‍👧 Family time".cleanedInput(maxLength: 60), "👨‍👩‍👧 Family time")
        XCTAssertEqual(String(repeating: "a", count: 100).cleanedInput(maxLength: 60).count, 60)
        XCTAssertEqual("abc   def".cleanedInput(maxLength: 4), "abc")
        XCTAssertEqual("\n\t ".cleanedInput(maxLength: 60), "")
    }

    func testExportedFieldsCannotRunAsFormulas() {
        XCTAssertEqual(DataExport.escape("Read"), "Read")
        XCTAssertEqual(DataExport.escape("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\"")
        XCTAssertEqual(DataExport.escape("+1"), "'+1")
        XCTAssertEqual(DataExport.escape("-"), "'-")
        XCTAssertEqual(DataExport.escape("@SUM(A1)"), "'@SUM(A1)")
        XCTAssertEqual(DataExport.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(DataExport.escape("a\rb"), "\"a\rb\"")
    }
}
