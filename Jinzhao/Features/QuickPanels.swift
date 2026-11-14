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
    @AppStorage("jinzhao.floatingStickyExpanded") private var expanded = false
    @AppStorage("jinzhao.floatingStickyAlwaysOnTop") private var alwaysOnTop = false
    @State private var draft = ""

    /// 浮窗只展示当日及无截止日期的待办，避免把远期计划全部堆上桌面。
    private var items: [TaskItem] {
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1,
                                              to: Calendar.current.startOfDay(for: now)) ?? now
        return store.tasks.filter {
            !$0.isDone && ($0.dueDate == nil || $0.dueDate! < tomorrow)
        }.prefix(expanded ? 8 : 3).map { $0 }
    }

    private var dayEvents: [CalendarEventItem] {
        calendar.events.filter { Calendar.current.isDateInToday($0.start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今朝 · 今日便签")
                        .font(.system(size: 16, weight: .semibold))
                    Text(Date(), format: .dateTime.month(.twoDigits).day().weekday(.wide))
                        .font(.jzCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    alwaysOnTop.toggle()
                } label: {
                    Image(systemName: alwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 13))
                        .foregroundStyle(alwaysOnTop ? Color.orange : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(alwaysOnTop ? "取消置顶" : "将便签保持在其他窗口上方")
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expanded.toggle()
                    }
                } label: {
                    Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(expanded ? "收起便签" : "展开便签")
            }

            Rectangle()
                .fill(Color.orange.opacity(0.19))
                .frame(height: 1)

            HStack {
                Text("今天想完成的事")
                    .font(.jzSection)
                Spacer()
                Text("\(items.count) 项")
                    .font(.jzCaption).foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("还没有待办，先记下一件小事吧。")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { task in
                    Button {
                        store.toggleTask(task)
                    } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                                .padding(.top, 1)
                            Text(task.title).lineLimit(expanded ? 2 : 1)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 3)
                }
            }

            if expanded && !dayEvents.isEmpty {
                Rectangle()
                    .fill(Color.orange.opacity(0.19))
                    .frame(height: 1)
                Text("今日日程").font(.jzSection)
                ForEach(dayEvents.prefix(4)) { event in
                    HStack(spacing: 8) {
                        Text(event.isAllDay ? "全天" : event.start.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(event.title).lineLimit(1)
                    }
                    .font(.callout)
                }
            } else if !expanded && !dayEvents.isEmpty {
                Label("\(dayEvents.count) 项日程，展开查看", systemImage: "calendar")
                    .font(.jzCaption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                TextField("随手添加一项任务…", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit(addTask)
                Button(action: addTask) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Color.white.opacity(0.43), in: RoundedRectangle(cornerRadius: 11))

            if expanded {
                Text("可直接勾选任务 · 数据与今朝主窗口同步")
                    .font(.jzCaption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 310, alignment: .topLeading)
        .background(TodayNoteWindowBehavior(alwaysOnTop: alwaysOnTop))
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(Color.orange.opacity(0.075))
                }
        )
    }

    private func addTask() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.addTask(title: draft)
        draft = ""
    }
}
