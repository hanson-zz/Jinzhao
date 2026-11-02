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
    let id = UUID()
    var title: String
    var start: Date
    var end: Date
    var location: String? = nil
    var meetingProvider: String? = nil   // 腾讯会议 / 飞书 / Zoom
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

    var isComplete: Bool { todayProgress >= targetPerDay }
    var fraction: Double { targetPerDay > 0 ? min(todayProgress / targetPerDay, 1) : 0 }
}

struct InboxItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var createdAt: Date
    var lunarNote: String? = nil        // 如「九月初九 · 10月18日 周日」
}

// MARK: - 演示数据（与效果图一致，仅供 UI 开发与验收；正式版由本地存储替换）

@MainActor
final class DemoStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var events: [CalendarEventItem] = []
    @Published var habits: [HabitItem] = []
    @Published var inbox: [InboxItem] = []

    /// 效果图基准日：2026-10-08（周四）
    static var referenceDate: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 8))!
    }

    init() { loadDemo() }

    func loadDemo() {
        let cal = Calendar(identifier: .gregorian)
        func at(_ day: Int, _ h: Int, _ m: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))!
        }
        events = [
            CalendarEventItem(title: "销售部晨会 · 国庆后订单复盘", start: at(8, 9), end: at(8, 9, 30),
                              meetingProvider: "腾讯会议", colorName: "purple"),
            CalendarEventItem(title: "拜访麦香烘焙坊 · 送黄油和淡奶油样品", start: at(8, 10, 30), end: at(8, 12),
                              location: "朝阳区望京西路 车程 25 分钟", colorName: "orange"),
            CalendarEventItem(title: "新品试吃会筹备 · 场地确认", start: at(8, 15), end: at(8, 16),
                              location: "公司 3 楼会议室", colorName: "green"),
            CalendarEventItem(title: "季度回款对账", start: at(9, 9, 30), end: at(9, 10, 30),
                              location: "财务部 · 1 小时", colorName: "purple"),
        ]
        tasks = [
            TaskItem(title: "整理国庆期间客户补货订单", dueDate: at(8, 12), isImportant: true, folderName: "工作"),
            TaskItem(title: "给王经理回年货礼盒报价单", reminderDate: at(8, 14), folderName: "Q4 客户拜访",
                     subtasks: [.init(title: "核对礼盒成本", isDone: true),
                                .init(title: "确认黄油用量", isDone: true),
                                .init(title: "发报价单")]),
            TaskItem(title: "报销国庆前出差票据", isDone: true, doneAt: at(8, 8, 42)),
            TaskItem(title: "准备周六调休日的拜访路线", folderName: "3 家客户 · 海淀"),
        ]
        habits = [
            HabitItem(name: "喝水", targetPerDay: 8, unit: "杯", todayProgress: 5, streakDays: 12),
            HabitItem(name: "读书 20 分钟", targetPerDay: 1, todayProgress: 1, streakDays: 12),
            HabitItem(name: "早睡", targetPerDay: 1, todayProgress: 0, streakDays: 12, scheduledTime: "23:30"),
        ]
        inbox = [
            InboxItem(text: "问供应商新年礼盒包装价", createdAt: at(7, 21, 14)),
            InboxItem(text: "下周去趟原料仓库盘点", createdAt: at(5, 9)),
            InboxItem(text: "看看新出的奶油奶酪", createdAt: at(3, 9)),
            InboxItem(text: "重阳节给爸妈订饭店", createdAt: at(2, 9), lunarNote: "九月初九 · 10月18日 周日"),
        ]
    }
}
