import Foundation

/// 真实数据存储：任务 / 习惯 / 收件箱以 JSON 落盘到 ~/Library/Application Support/Jinzhao/data.json
/// 本地存储、断网可用（产品定版）。日程在 EventKit 接入前为空数组，界面优雅降级。
@MainActor
final class DataStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] { didSet { save() } }
    @Published var habits: [HabitItem] = [] { didSet { save() } }
    @Published var inbox: [InboxItem] = [] { didSet { save() } }
    @Published var notes: [NoteItem] = [] { didSet { save() } }
    // 日程不在这里：由 CalendarService 实时读苹果日历

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
        // 修 bug：App 一直开着跨过零点，习惯进度不会清零，第二天点一下会被算成「今天已完成」
        dayObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rolloverIfNeeded() }
        }
    }

    private var dayObserver: NSObjectProtocol?

    // MARK: - 持久化

    private struct Persisted: Codable {
        var tasks: [TaskItem]
        var habits: [HabitItem]
        var inbox: [InboxItem]
        var habitDay: String
        /// 0.2 新增；旧版 data.json 没有这个键，解码为 nil，不影响旧数据
        var notes: [NoteItem]?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let p = try? JSONDecoder().decode(Persisted.self, from: data) else {
            // 读不出来时先备份原文件，避免下一次保存把旧数据覆盖掉
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("data-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            return
        }
        isLoading = true
        tasks = p.tasks
        habits = p.habits
        inbox = p.inbox
        habitDay = p.habitDay
        notes = p.notes ?? []
        isLoading = false
        rolloverIfNeeded()
    }

    /// 跨天：今日进度清零；连续天数校验（最后完成日既不是今天也不是昨天 → 断签归零）。
    /// 启动时调用一次；App 开着过了零点时由 NSCalendarDayChanged 再调用。
    func rolloverIfNeeded() {
        if habitDay != DataStore.todayKey() {
            let today = DataStore.todayKey()
            let yesterday = DataStore.dayKey(offsetDays: -1)
            habitDay = today   // 先改日期，下面改 habits 触发保存时写进去的就是新日期
            for i in habits.indices {
                habits[i].todayProgress = 0
                if let last = habits[i].lastDoneDay, last != today, last != yesterday {
                    habits[i].streakDays = 0
                }
            }
        }
    }

    private func save() {
        guard !isLoading else { return }
        let p = Persisted(tasks: tasks, habits: habits, inbox: inbox, habitDay: habitDay, notes: notes)
        guard let data = try? JSONEncoder().encode(p) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func todayKey() -> String { dayKey(offsetDays: 0) }

    nonisolated static func key(for date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func dayKey(offsetDays: Int) -> String {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: offsetDays, to: Date()) ?? Date()
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - 任务操作

    func addTask(title: String, dueDate: Date? = nil, folderName: String? = nil, priority: TaskPriority = .none) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var item = TaskItem(title: t, dueDate: dueDate, folderName: folderName)
        if priority != .none { item.priority = priority.rawValue; item.isImportant = priority == .high }
        tasks.append(item)
    }

    /// 仅在 EventKit 保存成功之后记录关联 ID。本地任务不会因为日历写入失败而改变。
    func linkCalendarEvent(taskID: UUID, eventID: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].calendarEventID = eventID
    }

    func toggleTask(_ task: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i].isDone.toggle()
        tasks[i].doneAt = tasks[i].isDone ? Date() : nil
        if tasks[i].isDone { tasks[i].boardStatus = nil }
    }

    /// 「重要」= 高优先级；切换时两者保持一致
    func toggleImportant(_ task: TaskItem) {
        setPriority(task.id, task.priorityLevel == .high ? .none : .high)
    }

    func setPriority(_ id: UUID, _ p: TaskPriority) {
        updateTask(id) { t in
            t.priority = p.rawValue
            t.isImportant = p == .high
        }
    }

    // MARK: - 任务 ↔ 日程关联

    func tasks(linkedTo eventID: String) -> [TaskItem] {
        tasks.filter { $0.linkedEventID == eventID }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                return a.priorityLevel.rawValue > b.priorityLevel.rawValue
            }
    }

    func linkTask(_ id: UUID, to event: CalendarEventItem) {
        updateTask(id) { t in
            t.linkedEventID = event.id
            t.linkedEventTitle = event.title
        }
    }

    func unlinkTask(_ id: UUID) {
        updateTask(id) { t in
            t.linkedEventID = nil
            t.linkedEventTitle = nil
        }
    }

    /// 在日程里直接新建任务：默认截止在日程开始时间
    func addTask(title: String, linkedTo event: CalendarEventItem) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var item = TaskItem(title: t, dueDate: event.isAllDay ? nil : event.start)
        item.linkedEventID = event.id
        item.linkedEventTitle = event.title
        tasks.append(item)
    }

    /// 统一排序：未完成在前，优先级高在前，截止早在前
    nonisolated static func byPriorityThenDue(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.priorityLevel != b.priorityLevel { return a.priorityLevel.rawValue > b.priorityLevel.rawValue }
        return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
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

    /// 点一下进度 +1（喝水这类计数习惯）；已满则回到 0，方便纠正。
    /// 完成瞬间更新连续天数：昨天完成了则 +1，否则从 1 重新开始；撤销完成则回退。
    func advanceHabit(_ habit: HabitItem) {
        rolloverIfNeeded()   // 兜底：睡眠唤醒等情况可能错过跨天通知
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let today = DataStore.todayKey()
        let yesterday = DataStore.dayKey(offsetDays: -1)
        if habits[i].todayProgress >= habits[i].targetPerDay {
            habits[i].todayProgress = 0
            habits[i].doneDays = (habits[i].doneDays ?? []).filter { $0 != today }
            if habits[i].lastDoneDay == today {
                habits[i].streakDays = max(0, habits[i].streakDays - 1)
                habits[i].lastDoneDay = habits[i].streakDays > 0 ? yesterday : nil
            }
        } else {
            habits[i].todayProgress += 1
            if habits[i].todayProgress >= habits[i].targetPerDay, habits[i].lastDoneDay != today {
                habits[i].streakDays = (habits[i].lastDoneDay == yesterday) ? habits[i].streakDays + 1 : 1
                habits[i].lastDoneDay = today
            }
            if habits[i].todayProgress >= habits[i].targetPerDay {
                var days = habits[i].doneDays ?? []
                if !days.contains(today) { days.append(today) }
                habits[i].doneDays = days
            }
        }
    }

    func addHabit(name: String, targetPerDay: Double = 1, unit: String = "") {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        habits.append(HabitItem(name: n, targetPerDay: targetPerDay, unit: unit))
    }

    func renameHabit(_ habit: HabitItem, name: String, targetPerDay: Double, unit: String) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { habits[i].name = n }
        habits[i].targetPerDay = max(1, targetPerDay)
        habits[i].unit = unit
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

    /// 收件箱分流：转成任务（解析中文日期）
    func inboxToTask(_ item: InboxItem) {
        let parsed = DatePhraseParser.parse(item.text)
        addTask(title: parsed.title, dueDate: parsed.due)
        deleteInbox(item)
    }

    /// 收件箱分流：转成笔记，返回新笔记 ID
    @discardableResult
    func inboxToNote(_ item: InboxItem) -> UUID {
        let id = addNote(title: String(item.text.prefix(20)), body: item.text)
        deleteInbox(item)
        return id
    }

    // MARK: - 任务：时间块 / 看板 / 编辑

    func updateTask(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        var t = tasks[i]
        change(&t)
        tasks[i] = t
    }

    /// 排进日程：开始时间吸附到 15 分钟
    func schedule(taskID: UUID, at start: Date, minutes: Int? = nil) {
        let snapped = DataStore.snap(start)
        updateTask(taskID) { t in
            t.scheduledStart = snapped
            t.scheduledMinutes = minutes ?? t.scheduledMinutes ?? 30
        }
    }

    func unschedule(taskID: UUID) {
        updateTask(taskID) { t in
            t.scheduledStart = nil   // 保留 scheduledMinutes 作为预计时长
        }
    }

    nonisolated static func snap(_ date: Date, minutes step: Int = 15) -> Date {
        let cal = Calendar(identifier: .gregorian)
        var c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let m = c.minute ?? 0
        c.minute = Int((Double(m) / Double(step)).rounded()) * step
        return cal.date(from: c) ?? date
    }

    /// 看板拖动：todo / doing / done
    func setBoardColumn(taskID: UUID, column: String) {
        updateTask(taskID) { t in
            switch column {
            case "done":
                if !t.isDone { t.isDone = true; t.doneAt = Date() }
                t.boardStatus = nil
            case "doing":
                t.isDone = false; t.doneAt = nil
                t.boardStatus = "doing"
            default:
                t.isDone = false; t.doneAt = nil
                t.boardStatus = nil
            }
        }
    }

    func renameTask(_ id: UUID, title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        updateTask(id) { $0.title = t }
    }

    // MARK: - 笔记

    @discardableResult
    func addNote(title: String = "", body: String = "") -> UUID {
        let now = Date()
        let blocks = body.isEmpty ? [NoteBlock()] :
            body.components(separatedBy: "\n").map { NoteBlock(kind: .text, text: $0) }
        let note = NoteItem(title: title, blocks: blocks, createdAt: now, updatedAt: now)
        notes.insert(note, at: 0)
        return note.id
    }

    func updateNote(_ id: UUID, _ change: (inout NoteItem) -> Void) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        var n = notes[i]
        change(&n)
        n.updatedAt = Date()
        notes[i] = n
    }

    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
    }

    /// 笔记里的待办转任务：已转过的不重复建
    func convertBlockToTask(noteID: UUID, blockID: UUID) {
        guard let ni = notes.firstIndex(where: { $0.id == noteID }),
              let bi = notes[ni].blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let block = notes[ni].blocks[bi]
        if let linked = block.linkedTaskID, tasks.contains(where: { $0.id == linked }) { return }
        let parsed = DatePhraseParser.parse(block.text)
        guard !parsed.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var task = TaskItem(title: parsed.title, dueDate: parsed.due)
        task.sourceNoteID = noteID
        tasks.append(task)
        updateNote(noteID) { n in
            if let j = n.blocks.firstIndex(where: { $0.id == blockID }) {
                n.blocks[j].linkedTaskID = task.id
                n.blocks[j].kind = .todo
            }
        }
    }
}
