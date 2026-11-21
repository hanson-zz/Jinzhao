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
    /// 已手动同步的苹果日历事件 ID；不随任务完成状态变化而删除。
    var calendarEventID: String? = nil
    /// 周视图时间块：开始时间与时长（分钟）。为空表示未排进日程。旧数据无此字段时为 nil。
    var scheduledStart: Date? = nil
    var scheduledMinutes: Int? = nil
    /// 看板状态："doing" 为进行中；nil / 其他为待办；完成以 isDone 为准。
    var boardStatus: String? = nil
    /// 来自哪篇笔记（笔记里的待办转任务时记录）
    var sourceNoteID: UUID? = nil

    var isDoing: Bool { !isDone && boardStatus == "doing" }
    var scheduledEnd: Date? {
        guard let s = scheduledStart else { return nil }
        return s.addingTimeInterval(Double(scheduledMinutes ?? 30) * 60)
    }

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
    /// 完成目标的日期列表（yyyy-MM-dd），习惯统计用；旧数据无此字段时为 nil
    var doneDays: [String]? = nil

    var isComplete: Bool { todayProgress >= targetPerDay }
    var fraction: Double { targetPerDay > 0 ? min(todayProgress / targetPerDay, 1) : 0 }
}

struct InboxItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var createdAt: Date
    var lunarNote: String? = nil        // 如「九月初九 · 10月18日 周日」
}

/// 笔记：块编辑（段落 / 标题 / 列表 / 待办），本地 JSON 落盘
struct NoteItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var blocks: [NoteBlock]
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool? = nil

    var plainText: String { blocks.map { $0.text }.joined(separator: "\n") }
    var preview: String {
        let t = blocks.map { $0.text.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        return t.isEmpty ? "空白笔记" : t
    }
    var openTodoCount: Int { blocks.filter { $0.kind == .todo && !($0.isDone ?? false) }.count }
}

struct NoteBlock: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case text, heading, bullet, todo, numbered, quote, image, table, divider
        var label: String {
            switch self {
            case .text: return "正文"
            case .heading: return "标题"
            case .bullet: return "列表"
            case .todo: return "待办"
            case .numbered: return "编号列表"
            case .quote: return "引用"
            case .image: return "图片"
            case .table: return "表格"
            case .divider: return "分割线"
            }
        }
        var symbol: String {
            switch self {
            case .text: return "text.alignleft"
            case .heading: return "textformat.size"
            case .bullet: return "list.bullet"
            case .todo: return "checkmark.square"
            case .numbered: return "list.number"
            case .quote: return "text.quote"
            case .image: return "photo"
            case .table: return "tablecells"
            case .divider: return "minus"
            }
        }
        /// 能在里面打字的块（图片 / 表格 / 分割线不能）
        var isTextual: Bool { ![.image, .table, .divider].contains(self) }
        /// 文字块之间可以互相切换的样式
        static let textKinds: [Kind] = [.text, .heading, .bullet, .numbered, .todo, .quote]
    }
    var id = UUID()
    var kind: Kind = .text
    var text: String = ""
    var isDone: Bool? = nil
    /// 转成任务后记下任务 ID，避免重复转
    var linkedTaskID: UUID? = nil
    /// 整行样式：加粗 / 斜体 / 下划线 / 删除线 / 文字颜色（颜色名，见 NoteBlock.colorNames）
    var bold: Bool? = nil
    var italic: Bool? = nil
    var underline: Bool? = nil
    var strike: Bool? = nil
    var color: String? = nil
    /// 图片块：存在「应用支持/Jinzhao/NoteImages/」下的文件名
    var imageFile: String? = nil
    /// 表格块：第一行是表头
    var table: [[String]]? = nil

    static let colorNames = ["red", "orange", "green", "blue", "purple", "gray"]
}

// 演示数据（DemoStore）已于第三片移除，真实数据见 DataStore（本地 JSON 落盘）。
