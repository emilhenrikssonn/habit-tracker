import Foundation
import SwiftData

/// A full copy of the person's habits, history and settings as one JSON file, for moving to a new
/// phone. The app never uploads it: the person saves or sends the file themselves from the share sheet,
/// and picks it from Files to restore. Restoring replaces everything currently on the phone.
struct BackupFile: Codable {
    static let formatName = "habits-backup"
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var settings: Settings
    var habits: [HabitRecord]

    struct Settings: Codable {
        var displayName: String
        var defaultView: String
        var customCategories: [String]
        var habitRemindersEnabled: Bool
        var morningPlanEnabled: Bool
        var morningPlanTime: String
        var eveningCheckinEnabled: Bool
        var eveningCheckinTime: String
        var streakRescueEnabled: Bool
        var streakRescueMinDays: Int
        var streakRescueAlertTime: String
        var weeklyReportEnabled: Bool
        var weeklyReportWeekday: Int
        /// Missing in backups made before this setting existed.
        var timeStatsEnabled: Bool?
        /// 1 = Monday, 7 = Sunday.
        var weekStart: Int?
        var theme: String?
    }

    /// Calendar days (start date, rest days, log days) are stored as "yyyy-MM-dd", so a backup
    /// restored in another time zone keeps every log on the same day.
    struct HabitRecord: Codable {
        var id: UUID
        var name: String
        var category: String
        var type: String
        var tracking: String
        var unit: String
        var dailyGoal: Double
        var repeatMode: String
        var weekdays: [Int]
        var timesPerWeek: Int
        var datesOfMonth: [Int]
        var activeStart: String
        var activeEnd: String?
        var timeOfDay: String
        var restWeekdays: [Int]
        var restDates: [String]
        var reminder: String?
        var archived: Bool
        var createdAt: Date
        var sortIndex: Int
        var logs: [LogRecord]
    }

    struct LogRecord: Codable {
        var day: String
        var value: Double
        var completed: Bool
        var skipped: Bool
        var note: String
        var completedAt: Date?
    }
}

enum BackupError: LocalizedError {
    case unreadable, notABackup, newerVersion, tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable: return "The file couldn't be read."
        case .notABackup: return "This file isn't a Habits backup."
        case .newerVersion: return "This backup was made by a newer version of Habits. Update the app and try again."
        case .tooLarge: return "This backup is larger than Habits can restore."
        }
    }
}

enum Backup {
    /// Limits on what a backup may hold, so a damaged or hostile file can't exhaust memory.
    static let maxFileBytes = 50 * 1024 * 1024
    static let maxHabits = 1_000
    static let maxLogs = 1_000_000
    static let maxNoteLength = 500

    // MARK: Writing

    static func make(in ctx: ModelContext, defaults: UserDefaults = .standard, now: Date = Date()) -> BackupFile {
        let prefs = (try? ctx.fetch(FetchDescriptor<AppPrefs>()))?.first ?? AppPrefs()
        let habits = (try? ctx.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let settings = BackupFile.Settings(
            displayName: prefs.displayName,
            defaultView: prefs.defaultViewRaw,
            customCategories: prefs.customCategories,
            habitRemindersEnabled: prefs.habitRemindersEnabled,
            morningPlanEnabled: prefs.morningPlanEnabled,
            morningPlanTime: prefs.morningPlanTime,
            eveningCheckinEnabled: prefs.eveningCheckinEnabled,
            eveningCheckinTime: prefs.eveningCheckinTime,
            streakRescueEnabled: prefs.streakRescueEnabled,
            streakRescueMinDays: prefs.streakRescueMinDays,
            streakRescueAlertTime: prefs.streakRescueAlertTime,
            weeklyReportEnabled: prefs.weeklyReportEnabled,
            weeklyReportWeekday: prefs.weeklyReportWeekday,
            timeStatsEnabled: prefs.timeStatsEnabled,
            weekStart: defaults.integer(forKey: "weekStart") == 7 ? 7 : 1,
            theme: defaults.string(forKey: AppTheme.storageKey)
        )
        return BackupFile(format: BackupFile.formatName, version: BackupFile.currentVersion,
                          exportedAt: now, settings: settings, habits: habits.map(record))
    }

    private static func record(_ h: Habit) -> BackupFile.HabitRecord {
        let sortedLogs: [HabitLog] = h.logs.sorted { $0.date < $1.date }
        let logs: [BackupFile.LogRecord] = sortedLogs.map(logRecord)
        let restDates: [String] = h.restDates.map(dayString)
        let activeEnd: String? = h.activeEnd.map(dayString)
        return BackupFile.HabitRecord(
            id: h.id, name: h.name, category: h.categoryRaw, type: h.typeRaw, tracking: h.trackingRaw,
            unit: h.unit, dailyGoal: h.dailyGoal, repeatMode: h.repeatModeRaw, weekdays: h.weekdays,
            timesPerWeek: h.timesPerWeek, datesOfMonth: h.datesOfMonth,
            activeStart: dayString(h.activeStart), activeEnd: activeEnd,
            timeOfDay: h.timeOfDay, restWeekdays: h.restWeekdays, restDates: restDates,
            reminder: h.reminder, archived: h.archived, createdAt: h.createdAt, sortIndex: h.sortIndex,
            logs: logs
        )
    }

    private static func logRecord(_ log: HabitLog) -> BackupFile.LogRecord {
        BackupFile.LogRecord(day: dayString(log.date), value: log.value, completed: log.completed,
                             skipped: log.skipped, note: log.note, completedAt: log.completedAt)
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Writes the backup to a temporary file for the share sheet.
    static func file(in ctx: ModelContext) -> URL? {
        let day = Date().formatted(Date.ISO8601FormatStyle().year().month().day())
        guard let data = try? encode(make(in: ctx)) else { return nil }
        return ExportFolder.write(data, named: "Habits backup \(day).json")
    }

    // MARK: Reading

    /// Reads and checks a backup the person picked in Files.
    static func read(from url: URL) throws -> BackupFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxFileBytes {
            throw BackupError.tooLarge
        }
        guard let data = try? Data(contentsOf: url) else { throw BackupError.unreadable }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        guard data.count <= maxFileBytes else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: data),
              backup.format == BackupFile.formatName else { throw BackupError.notABackup }
        guard backup.version <= BackupFile.currentVersion else { throw BackupError.newerVersion }
        guard backup.habits.count <= maxHabits,
              backup.habits.reduce(0, { $0 + $1.logs.count }) <= maxLogs else { throw BackupError.tooLarge }
        return backup
    }

    // MARK: Restoring

    /// Replaces every habit, log and setting with the backup's. Every value is checked on the way in,
    /// so a hand-edited file can't store anything the app couldn't have stored itself.
    /// Nothing changes if saving fails.
    static func restore(_ backup: BackupFile, into ctx: ModelContext, defaults: UserDefaults = .standard) throws {
        let cal = Calendar.current
        do {
            for habit in try ctx.fetch(FetchDescriptor<Habit>()) { ctx.delete(habit) }
            for log in try ctx.fetch(FetchDescriptor<HabitLog>()) { ctx.delete(log) }

            let prefs = try ctx.fetch(FetchDescriptor<AppPrefs>()).first ?? {
                let p = AppPrefs(); ctx.insert(p); return p
            }()
            let s = backup.settings
            let name = s.displayName.cleanedInput(maxLength: TextLimit.displayName)
            prefs.displayName = name.isEmpty ? "You" : name
            prefs.defaultView = HomeViewStyle(rawValue: s.defaultView) ?? .list
            var categories: [String] = []
            for raw in s.customCategories {
                let c = raw.cleanedInput(maxLength: TextLimit.category)
                if !c.isEmpty, !categories.contains(c), categories.count < 100 { categories.append(c) }
            }
            prefs.customCategories = categories
            prefs.habitRemindersEnabled = s.habitRemindersEnabled
            prefs.morningPlanEnabled = s.morningPlanEnabled
            prefs.morningPlanTime = clock(s.morningPlanTime) ?? prefs.morningPlanTime
            prefs.eveningCheckinEnabled = s.eveningCheckinEnabled
            prefs.eveningCheckinTime = clock(s.eveningCheckinTime) ?? prefs.eveningCheckinTime
            prefs.streakRescueEnabled = s.streakRescueEnabled
            prefs.streakRescueMinDays = min(max(s.streakRescueMinDays, 1), 365)
            prefs.streakRescueAlertTime = clock(s.streakRescueAlertTime) ?? prefs.streakRescueAlertTime
            prefs.weeklyReportEnabled = s.weeklyReportEnabled
            prefs.weeklyReportWeekday = (1...7).contains(s.weeklyReportWeekday) ? s.weeklyReportWeekday : 7
            prefs.timeStatsEnabled = s.timeStatsEnabled ?? true
            prefs.hasOnboarded = true

            var seenIDs = Set<UUID>()
            for r in backup.habits {
                let id = seenIDs.insert(r.id).inserted ? r.id : UUID()
                let tracking = r.tracking == "count" ? TrackingType.amount : (TrackingType(rawValue: r.tracking) ?? .done)
                let habitName = r.name.cleanedInput(maxLength: TextLimit.habitName)
                let category = HabitCategory(rawValue: r.category)?.rawValue
                    ?? r.category.cleanedInput(maxLength: TextLimit.category)
                let start = day(r.activeStart) ?? cal.startOfDay(for: Date())

                let h = Habit(name: habitName.isEmpty ? "Habit" : habitName, category: .health)
                h.id = id
                h.categoryRaw = category.isEmpty ? HabitCategory.health.rawValue : category
                h.type = HabitType(rawValue: r.type) ?? .build
                h.tracking = tracking
                switch tracking {
                case .done:
                    h.unit = ""
                    h.dailyGoal = 1
                case .time:
                    h.unit = "min"
                    h.dailyGoal = amount(r.dailyGoal, minimum: 1)
                case .amount:
                    h.unit = r.unit.cleanedInput(maxLength: TextLimit.unit)
                    h.dailyGoal = amount(r.dailyGoal, minimum: 1)
                }
                h.repeatMode = RepeatMode(rawValue: r.repeatMode) ?? .daily
                h.weekdays = days(r.weekdays, in: 1...7, fallback: Array(1...7))
                h.timesPerWeek = min(max(r.timesPerWeek, 1), 7)
                h.datesOfMonth = days(r.datesOfMonth, in: 1...31, fallback: [])
                h.activeStart = start
                h.activeEnd = r.activeEnd.flatMap(day)
                h.timeOfDay = r.timeOfDay.cleanedInput(maxLength: 30)
                // Resting all seven days would mean the habit is never due; the app doesn't allow that.
                let rest = days(r.restWeekdays, in: 1...7, fallback: [])
                h.restWeekdays = rest.count >= 7 ? [] : rest
                h.restDates = Array(Set(r.restDates.prefix(5_000).compactMap(day))).sorted()
                h.reminder = r.reminder.flatMap(clock)
                h.archived = r.archived
                h.createdAt = r.createdAt
                h.sortIndex = r.sortIndex
                h.timerStartedAt = nil
                ctx.insert(h)

                var loggedDays = Set<Date>()
                for l in r.logs {
                    guard let date = day(l.day), loggedDays.insert(date).inserted else { continue }
                    let log = HabitLog(date: date, value: amount(l.value, minimum: 0), completed: l.completed,
                                       skipped: l.skipped, note: l.note.cleanedInput(maxLength: maxNoteLength))
                    log.completedAt = l.completed ? l.completedAt : nil
                    log.habit = h
                    ctx.insert(log)
                }
            }

            try ctx.save()
        } catch {
            ctx.rollback()
            throw error
        }

        defaults.set(backup.settings.weekStart == 7 ? 7 : 1, forKey: "weekStart")
        if let theme = backup.settings.theme.flatMap(AppTheme.init(rawValue:)) {
            defaults.set(theme.rawValue, forKey: AppTheme.storageKey)
        }
    }

    // MARK: Helpers

    /// Built once: a formatter is slow to create and a backup can hold years of logs.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f
    }()

    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    /// The start of that calendar day here, or nil for anything that isn't a real yyyy-MM-dd date.
    static func day(_ string: String) -> Date? {
        guard string.count == 10, let date = dayFormatter.date(from: string) else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    /// "HH:mm" with a real hour and minute, or nil.
    static func clock(_ string: String) -> String? {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ $0.count == 2 }),
              let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return String(format: "%02d:%02d", h, m)
    }

    private static func amount(_ value: Double, minimum: Double) -> Double {
        guard value.isFinite else { return minimum }
        return min(max(value, minimum), AmountEntryAlert.maxValue)
    }

    private static func days(_ values: [Int], in range: ClosedRange<Int>, fallback: [Int]) -> [Int] {
        let valid = Array(Set(values.filter(range.contains))).sorted()
        return valid.isEmpty ? fallback : valid
    }
}

/// Exported files are written to one temporary folder that's emptied before each export,
/// so old copies of the person's data don't pile up on the phone.
enum ExportFolder {
    static func write(_ data: Data, named name: String) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
