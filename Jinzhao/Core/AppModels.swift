import Foundation

// MARK: - 基础模型（v1 本地存储，先 Codable 落盘，后续可换 SwiftData）

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var note: String? = nil
    var dueDate: Date? = nil
    var reminderDate: Date? = nil
    var isImportant: Bool = false
    var isDone: Bool = false
    var doneAt: Date? = nil
    var folderName: String? = nil
    var tags: [String] = []
    var subtasks: [Subtask] = []
    /// 是否按农历重复（Pro）：如每年八月十五
    var lunarRepeat: Bool = false

    struct Subtask: Identifiable, Codable, Equatable {
        var id = UUID()
        var title: String
        var isDone: Bool = false
    }
}

struct CalendarEventItem: Identifiable, Equatable {
    var id: String = UUID().uuidString   // EventKit 接入后用 eventIdentifier
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool = false
    var location: String? = nil
    var meetingProvider: String? = nil   // 腾讯会议 / 飞书 / Zoom …
    var meetingURL: URL? = nil
    var colorName: String = "blue"
}

struct HabitItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var targetPerDay: Double = 1        // 如喝水 8 杯
    var unit: String = ""               // 杯 / 分钟 …
    var todayProgress: Double = 0
    var streakDays: Int = 0
    var scheduledTime: String? = nil    // "23:30" 早睡这类时间型习惯
    /// 最近一次完成目标的日期（yyyy-MM-dd），连续天数计算用；旧数据无此字段时为 nil
    var lastDoneDay: String? = nil

    var isComplete: Bool { todayProgress >= targetPerDay }
    var fraction: Double { targetPerDay > 0 ? min(todayProgress / targetPerDay, 1) : 0 }
}

struct InboxItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var createdAt: Date
    var lunarNote: String? = nil        // 如「九月初九 · 10月18日 周日」
}

// 演示数据（DemoStore）已于第三片移除，真实数据见 DataStore（本地 JSON 落盘）。
