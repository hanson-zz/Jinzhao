import SwiftUI

/// 任务页：添加（可带截止日期）/ 打勾 / 标重要 / 子任务 / 删除，全部即时落盘
struct TasksView: View {
    @EnvironmentObject private var store: DataStore
    @State private var newTitle = ""
    @State private var dueDate: Date? = nil      // 由中文日期解析或日历胶囊设置
    @State private var dueManual = false         // 手动选过日期后，输入解析不再覆盖
    @State private var showDuePicker = false
    @State private var expanded: Set<UUID> = []
    @State private var subtaskDrafts: [UUID: String] = [:]
    @FocusState private var newTitleFocused: Bool

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var openTasks: [TaskItem] {
        store.tasks.filter { !$0.isDone }.sorted { a, b in
            if a.isImportant != b.isImportant { return a.isImportant }
            let ad = a.dueDate ?? .distantFuture
            let bd = b.dueDate ?? .distantFuture
            return ad < bd
        }
    }

    private var doneTasks: [TaskItem] {
        store.tasks.filter { $0.isDone }
            .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
    }

    var body: some View {
        GlassCard {
          if store.tasks.isEmpty {
            // 空状态：不进滚动区，固定在中栏上三分之一处
            VStack(alignment: .leading, spacing: 16) {
                header
                addBar
                HStack { Spacer(); emptyState; Spacer() }
                    .padding(.top, 56)
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    addBar
                    if !openTasks.isEmpty {
                        sectionTitle("待办 · \(openTasks.count)")
                        ForEach(openTasks) { task in
                            taskRow(task)
                        }
                    }
                    if !doneTasks.isEmpty {
                        sectionTitle("已完成 · \(doneTasks.count)")
                            .padding(.top, 6)
                        ForEach(doneTasks) { task in
                            taskRow(task)
                        }
                    }
                }
                .padding(20)
            }
          }
        }
        // 菜单「新建任务」：外壳切到任务页后发来聚焦信号
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoFocusTaskField)) { _ in
            newTitleFocused = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("任务").font(.system(size: 24, weight: .bold))
            Text("\(openTasks.count) 项待办")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle").foregroundStyle(.secondary)
            TextField("新任务，回车添加", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($newTitleFocused)
                .onSubmit(addTask)
                .onChange(of: newTitle) { _, value in
                    // 输入即解析中文日期（如「明天下午三点开会」）；手动选过日期后不再覆盖
                    if !dueManual { dueDate = DatePhraseParser.parse(value).due }
                }
            dueCapsule
            // 蓝色「添加」按钮去掉：回车即添加；有文字时只给一个玻璃按钮
            if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("添加", action: addTask).glassButton()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: 11))
    }

    /// 截止胶囊：日历图标，选好日期后显示日期；点击弹出快捷选项 + 日期时间选择
    private var dueCapsule: some View {
        Button { showDuePicker = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                if let d = dueDate { Text(dueLabel(d)) }
            }
            .font(.jzCaption)
        }
        .glassButton()
        .popover(isPresented: $showDuePicker, arrowEdge: .bottom) {
            duePicker
        }
    }

    private var duePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button("今天") { setQuick(day: Date()) }
                Button("明天") { setQuick(day: cal.date(byAdding: .day, value: 1, to: Date())!) }
                Button("下周一") { setQuick(day: nextMonday) }
            }
            DatePicker("截止时间", selection: dueBinding, displayedComponents: [.date, .hourAndMinute])
            if dueDate != nil {
                Button("清除截止", role: .destructive) {
                    dueDate = nil
                    dueManual = true
                    showDuePicker = false
                }
            }
        }
        .glassButton()
        .padding(14)
        .frame(width: 300)
    }

    private var dueBinding: Binding<Date> {
        Binding(get: { dueDate ?? Date() }, set: { dueDate = $0; dueManual = true })
    }

    private var nextMonday: Date {
        let todayW = cal.component(.weekday, from: Date())
        var delta = (2 - todayW + 7) % 7
        if delta == 0 { delta = 7 }
        return cal.date(byAdding: .day, value: delta, to: Date())!
    }

    /// 快捷选日：保留已解析/已选的时间，没有则默认 9:00
    private func setQuick(day: Date) {
        var c = cal.dateComponents([.year, .month, .day], from: day)
        if let existing = dueDate {
            let tc = cal.dateComponents([.hour, .minute], from: existing)
            c.hour = tc.hour
            c.minute = tc.minute
        } else {
            c.hour = 9
            c.minute = 0
        }
        dueDate = cal.date(from: c)
        dueManual = true
        showDuePicker = false
    }

    private func dueLabel(_ d: Date) -> String {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        if cal.isDateInToday(d) { return "今天 \(time.string(from: d))" }
        if cal.isDateInTomorrow(d) { return "明天 \(time.string(from: d))" }
        let day = DateFormatter()
        day.locale = Locale(identifier: "zh_CN")
        day.dateFormat = "M月d日"
        return "\(day.string(from: d)) \(time.string(from: d))"
    }

    private func addTask() {
        // 提交时把日期时间词从标题里抠掉（「明天下午三点开会」→「开会」）
        let parsed = DatePhraseParser.parse(newTitle)
        store.addTask(title: parsed.title, dueDate: dueDate)
        newTitle = ""
        dueDate = nil
        dueManual = false
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist").font(.largeTitle).foregroundStyle(.secondary)
            Text("还没有任务").font(.jzSection)
            Text("写下第一件事，回车就好")
                .font(.jzBody).foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
    }

    // MARK: 任务行

    private func taskRow(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { store.toggleTask(task) }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(checkColor(task))
                        .font(.system(size: 17))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .fontWeight(.medium)
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            Label(dueText(due), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(isOverdue(task) ? .red : .secondary)
                        }
                        if !task.subtasks.isEmpty {
                            Text("子任务 \(task.subtasks.filter { $0.isDone }.count)/\(task.subtasks.count)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let folder = task.folderName {
                            CapsuleTag(text: folder)
                        }
                    }
                }
                Spacer()
                Button { store.toggleImportant(task) } label: {
                    Image(systemName: task.isImportant ? "flag.fill" : "flag")
                        .foregroundStyle(task.isImportant ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help("标为重要")

                if !task.subtasks.isEmpty || !task.isDone {
                    Button {
                        if expanded.contains(task.id) { expanded.remove(task.id) }
                        else { expanded.insert(task.id) }
                    } label: {
                        Image(systemName: expanded.contains(task.id) ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("子任务")
                }
            }

            if expanded.contains(task.id) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(task.subtasks) { sub in
                        HStack(spacing: 8) {
                            Button { store.toggleSubtask(task: task, subtask: sub) } label: {
                                Image(systemName: sub.isDone ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(sub.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            Text(sub.title)
                                .font(.callout)
                                .strikethrough(sub.isDone)
                                .foregroundStyle(sub.isDone ? .secondary : .primary)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
                        TextField("添加子任务，回车保存", text: Binding(
                            get: { subtaskDrafts[task.id] ?? "" },
                            set: { subtaskDrafts[task.id] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .onSubmit {
                            store.addSubtask(task: task, title: subtaskDrafts[task.id] ?? "")
                            subtaskDrafts[task.id] = ""
                        }
                    }
                }
                .padding(.leading, 29)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .hoverHighlight()
        .contextMenu {
            Button("删除任务", role: .destructive) { store.deleteTask(task) }
        }
    }

    /// 勾选圈按优先级上色：已完成绿 / 重要红 / 已过期橙 / 普通灰
    private func checkColor(_ task: TaskItem) -> Color {
        if task.isDone { return JZ.success }
        if task.isImportant { return JZ.danger }
        if isOverdue(task) { return JZ.warm }
        return .secondary
    }

    private func isOverdue(_ task: TaskItem) -> Bool {
        guard let due = task.dueDate, !task.isDone else { return false }
        return due < Date()
    }

    private func dueText(_ due: Date) -> String {
        if cal.isDateInToday(due) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return "今天 \(f.string(from: due))"
        }
        if cal.isDateInTomorrow(due) { return "明天" }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 HH:mm"
        return f.string(from: due)
    }
}
