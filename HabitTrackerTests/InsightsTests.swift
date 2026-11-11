import XCTest
@testable import HabitTracker

final class InsightsTests: XCTestCase {
    private let cal = Calendar.current
    /// A Monday, so weekday maths is easy to follow.
    private lazy var monday = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!

    private func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: monday)! }
    private func days(_ pattern: String, from start: Int = 0) -> [DueDay] {
        pattern.enumerated().map { (day(start + $0.offset), $0.element == "x") }
    }
    private func at(_ n: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: day(n))!
    }

    func testMomentumWeighsRecentDaysMost() {
        let slipping = days("xxxxxxxxxxxxx...")
        let rising = days("...xxxxxxxxxxxxx")
        let asOf = day(15)
        XCTAssertLessThan(Insights.momentum([slipping], asOf: asOf)!, 75)
        XCTAssertLessThan(Insights.momentum([slipping], asOf: asOf)!, Insights.momentum([rising], asOf: asOf)!)
        XCTAssertGreaterThan(Insights.momentum([rising], asOf: asOf)!, 90)
        XCTAssertEqual(Insights.momentum([days("xxxx")], asOf: day(3)), 100)
        XCTAssertNil(Insights.momentum([days("xx")], asOf: day(1)))
    }

    func testRecoveryCountsDaysUntilNextKeptDay() {
        // Slips of 1 day and 3 days, ending kept.
        let r = Insights.recovery([days("xx.xx...x")], today: day(8))!
        XCTAssertEqual(r.slips, 2)
        XCTAssertEqual(r.typicalDays, 2) // median of 1 and 3
        XCTAssertNil(r.currentGap)

        let ongoing = Insights.recovery([days("xx..")], today: day(3))!
        XCTAssertEqual(ongoing.currentGap, 1)
        XCTAssertNil(ongoing.typicalDays)

        // Misses before the first kept day aren't slips.
        XCTAssertNil(Insights.recovery([days("...x")], today: day(3)))
    }

    func testStreakRiskFindsTheDayStreaksEndOn() {
        // Six weeks, kept every day except Sundays.
        let weeks = days(String(repeating: "xxxxxx.", count: 6))
        let risk = Insights.streakRisk([weeks])!
        XCTAssertEqual(risk.weekday, 7)
        XCTAssertEqual(risk.rate, 100)
        XCTAssertTrue(risk.standsOut)
    }

    func testLongestRunPrefersTheMostRecentTie() {
        let run = Insights.longestRun(days("xxx.xxx."))!
        XCTAssertEqual(run.length, 3)
        XCTAssertEqual(run.start, day(4))
        XCTAssertEqual(run.end, day(6))
    }

    func testPerfectWeeksOnlyCountFinishedWeeks() {
        let a = days(String(repeating: "x", count: 14) + "x.x")
        let b = days(String(repeating: "x", count: 17))
        let perfect = Insights.perfectDays([a, b], dueToday: 0, today: day(16))
        let weeks = Insights.perfectWeeks(perfect, today: day(16))
        XCTAssertEqual(weeks.count, 2)
        XCTAssertTrue(weeks.allSatisfy(\.kept))
        XCTAssertEqual(Insights.longestRun(weeks)?.length, 2)
    }

    func testBestMonthNeedsEnoughDueDays() {
        let march = days(String(repeating: "x", count: 20) + ".", from: 0)
        let april = days("xxxxx", from: 30) // all kept, but too few days to count
        let best = Insights.bestMonth([march, april])!
        XCTAssertEqual(cal.component(.month, from: best.month), 3)
        XCTAssertEqual(best.rate, 95)
    }

    func testTimeOfDaySplitsTheDay() {
        let t = Insights.timeOfDay([at(0, 7), at(1, 7, 30), at(2, 8), at(3, 19)])!
        XCTAssertEqual(t.peakHour, 7)
        XCTAssertEqual(t.beforeNoon, 75)
        XCTAssertEqual(t.morning, 75)
        XCTAssertEqual(t.evening, 25)
    }

    func testTypicalTimeHandlesMidnight() {
        let minute = Insights.typicalMinute([at(0, 23, 30), at(1, 0, 30), at(2, 23, 50)])!
        XCTAssertEqual(Insights.clock(minute), "23:50")
    }

    func testRoutinesFollowOrderAndGap() {
        // Walk → meditate → vitamins on four mornings; read in the evening.
        var walk: [Date] = [], meditate: [Date] = [], vitamins: [Date] = [], read: [Date] = []
        for n in 0..<4 {
            walk.append(at(n, 7))
            meditate.append(at(n, 7, 40))
            vitamins.append(at(n, 8, 10))
            read.append(at(n, 21))
        }
        // One morning out of order doesn't count.
        walk.append(at(5, 9)); meditate.append(at(5, 8))

        let routines = Insights.routines([walk, meditate, vitamins, read])
        XCTAssertEqual(routines.count, 1)
        XCTAssertEqual(routines[0].members, [0, 1, 2])
        XCTAssertEqual(routines[0].days, 4)
        XCTAssertEqual(routines[0].usualStart, 7 * 60)
    }
}
