import SwiftUI

/// 看板：待办 / 进行中 / 已完成三列，任务卡可在列之间拖动
struct TaskBoardView: View {
    /// 参与看板的任务（任务页传全部，今天页传今天相关的）
    let tasks: [TaskItem]
    var compact: Bool = false
    @EnvironmentObject private var store: DataStore

    private struct Column: Identifiable {
        let id: String
        let title: String
        let color: Color
    }

    private let columns = [
        Column(id: "todo", title: "待办", color: .secondary),
        Column(id: "doing", title: "进行中", color: JZ.accent),
        Column(id: "done", title: "已完成", color: JZ.success)
    ]

    private func items(_ column: String) -> [TaskItem] {
        switch column {
        case "doing": return tasks.filter { $0.isDoing }
        case "done":
            return tasks.filter { $0.isDone }
                .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
                .prefix(compact ? 6 : 30).map { $0 }
        default:
            return tasks.filter { !$0.isDone && !$0.isDoing }
                .sorted { a, b in
                    if a.isImportant != b.isImportant { return a.isImportant }
                    return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
                }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(columns) { col in
                BoardColumn(id: col.id, title: col.title, color: col.color, items: items(col.id), compact: compact)
            }
        }
    }
}

private struct BoardColumn: View {
    let id: String
    let title: String
    let color: Color
    let items: [TaskItem]
    let compact: Bool
    @EnvironmentObject private var store: DataStore
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title).font(.jzSection)
                Text("\(items.count)").font(.jzCaption).foregroundStyle(.secondary)
                Spacer()
            }
            if items.isEmpty {
                Text(id == "doing" ? "把正在做的任务拖到这里" : "空")
                    .font(.jzCaption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            ForEach(items) { t in
                BoardCard(task: t)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: compact ? 160 : 320, alignment: .topLeading)
        .background(targeted ? JZ.accent.opacity(0.10) : JZ.innerFill,
                    in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
        .dropDestination(for: String.self) { raws, _ in
            guard let raw = raws.first, let uuid = UUID(uuidString: raw) else { return false }
            withAnimation(.easeInOut(duration: 0.15)) { store.setBoardColumn(taskID: uuid, column: id) }
            return true
        } isTargeted: { targeted = $0 }
    }
}

private struct BoardCard: View {
    let task: TaskItem
    @EnvironmentObject private var store: DataStore
    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 7) {
                Button { store.toggleTask(task) } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isDone ? JZ.success : (task.isImportant ? JZ.warm : Color.secondary))
                }
                .buttonStyle(.plain)
                Text(task.title)
                    .font(.callout.weight(.medium))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(3)
                Spacer(minLength: 0)
                if task.isImportant {
                    Image(systemName: "flag.fill").font(.caption).foregroundStyle(JZ.warm)
                }
            }
            HStack(spacing: 6) {
                if let due = task.dueDate {
                    Label(dueText(due), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(!task.isDone && due < Date() ? JZ.danger : .secondary)
                }
                if !task.subtasks.isEmpty {
                    Text("\(task.subtasks.filter { $0.isDone }.count)/\(task.subtasks.count)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let folder = task.folderName { CapsuleTag(text: folder) }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous)
                .strokeBorder(JZ.separator.opacity(0.4), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .draggable(task.id.uuidString) {
            Text(task.title).font(.callout).padding(6)
                .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: 6))
        }
        .contextMenu {
            Button("移到待办") { store.setBoardColumn(taskID: task.id, column: "todo") }
            Button("移到进行中") { store.setBoardColumn(taskID: task.id, column: "doing") }
            Button("移到已完成") { store.setBoardColumn(taskID: task.id, column: "done") }
            Divider()
            Button(task.isImportant ? "取消重要" : "标为重要") { store.toggleImportant(task) }
            Button("删除任务", role: .destructive) { store.deleteTask(task) }
        }
    }

    private func dueText(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(d) { f.dateFormat = "今天 HH:mm" }
        else if cal.isDateInTomorrow(d) { f.dateFormat = "明天 HH:mm" }
        else { f.dateFormat = "M月d日" }
        return f.string(from: d)
    }
}
