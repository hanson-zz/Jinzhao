import SwiftUI

// MARK: - 优先级：颜色、旗标按钮、右键子菜单（任务页 / 看板 / 待排期 共用）

extension TaskPriority {
    var color: Color {
        switch self {
        case .none: return Color.secondary.opacity(0.5)
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
    var symbol: String { self == .none ? "flag" : "flag.fill" }
}

/// 点一下弹出 高 / 中 / 低 / 无 的旗标
struct PriorityFlagMenu: View {
    let task: TaskItem
    var size: CGFloat = 13
    @EnvironmentObject private var store: DataStore

    var body: some View {
        Menu {
            PriorityMenuItems(task: task)
        } label: {
            Image(systemName: task.priorityLevel.symbol)
                .font(.system(size: size))
                .foregroundStyle(task.priorityLevel.color)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("优先级：\(task.priorityLevel.short)")
    }
}

/// 放进 contextMenu / Menu 里的四个选项
struct PriorityMenuItems: View {
    let task: TaskItem
    @EnvironmentObject private var store: DataStore

    var body: some View {
        ForEach(TaskPriority.allCases.reversed()) { p in
            Button {
                store.setPriority(task.id, p)
            } label: {
                if task.priorityLevel == p {
                    Label(p.label, systemImage: "checkmark")
                } else {
                    Text(p.label)
                }
            }
        }
    }
}

/// 任务上的「日程：xxx」小胶囊
struct LinkedEventTag: View {
    let title: String
    var body: some View {
        Label(title, systemImage: "calendar")
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(JZ.controlFill, in: Capsule())
            .help("关联日程：\(title)")
    }
}

// MARK: - 日程详情浮层：关联任务

/// 点日程块弹出：时间、入会、关联任务（勾选 / 新建 / 关联已有 / 取消关联）
struct EventTasksPopover: View {
    let event: CalendarEventItem
    @EnvironmentObject private var store: DataStore
    @Environment(\.openURL) private var openURL
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var linked: [TaskItem] { store.tasks(linkedTo: event.id) }
    private var candidates: [TaskItem] {
        store.tasks.filter { !$0.isDone && $0.linkedEventID != event.id }
            .sorted(by: DataStore.byPriorityThenDue)
            .prefix(30).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.headline).lineLimit(2)
                Text(timeText).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                if let loc = event.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if let url = event.meetingURL {
                Button {
                    openURL(url)
                } label: {
                    Label("加入\(event.meetingProvider ?? "")会议", systemImage: "video")
                }
                .controlSize(.small)
            }
            Divider()
            HStack {
                Text("关联任务").font(.subheadline.weight(.semibold))
                if !linked.isEmpty {
                    Text("\(linked.filter { $0.isDone }.count)/\(linked.count)")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                Spacer()
                Menu("关联已有") {
                    if candidates.isEmpty { Text("没有可关联的待办") }
                    ForEach(candidates) { t in
                        Button(t.title) { store.linkTask(t.id, to: event) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .font(.caption)
            }
            if linked.isEmpty {
                Text("开会前要准备的、会后要跟进的，都可以挂在这里。")
                    .font(.caption).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(linked) { t in
                HStack(spacing: 8) {
                    Button { store.toggleTask(t) } label: {
                        Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(t.isDone ? JZ.success : t.priorityLevel == .none ? Color.secondary : t.priorityLevel.color)
                    }
                    .buttonStyle(.plain)
                    Text(t.title).font(.callout).lineLimit(1)
                        .strikethrough(t.isDone)
                        .foregroundStyle(t.isDone ? .secondary : .primary)
                    Spacer(minLength: 0)
                    Button { store.unlinkTask(t.id) } label: {
                        Image(systemName: "xmark").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("取消关联（任务保留）")
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
                TextField("新建任务，回车保存", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($focused)
                    .onSubmit {
                        store.addTask(title: draft, linkedTo: event)
                        draft = ""
                    }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var timeText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        if event.isAllDay { f.dateFormat = "M月d日 EEEE · 全天"; return f.string(from: event.start) }
        f.dateFormat = "M月d日 EEEE HH:mm"
        let g = DateFormatter(); g.dateFormat = "HH:mm"
        return "\(f.string(from: event.start)) – \(g.string(from: event.end))"
    }
}
