import Foundation

/// 真实数据存储：任务 / 习惯 / 收件箱以 JSON 落盘到 ~/Library/Application Support/Jinzhao/data.json
/// 本地存储、断网可用（产品定版）。日程在 EventKit 接入前为空数组，界面优雅降级。
@MainActor
final class DataStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] { didSet { save() } }
    @Published var habits: [HabitItem] = [] { didSet { save() } }
    @Published var inbox: [InboxItem] = [] { didSet { save() } }
    /// 日程（下一片接 EventKit 读写苹果日历）
    @Published var events: [CalendarEventItem] = []

    private let fileURL: URL
    private var isLoading = false
    /// 习惯进度属于哪一天（yyyy-MM-dd），跨天打开时清零今日进度
    private var habitDay: String = ""

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jinzhao", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")
        habitDay = DataStore.todayKey()
        load()
    }

    // MARK: - 持久化

    private struct Persisted: Codable {
        var tasks: [TaskItem]
        var habits: [HabitItem]
        var inbox: [InboxItem]
        var habitDay: String
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        isLoading = true
        tasks = p.tasks
        habits = p.habits
        inbox = p.inbox
        habitDay = p.habitDay
        isLoading = false
        // 跨天：今日进度清零（连续天数保留，后续接打卡历史再精确计算）
        if habitDay != DataStore.todayKey() {
            for i in habits.indices { habits[i].todayProgress = 0 }
            habitDay = DataStore.todayKey()
        }
    }

    private func save() {
        guard !isLoading else { return }
        let p = Persisted(tasks: tasks, habits: habits, inbox: inbox, habitDay: habitDay)
        guard let data = try? JSONEncoder().encode(p) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func todayKey() -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - 任务操作

    func addTask(title: String, dueDate: Date? = nil, folderName: String? = nil) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        tasks.append(TaskItem(title: t, dueDate: dueDate, folderName: folderName))
    }

    func toggleTask(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isDone.toggle()
        tasks[i].doneAt = tasks[i].isDone ? Date() : nil
    }

    func toggleImportant(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isImportant.toggle()
    }

    func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
    }

    func addSubtask(task: TaskItem, title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].subtasks.append(TaskItem.Subtask(title: t))
    }

    func toggleSubtask(task: TaskItem, subtask: TaskItem.Subtask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }),
              let j = tasks[i].subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        tasks[i].subtasks[j].isDone.toggle()
    }

    // MARK: - 习惯操作

    /// 点一下进度 +1（喝水这类计数习惯）；已满则回到 0，方便纠正
    func advanceHabit(_ habit: HabitItem) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        if habits[i].todayProgress >= habits[i].targetPerDay {
            habits[i].todayProgress = 0
        } else {
            habits[i].todayProgress += 1
        }
    }

    func addHabit(name: String, targetPerDay: Double = 1, unit: String = "") {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        habits.append(HabitItem(name: n, targetPerDay: targetPerDay, unit: unit))
    }

    func deleteHabit(_ habit: HabitItem) {
        habits.removeAll { $0.id == habit.id }
    }

    // MARK: - 收件箱操作

    func addInbox(text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        inbox.insert(InboxItem(text: t, createdAt: Date()), at: 0)
    }

    func deleteInbox(_ item: InboxItem) {
        inbox.removeAll { $0.id == item.id }
    }
}
