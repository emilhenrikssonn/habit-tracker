import XCTest
import SwiftData
@testable import HabitTracker

@MainActor
final class BackupAndLinkTests: XCTestCase {
    private let cal = Calendar.current

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
    }

    private func context() throws -> ModelContext {
        let schema = Schema([Habit.self, HabitLog.self, AppPrefs.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    // MARK: Linked misses

    func testMissesTogetherGiveAStrongPositiveLink() {
        // 10 shared days; both missed on days 0–2, kept on the rest.
        let a = (0..<10).map { (date: day(-$0), kept: $0 >= 3) }
        let b = (0..<10).map { (date: day(-$0), kept: $0 >= 3) }
        let link = Insights.pairLink(a, b)
        XCTAssertEqual(link.sharedDays, 10)
        XCTAssertEqual(link.bWhenAMissed, 100)
        XCTAssertEqual(link.aWhenBMissed, 100)
        XCTAssertEqual(link.bMissRate, 30)
        XCTAssertEqual(link.score!, 1, accuracy: 0.0001)
        XCTAssertEqual(Insights.linkStrength(link.score!), "strong link")
    }

    func testOppositeMissesGiveANegativeLink() {
        let a = (0..<10).map { (date: day(-$0), kept: $0 % 2 == 0) }
        let b = (0..<10).map { (date: day(-$0), kept: $0 % 2 == 1) }
        let link = Insights.pairLink(a, b)
        XCTAssertEqual(link.bWhenAMissed, 0)
        XCTAssertEqual(link.score!, -1, accuracy: 0.0001)
        XCTAssertEqual(Insights.linkStrength(link.score!), "strong opposite link")
    }

    func testOnlyDaysBothAreDueCount() {
        let a = (0..<10).map { (date: day(-$0), kept: $0 != 1) }
        let b = [(date: day(-1), kept: false), (date: day(-2), kept: true), (date: day(-30), kept: false)]
        let link = Insights.pairLink(a, b)
        XCTAssertEqual(link.sharedDays, 2)
        XCTAssertEqual(link.missedBoth, 1)
    }

    func testNoScoreWhenAHabitWasNeverMissed() {
        let a = (0..<10).map { (date: day(-$0), kept: true) }
        let b = (0..<10).map { (date: day(-$0), kept: $0 < 5) }
        let link = Insights.pairLink(a, b)
        XCTAssertNil(link.score)
        XCTAssertNil(link.bWhenAMissed)
        XCTAssertEqual(link.aWhenBMissed, 0)
    }

    func testEveryScoreHasAMeaning() {
        XCTAssertEqual(Insights.linkMeaning(1), "You usually miss these two on the same days.")
        XCTAssertEqual(Insights.linkMeaning(0.63), "You usually miss these two on the same days.")
        XCTAssertEqual(Insights.linkMeaning(0.05), "Missing one says nothing about whether you'll miss the other.")
        XCTAssertEqual(Insights.linkMeaning(-0.1), "When you miss one, you're a little more likely to keep the other.")
        XCTAssertEqual(Insights.linkMeaning(-1), "When you miss one, you usually keep the other, as if they compete for the same time.")
    }

    func testWeekdaysRankBestFirst() {
        let ranked = Insights.rankWeekdays([
            1: (due: 10, kept: 5),   // 50%
            3: (due: 10, kept: 9),   // 90%
            5: (due: 4, kept: 4),    // 100%
            6: (due: 20, kept: 18),  // 90%, more kept than Wednesday
            7: (due: 0, kept: 0),    // nothing due: left out
        ])
        XCTAssertEqual(ranked.map(\.weekday), [5, 6, 3, 1])
        XCTAssertEqual(ranked.map(\.rate), [100, 90, 90, 50])
        XCTAssertEqual(ranked.first?.kept, 4)
    }

    func testScoreFormatting() {
        XCTAssertEqual(PairLinkBlock.formatScore(0.4234), "+0.42")
        XCTAssertEqual(PairLinkBlock.formatScore(-0.5), "-0.50")
        XCTAssertEqual(PairLinkBlock.formatScore(-0.001), "0.00")
    }

    // MARK: Backup

    func testBackupRoundTripsHabitsLogsAndSettings() throws {
        let source = try context()
        let prefs = AppPrefs()
        prefs.displayName = "Sam"
        prefs.customCategories = ["Garden"]
        prefs.eveningCheckinTime = "22:15"
        prefs.timeStatsEnabled = false
        source.insert(prefs)
        let read = Habit(name: "Read", category: .mind, tracking: .amount, unit: "pages", dailyGoal: 20)
        read.categoryRaw = "Garden"
        read.restWeekdays = [7]
        read.restDates = [day(-3)]
        read.reminder = "21:30"
        read.archived = true
        source.insert(read)
        let log = HabitLog(date: day(-1), value: 12.5, completed: false, note: "train")
        log.habit = read
        source.insert(log)
        try source.save()

        let data = try Backup.encode(Backup.make(in: source, defaults: UserDefaults(suiteName: "backup-test-src")!))
        let backup = try Backup.decode(data)

        let target = try context()
        let old = Habit(name: "Old", category: .health)
        target.insert(old)
        try target.save()
        let defaults = UserDefaults(suiteName: "backup-test-dst")!
        try Backup.restore(backup, into: target, defaults: defaults)

        let habits = try target.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.map(\.name), ["Read"])
        let restored = habits[0]
        XCTAssertEqual(restored.id, read.id)
        XCTAssertEqual(restored.categoryRaw, "Garden")
        XCTAssertEqual(restored.tracking, .amount)
        XCTAssertEqual(restored.unit, "pages")
        XCTAssertEqual(restored.dailyGoal, 20)
        XCTAssertEqual(restored.restWeekdays, [7])
        XCTAssertEqual(restored.restDates, [day(-3)])
        XCTAssertEqual(restored.reminder, "21:30")
        XCTAssertTrue(restored.archived)
        XCTAssertEqual(restored.logs.count, 1)
        XCTAssertEqual(restored.logs[0].date, day(-1))
        XCTAssertEqual(restored.logs[0].value, 12.5)
        XCTAssertEqual(restored.logs[0].note, "train")
        XCTAssertEqual(try target.fetch(FetchDescriptor<HabitLog>()).count, 1)

        let restoredPrefs = try target.fetch(FetchDescriptor<AppPrefs>())
        XCTAssertEqual(restoredPrefs.count, 1)
        XCTAssertEqual(restoredPrefs[0].displayName, "Sam")
        XCTAssertEqual(restoredPrefs[0].customCategories, ["Garden"])
        XCTAssertEqual(restoredPrefs[0].eveningCheckinTime, "22:15")
        XCTAssertTrue(restoredPrefs[0].hasOnboarded)
        XCTAssertFalse(restoredPrefs[0].timeStatsEnabled)
    }

    func testBackupsFromBeforeTimeStatsSettingStillRestore() throws {
        let source = try context()
        let prefs = AppPrefs()
        source.insert(prefs)
        try source.save()
        // Drop the key, as in a backup made before the setting existed.
        var json = try JSONSerialization.jsonObject(with: Backup.encode(Backup.make(in: source))) as! [String: Any]
        var settings = json["settings"] as! [String: Any]
        settings.removeValue(forKey: "timeStatsEnabled")
        json["settings"] = settings
        let backup = try Backup.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(backup.settings.timeStatsEnabled)

        let target = try context()
        let targetPrefs = AppPrefs()
        targetPrefs.timeStatsEnabled = false
        target.insert(targetPrefs)
        try target.save()
        try Backup.restore(backup, into: target, defaults: UserDefaults(suiteName: "backup-test-old")!)
        XCTAssertEqual(try target.fetch(FetchDescriptor<AppPrefs>()).first?.timeStatsEnabled, true)
    }

    func testRestoreCleansBadValues() throws {
        var backup = Backup.make(in: try context())
        backup.settings.morningPlanTime = "25:99"
        backup.habits = [BackupFile.HabitRecord(
            id: UUID(), name: "  Walk\nfar  " + String(repeating: "x", count: 200), category: "health", type: "nonsense",
            tracking: "amount", unit: "km", dailyGoal: .infinity, repeatMode: "weekly", weekdays: [0, 9],
            timesPerWeek: 40, datesOfMonth: [], activeStart: "not a date", activeEnd: nil, timeOfDay: "Anytime",
            restWeekdays: [1, 2, 3, 4, 5, 6, 7], restDates: ["2026-02-30"], reminder: "7:5", archived: false,
            createdAt: Date(), sortIndex: 0,
            logs: [
                BackupFile.LogRecord(day: Backup.dayString(day(-1)), value: -5, completed: true, skipped: false, note: "", completedAt: nil),
                BackupFile.LogRecord(day: Backup.dayString(day(-1)), value: 3, completed: true, skipped: false, note: "", completedAt: nil),
                BackupFile.LogRecord(day: Backup.dayString(day(-2)), value: 1e300, completed: true, skipped: false, note: "", completedAt: nil),
            ]
        )]
        let ctx = try context()
        try Backup.restore(backup, into: ctx, defaults: UserDefaults(suiteName: "backup-test-clean")!)

        let h = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Habit>()).first)
        XCTAssertTrue(h.name.hasPrefix("Walk far"))
        XCTAssertEqual(h.name.count, TextLimit.habitName)
        XCTAssertEqual(h.type, .build)
        XCTAssertEqual(h.dailyGoal, 1)
        XCTAssertEqual(h.weekdays, Array(1...7))
        XCTAssertEqual(h.timesPerWeek, 7)
        XCTAssertEqual(h.restWeekdays, [])
        XCTAssertEqual(h.restDates, [])
        XCTAssertNil(h.reminder)
        XCTAssertEqual(h.activeStart, cal.startOfDay(for: Date()))
        let logs = h.logs.sorted { $0.date < $1.date }
        XCTAssertEqual(logs.count, 2, "a second log for the same day is dropped")
        XCTAssertEqual(logs.map(\.value), [AmountEntryAlert.maxValue, 0])
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<AppPrefs>()).first?.morningPlanTime, "07:30")
    }

    func testOtherFilesAreRejected() {
        XCTAssertThrowsError(try Backup.decode(Data("hello".utf8)))
        XCTAssertThrowsError(try Backup.decode(Data(#"{"format":"something-else"}"#.utf8)))
        var newer = Backup.make(in: try! context())
        newer.version = BackupFile.currentVersion + 1
        XCTAssertThrowsError(try Backup.decode(try Backup.encode(newer))) { error in
            XCTAssertEqual(error as? BackupError, .newerVersion)
        }
    }

    func testClockAndDayParsing() {
        XCTAssertEqual(Backup.clock("07:30"), "07:30")
        XCTAssertNil(Backup.clock("7:30"))
        XCTAssertNil(Backup.clock("24:00"))
        XCTAssertNil(Backup.clock("12:60"))
        XCTAssertEqual(Backup.day("2026-11-18"), cal.date(from: DateComponents(year: 2026, month: 11, day: 18)))
        XCTAssertNil(Backup.day("2026-02-30"))
        XCTAssertNil(Backup.day("18/11/2026"))
    }
}
