import SwiftUI

/// 轻量启动器：无需打开完整主窗口即可搜索任务、快速记录和创建待办。
/// ⌘K 为应用内快捷键；系统级快捷键需单独申请辅助功能/事件监听权限。
struct QuickLauncherView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var query = ""
    @FocusState private var focused: Bool

    private var matchedTasks: [TaskItem] {
        guard !query.isEmpty else { return store.tasks.filter { !$0.isDone }.prefix(5).map { $0 } }
        return store.tasks.filter { $0.title.localizedCaseInsensitiveContains(query) }.prefix(6).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("搜索任务，或直接输入新任务…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit { addTask() }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Label("快捷操作", systemImage: "bolt")
                    .font(.jzCaption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("回车新建任务").font(.jzCaption).foregroundStyle(.tertiary)
            }
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: addTask) {
                    Label("新建任务：\(query)", systemImage: "plus.circle")
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain).padding(10)
                Button {
                    store.addInbox(text: query)
                    dismissWindow(id: "quick-launcher")
                } label: {
                    Label("记录到收件箱", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain).padding(10)
            }
            Divider()
            if matchedTasks.isEmpty {
                Text("没有匹配的任务").font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
            } else {
                ForEach(matchedTasks) { task in
                    Button {
                        store.toggleTask(task)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            Text(task.title).lineLimit(1)
                            Spacer()
                            if task.isImportant { Image(systemName: "flag.fill").foregroundStyle(.orange) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverHighlight()
                }
            }
            HStack {
                Text("今朝 · 快捷入口").font(.jzCaption).foregroundStyle(.tertiary)
                Spacer()
                Text("本地数据 · 离线可用").font(.jzCaption).foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(width: 520)
        .background(JZ.windowBg)
        .onAppear { focused = true }
    }

    private func addTask() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addTask(title: text)
        query = ""
        dismissWindow(id: "quick-launcher")
    }
}

/// 独立今日浮窗：复用同一份 DataStore / CalendarService，不存重复数据。
struct TodayFloatingView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @State private var draft = ""

    private var items: [TaskItem] {
        store.tasks.filter { !$0.isDone }.prefix(8).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今天").font(.system(size: 22, weight: .semibold))
                    Text(Date(), format: .dateTime.month(.wide).day().weekday(.wide))
                        .font(.jzCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sun.horizon")
                    .font(.title2).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Text("待办事项").font(.jzSection)
                Spacer()
                Text("\(items.count) 项").font(.jzCaption).foregroundStyle(.secondary)
            }
            if items.isEmpty {
                Text("今日暂无待办，享受井井有条的一天。")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
            } else {
                ForEach(items) { task in
                    Button { store.toggleTask(task) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "circle").foregroundStyle(.secondary)
                            Text(task.title).lineLimit(2)
                            Spacer()
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain).padding(.vertical, 4)
                }
            }
            Divider()
            HStack {
                TextField("快速添加任务…", text: $draft)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        store.addTask(title: draft)
                        draft = ""
                    }
                Button {
                    store.addTask(title: draft)
                    draft = ""
                } label: { Image(systemName: "plus.circle.fill") }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: 10))
            if !calendar.events.filter({ Calendar.current.isDateInToday($0.start) }).isEmpty {
                Text("今日日程").font(.jzSection)
                ForEach(calendar.events.filter { Calendar.current.isDateInToday($0.start) }.prefix(4)) { event in
                    HStack {
                        Text(event.start, style: .time).foregroundStyle(.secondary)
                        Text(event.title).lineLimit(1)
                    }.font(.callout)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 320, minHeight: 360, alignment: .topLeading)
        .background(JZ.windowBg)
    }
}
