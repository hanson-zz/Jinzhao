import SwiftUI

/// 任务页：添加（可带截止日期）/ 打勾 / 标重要 / 子任务 / 删除，全部即时落盘
struct TasksView: View {
    @EnvironmentObject private var store: DataStore
    @State private var newTitle = ""
    @State private var newDue: Date = Date()
    @State private var hasDue = false
    @State private var expanded: Set<UUID> = []
    @State private var subtaskDrafts: [UUID: String] = [:]

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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    addBar
                    if store.tasks.isEmpty {
                        emptyState
                    }
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
                .onSubmit(addTask)
            Toggle("截止", isOn: $hasDue)
                .toggleStyle(.checkbox)
                .font(.callout)
            if hasDue {
                DatePicker("", selection: $newDue, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            Button("添加", action: addTask)
                .buttonStyle(.borderedProminent)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
    }

    private func addTask() {
        store.addTask(title: newTitle, dueDate: hasDue ? newDue : nil)
        newTitle = ""
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist").font(.largeTitle).foregroundStyle(.secondary)
            Text("还没有任务").font(.headline)
            Text("在上方输入框写下第一件事，回车就存好，关掉 App 也不会丢。")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
