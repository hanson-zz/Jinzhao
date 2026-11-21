import SwiftUI
import AppKit

/// 快速启动器（⌘K / ⌥Space）：一句话新建 + 全局搜索
/// - 「明天三点见王总」→ 回车建任务（带截止时间），⌘回车建日程（写入苹果日历）
/// - 「三点到五点」识别为时段；没写结束时间默认 1 小时
/// - 搜索任务、笔记和未来 30 天日程，支持拼音首字母（如「kh」找「开会」）
struct QuickLauncherView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var notice: String?
    @FocusState private var focused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsed: QuickPhrase { QuickPhrase.parse(trimmed) }

    private var matchedTasks: [TaskItem] {
        guard !trimmed.isEmpty else { return store.tasks.filter { !$0.isDone }.prefix(5).map { $0 } }
        return store.tasks.filter { PinyinMatcher.matches($0.title, trimmed) }.prefix(6).map { $0 }
    }

    private var matchedNotes: [NoteItem] {
        guard !trimmed.isEmpty else { return [] }
        return store.notes.filter {
            PinyinMatcher.matches($0.title, trimmed) || $0.plainText.localizedCaseInsensitiveContains(trimmed)
        }.prefix(4).map { $0 }
    }

    private var matchedEvents: [CalendarEventItem] {
        guard !trimmed.isEmpty else { return [] }
        let now = Date()
        let limit = now.addingTimeInterval(30 * 86400)
        return calendar.events.filter { $0.end >= now && $0.start <= limit && PinyinMatcher.matches($0.title, trimmed) }
            .prefix(4).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("搜索，或一句话新建：明天下午三点到五点 评审", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit { createTask() }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: 14))

            if let notice {
                Text(notice).font(.jzCaption).foregroundStyle(JZ.danger)
            }

            if !trimmed.isEmpty {
                VStack(spacing: 2) {
                    actionRow(symbol: "checklist", title: "新建任务：\(parsed.title)",
                              detail: [parsed.start.map { "截止 " + Self.when($0) }, parsed.priority == .none ? nil : parsed.priority.label].compactMap { $0 }.joined(separator: " · ").nilIfEmpty, hint: "↩", action: createTask)
                    actionRow(symbol: "calendar.badge.plus", title: "新建日程：\(parsed.title)",
                              detail: eventDetail, hint: "⌘↩", action: createEvent)
                        .keyboardShortcut(.return, modifiers: .command)
                    actionRow(symbol: "doc.text", title: "新建笔记：\(trimmed)", detail: nil, hint: "", action: createNote)
                    actionRow(symbol: "tray.and.arrow.down", title: "记录到收件箱", detail: nil, hint: "", action: capture)
                }
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !matchedEvents.isEmpty {
                        sectionLabel("日程")
                        ForEach(matchedEvents) { e in
                            HStack(spacing: 10) {
                                Image(systemName: "calendar").foregroundStyle(.secondary)
                                Text(e.title).lineLimit(1)
                                Spacer()
                                Text(Self.when(e.start)).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                        }
                    }
                    if !matchedNotes.isEmpty {
                        sectionLabel("笔记")
                        ForEach(matchedNotes) { n in
                            Button { open(note: n.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.text").foregroundStyle(.secondary)
                                    Text(n.title.isEmpty ? "无标题" : n.title).lineLimit(1)
                                    Spacer()
                                    Text(n.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .hoverHighlight()
                        }
                    }
                    sectionLabel(trimmed.isEmpty ? "待办" : "任务")
                    if matchedTasks.isEmpty {
                        Text("没有匹配的任务").font(.callout).foregroundStyle(.secondary)
                            .padding(10)
                    }
                    ForEach(matchedTasks) { task in
                        Button {
                            store.toggleTask(task)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                Text(task.title).lineLimit(1)
                                Spacer()
                                if task.priorityLevel != .none { Image(systemName: "flag.fill").foregroundStyle(task.priorityLevel.color) }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hoverHighlight()
                    }
                }
            }
            .frame(maxHeight: 300)

            HStack {
                Text("↩ 建任务 · ⌘↩ 建日程 · 支持拼音首字母").font(.jzCaption).foregroundStyle(.tertiary)
                Spacer()
                Text("本地数据 · 离线可用").font(.jzCaption).foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(JZ.windowBg)
        .onAppear {
            focused = true
            if let seed = UserDefaults.standard.string(forKey: "jinzhao.launcherSeed"), !seed.isEmpty {
                query = seed
                UserDefaults.standard.removeObject(forKey: "jinzhao.launcherSeed")
            }
        }
        .onExitCommand { dismissWindow(id: "quick-launcher") }
    }

    private var eventDetail: String {
        guard calendar.authState == .authorized else { return "需要先连接苹果日历" }
        let (s, e) = parsed.eventRange()
        return "\(Self.when(s)) – \(Self.timeOnly(e))"
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.jzCaption.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.top, 6)
    }

    private func actionRow(symbol: String, title: String, detail: String?, hint: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18).foregroundStyle(JZ.accent)
                Text(title).lineLimit(1)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
                Text(hint).font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }

    private func finish() {
        query = ""
        notice = nil
        dismissWindow(id: "quick-launcher")
    }

    private func createTask() {
        guard !trimmed.isEmpty else { return }
        store.addTask(title: parsed.title, dueDate: parsed.start, priority: parsed.priority)
        finish()
    }

    private func createEvent() {
        guard !trimmed.isEmpty else { return }
        guard calendar.authState == .authorized else {
            notice = "还没连接苹果日历：请先在「日历」页连接。"
            return
        }
        let (s, e) = parsed.eventRange()
        var location: String? = nil
        if trimmed.contains("腾讯会议") { location = "腾讯会议" }
        else if trimmed.contains("飞书") { location = "飞书会议" }
        if calendar.createEvent(title: parsed.title, start: s, end: e, location: location) {
            finish()
        } else {
            notice = "保存失败：请确认系统里有可写的默认日历。"
        }
    }

    private func createNote() {
        guard !trimmed.isEmpty else { return }
        let id = store.addNote(title: String(trimmed.prefix(30)))
        finish()
        open(note: id)
    }

    private func capture() {
        store.addInbox(text: trimmed)
        finish()
    }

    private func open(note id: UUID) {
        NSApp.activate(ignoringOtherApps: true)
        UserDefaults.standard.set(id.uuidString, forKey: "jinzhao.selectedNoteID")
        NotificationCenter.default.post(name: .jinzhaoOpenNote, object: id)
        dismissWindow(id: "quick-launcher")
    }

    static func when(_ d: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(d) { f.dateFormat = "今天 HH:mm" }
        else if cal.isDateInTomorrow(d) { f.dateFormat = "明天 HH:mm" }
        else { f.dateFormat = "M月d日 EEE HH:mm" }
        return f.string(from: d)
    }

    static func timeOnly(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

/// 快速启动器的一句话解析：在 DatePhraseParser 之上补「到X点」时段、「半小时后 / X小时后」、标签
struct QuickPhrase {
    var title: String
    var start: Date?
    var end: Date?
    var priority: TaskPriority = .none

    func eventRange(now: Date = Date()) -> (Date, Date) {
        let s = start ?? DataStore.snap(now.addingTimeInterval(3600), minutes: 30)
        let e = end.flatMap { $0 > s ? $0 : nil } ?? s.addingTimeInterval(3600)
        return (s, e)
    }

    static func parse(_ raw: String, now: Date = Date()) -> QuickPhrase {
        var text = raw
        let cal = Calendar(identifier: .gregorian)
        var relative: Date? = nil
        // 半小时后 / 3小时后 / 20分钟后
        let relPattern = #"(半|\d{1,2}|[一二两三四五六七八九十])\s*(个)?\s*(小时|分钟)后"#
        if let re = try? NSRegularExpression(pattern: relPattern),
           let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r = Range(m.range, in: text), let nr = Range(m.range(at: 1), in: text),
           let ur = Range(m.range(at: 3), in: text) {
            let n = String(text[nr])
            let unit = String(text[ur])
            let value: Double = n == "半" ? 0.5 : Double(Int(n) ?? chinese(n) ?? 1)
            let minutes = unit == "小时" ? value * 60 : value
            relative = now.addingTimeInterval(minutes * 60)
            text.removeSubrange(r)
        }
        // 「到五点 / 至17:30」结束时间
        var endHour: Int? = nil
        var endMinute = 0
        let endPattern = #"(到|至|-|~)\s*(十[一二]?|[一二三四五六七八九两]|\d{1,2})(?:\s*点\s*(半)?|:(\d{2}))"#
        if let re = try? NSRegularExpression(pattern: endPattern),
           let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r = Range(m.range, in: text), let hr = Range(m.range(at: 2), in: text) {
            let hs = String(text[hr])
            endHour = Int(hs) ?? chinese(hs)
            if Range(m.range(at: 3), in: text) != nil { endMinute = 30 }
            if let mr = Range(m.range(at: 4), in: text) { endMinute = Int(text[mr]) ?? 0 }
            text.removeSubrange(r)
        }
        let base = DatePhraseParser.parse(text, now: now)
        var start = relative ?? base.due
        if relative != nil, let s = start { start = DataStore.snap(s, minutes: 5) }
        var end: Date? = nil
        if let s = start, var h = endHour {
            let sh = cal.component(.hour, from: s)
            if sh >= 12 && h < 12 { h += 12 }
            end = cal.date(bySettingHour: min(h, 23), minute: endMinute, second: 0, of: s)
        }
        var title = base.title
        // 优先级：!!! 高 / !! 中，或直接写「高/中/低优先级」（单个 ! 不算，免得误伤感叹句）
        var priority: TaskPriority = .none
        let prioRules: [(String, TaskPriority)] = [
            (#"\s*[!！]{3,}\s*"#, .high), (#"\s*高优先级\s*"#, .high),
            (#"\s*[!！]{2}\s*"#, .medium), (#"\s*中优先级\s*"#, .medium),
            (#"\s*低优先级\s*"#, .low)
        ]
        for (pattern, p) in prioRules {
            if let re = try? NSRegularExpression(pattern: pattern),
               let m = re.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
               let r = Range(m.range, in: title) {
                priority = p
                title.replaceSubrange(r, with: " ")
                break
            }
        }
        for word in ["腾讯会议", "飞书会议"] { title = title.replacingOccurrences(of: word, with: "") }
        title = title.trimmingCharacters(in: .whitespaces)
        if title.isEmpty { title = raw }
        return QuickPhrase(title: title, start: start, end: end, priority: priority)
    }

    private static func chinese(_ s: String) -> Int? {
        let map: [String: Int] = ["一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
                                  "六": 6, "七": 7, "八": 8, "九": 9, "十": 10, "十一": 11, "十二": 12]
        return map[s]
    }
}

/// 拼音匹配：原文包含 / 全拼包含 / 首字母包含（「kh」→「开会」）
enum PinyinMatcher {
    private static var cache: [String: (full: String, initials: String)] = [:]

    static func matches(_ text: String, _ query: String) -> Bool {
        let q = query.lowercased().replacingOccurrences(of: " ", with: "")
        guard !q.isEmpty else { return true }
        if text.localizedCaseInsensitiveContains(query) { return true }
        guard q.allSatisfy({ $0.isASCII && $0.isLetter }) else { return false }
        let p = pinyin(text)
        return p.initials.contains(q) || p.full.contains(q)
    }

    static func pinyin(_ text: String) -> (full: String, initials: String) {
        if let hit = cache[text] { return hit }
        let m = NSMutableString(string: text) as CFMutableString
        CFStringTransform(m, nil, kCFStringTransformToLatin, false)
        CFStringTransform(m, nil, kCFStringTransformStripDiacritics, false)
        let latin = (m as String).lowercased()
        let words = latin.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let result = (full: words.joined(), initials: String(words.compactMap { $0.first }))
        if cache.count > 2000 { cache.removeAll() }
        cache[text] = result
        return result
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
