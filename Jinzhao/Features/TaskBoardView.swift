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
                .sorted(by: DataStore.byPriorityThenDue)
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
            HStack(spacing: 8) {
                Text(title).font(.system(size: compact ? 15 : 18, weight: .bold))
                Text("\(items.count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(JZ.controlFill, in: Capsule())
                Spacer()
            }
            .padding(.horizontal, 4).padding(.bottom, 4)
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
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: compact ? 160 : 420, alignment: .topLeading)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous))
        .overlay {
            if targeted {
                RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous)
                    .strokeBorder(JZ.accent.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .background(JZ.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous))
            }
        }
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

    private var urgent: Bool {
        guard let due = task.dueDate, !task.isDone else { return false }
        return due < Date().addingTimeInterval(24 * 3600)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button { store.toggleTask(task) } label: {
                    Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                        .font(.system(size: 17))
                        .foregroundStyle(JZ.accent)
                }
                .buttonStyle(.plain)
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(3)
                Spacer(minLength: 0)
                PriorityFlagMenu(task: task, size: 14)
            }
            if let due = task.dueDate {
                Label(dueText(due), systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    .foregroundStyle(task.isDone ? Color.secondary : (urgent ? JZ.danger : JZ.accent))
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background((task.isDone ? Color.secondary : (urgent ? JZ.danger : JZ.accent)).opacity(0.12), in: Capsule())
                    .padding(.leading, 27)
            }
            if !task.subtasks.isEmpty {
                let done = task.subtasks.filter { $0.isDone }.count
                let total = task.subtasks.count
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(JZ.controlFill)
                            Capsule().fill(task.isDone || done == total ? JZ.success : JZ.accent)
                                .frame(width: geo.size.width * CGFloat(done) / CGFloat(max(total, 1)))
                        }
                    }
                    .frame(height: 6)
                    Text("\(done)/\(total)").font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                }
                .padding(.leading, 27)
            }
            if task.folderName != nil || task.linkedEventTitle != nil {
                HStack(spacing: 6) {
                    if let folder = task.folderName { CapsuleTag(text: folder) }
                    if let ev = task.linkedEventTitle { LinkedEventTag(title: ev) }
                }
                .padding(.leading, 27)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(JZ.separator.opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        .contentShape(Rectangle())
        .draggable(task.id.uuidString) {
            Text(task.title).font(.system(size: 14, weight: .semibold)).padding(10)
                .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: 10))
                .rotationEffect(.degrees(-3))
        }
        .contextMenu {
            Button("移到待办") { store.setBoardColumn(taskID: task.id, column: "todo") }
            Button("移到进行中") { store.setBoardColumn(taskID: task.id, column: "doing") }
            Button("移到已完成") { store.setBoardColumn(taskID: task.id, column: "done") }
            Divider()
            Menu("优先级") { PriorityMenuItems(task: task) }
            if task.linkedEventID != nil {
                Button("取消关联日程") { store.unlinkTask(task.id) }
            }
            Button("删除任务", role: .destructive) { store.deleteTask(task) }
        }
    }

    private func dueText(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日（EEEEE）HH:mm"
        return f.string(from: d)
    }
}
