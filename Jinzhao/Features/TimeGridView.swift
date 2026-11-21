import SwiftUI

/// 时间网格（周 / 3 天 / 单日共用）：苹果日历日程 + 已排期的今朝任务
/// - 把任务拖进某天某个时间：排成时间块，开始时间吸附到 15 分钟
/// - 时间块也能拖到别的时间 / 别的天；右键改时长、完成、移出日程
struct TimeGridView: View {
    let days: [Date]
    var hourHeight: CGFloat = 44
    var showsHeader: Bool = true

    @Environment(\.holidayService) private var holidays
    private var cal: Calendar { Calendar(identifier: .gregorian) }
    static let labelWidth: CGFloat = 46

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                headerRow
                    .padding(.bottom, 6)
            }
            AllDayRow(days: days)
            Divider()
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        hourLabels
                        ForEach(days, id: \.self) { day in
                            DayColumn(day: day, hourHeight: hourHeight)
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.top, 6)
                }
                .onAppear {
                    let hour = max(0, min(20, cal.component(.hour, from: Date()) - 2))
                    proxy.scrollTo(min(hour, 8), anchor: .top)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: TimeGridView.labelWidth, height: 1)
            ForEach(days, id: \.self) { day in
                dayHeader(day).frame(maxWidth: .infinity)
            }
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        let isToday = cal.isDateInToday(day)
        let badge = holidays.badge(on: day)
        let lunar = SolarTermTable.term(on: day) ?? LunarCalendar.info(for: day).dayText
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(TimeGridView.weekdayText(day)).font(.jzCaption).foregroundStyle(.secondary)
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 15, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.white : (holidays.isOffDay(on: day) ? JZ.success : Color.primary))
                    .frame(minWidth: 24, minHeight: 24)
                    .background(isToday ? JZ.accent : Color.clear, in: Circle())
                if let t = badge.text {
                    Text(t).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(TimeGridView.isWork(badge) ? JZ.warm : JZ.success, in: Capsule())
                }
            }
            Text(lunar).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var hourLabels: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { h in
                Text(h == 0 ? "" : String(format: "%02d:00", h))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: TimeGridView.labelWidth, height: hourHeight, alignment: .topTrailing)
                    .offset(y: -6)
                    .padding(.trailing, 4)
                    .id(h)
            }
        }
        .frame(width: TimeGridView.labelWidth)
    }

    static func weekdayText(_ day: Date) -> String {
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[Calendar(identifier: .gregorian).component(.weekday, from: day) - 1]
    }

    static func isWork(_ badge: DayBadge) -> Bool {
        if case .work = badge { return true }
        return false
    }

    static func color(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }

    static func timeText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

// MARK: - 全天行：全天日程 + 当天到期但还没排时间的任务（可直接拖进下面的时间格）

private struct AllDayRow: View {
    let days: [Date]
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("全天")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(width: TimeGridView.labelWidth, alignment: .trailing)
                .padding(.trailing, 4)
                .padding(.top, 4)
            ForEach(days, id: \.self) { day in
                cell(day)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(minHeight: 26)
        .padding(.bottom, 4)
    }

    private func cell(_ day: Date) -> some View {
        let allDay = calendar.events(on: day).filter { $0.isAllDay }
        let due = store.tasks.filter { t in
            !t.isDone && t.scheduledStart == nil && (t.dueDate.map { cal.isDate($0, inSameDayAs: day) } ?? false)
        }
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(allDay) { e in
                Text(e.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TimeGridView.color(e.colorName).opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
            }
            ForEach(due) { t in
                TaskChip(task: t)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// 可拖动的任务小条（待排期列表、全天行共用）
struct TaskChip: View {
    let task: TaskItem
    @EnvironmentObject private var store: DataStore

    var body: some View {
        HStack(spacing: 5) {
            Button { store.toggleTask(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundStyle(task.isImportant ? JZ.warm : Color.secondary)
            }
            .buttonStyle(.plain)
            Text(task.title).font(.system(size: 11)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5).padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .draggable(task.id.uuidString) {
            Text(task.title).font(.callout).padding(6)
                .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: 6))
        }
        .help("拖到下面的时间格里，排成时间块")
    }
}

// MARK: - 单日列

private struct GridEntry: Identifiable {
    enum Kind { case event(CalendarEventItem), task(TaskItem) }
    let id: String
    let start: Date
    let end: Date
    let kind: Kind
    var column = 0
    var columns = 1
}

private struct DayColumn: View {
    let day: Date
    let hourHeight: CGFloat
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @State private var targeted = false
    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var dayStart: Date { cal.startOfDay(for: day) }
    private var dayEnd: Date { cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart }

    var body: some View {
        ZStack(alignment: .topLeading) {
            gridLines
            GeometryReader { geo in
                let entries = layout()
                ForEach(entries) { entry in
                    let colWidth = geo.size.width / CGFloat(max(entry.columns, 1))
                    EntryBlock(entry: entry, hourHeight: hourHeight)
                        .frame(width: max(colWidth - 3, 10), height: max(height(entry), 18), alignment: .topLeading)
                        .offset(x: colWidth * CGFloat(entry.column) + 1, y: y(entry.start))
                }
                if cal.isDateInToday(day) {
                    nowLine(width: geo.size.width)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hourHeight * 24)
        .background(targeted ? JZ.accent.opacity(0.07) : Color.clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(JZ.separator.opacity(0.5)).frame(width: 0.5)
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, location in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            let minutes = max(0, min(23.75 * 60, Double(location.y / hourHeight) * 60))
            store.schedule(taskID: id, at: dayStart.addingTimeInterval(minutes * 60))
            return true
        } isTargeted: { targeted = $0 }
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle().fill(JZ.separator.opacity(0.35)).frame(height: 0.5)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func nowLine(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Circle().fill(JZ.danger).frame(width: 7, height: 7)
            Rectangle().fill(JZ.danger).frame(height: 1.2)
        }
        .frame(width: width)
        .offset(x: -3, y: y(Date()) - 3.5)
        .allowsHitTesting(false)
    }

    private func y(_ date: Date) -> CGFloat {
        let minutes = max(0, date.timeIntervalSince(dayStart) / 60)
        return CGFloat(minutes / 60) * hourHeight
    }

    private func height(_ e: GridEntry) -> CGFloat {
        CGFloat(e.end.timeIntervalSince(e.start) / 3600) * hourHeight - 1
    }

    /// 重叠的块并排显示：贪心分列
    private func layout() -> [GridEntry] {
        var items: [GridEntry] = []
        for e in calendar.events where !e.isAllDay && e.end > dayStart && e.start < dayEnd {
            items.append(GridEntry(id: "e-" + e.id, start: max(e.start, dayStart), end: min(max(e.end, e.start.addingTimeInterval(900)), dayEnd), kind: .event(e)))
        }
        for t in store.tasks {
            guard let s = t.scheduledStart, let end = t.scheduledEnd, end > dayStart, s < dayEnd else { continue }
            items.append(GridEntry(id: "t-" + t.id.uuidString, start: max(s, dayStart), end: min(end, dayEnd), kind: .task(t)))
        }
        items.sort { $0.start < $1.start }

        var result: [GridEntry] = []
        var cluster: [GridEntry] = []
        var clusterEnd = Date.distantPast
        func flush() {
            var colEnds: [Date] = []
            var placed: [GridEntry] = []
            for var item in cluster {
                if let c = colEnds.firstIndex(where: { $0 <= item.start }) {
                    item.column = c; colEnds[c] = item.end
                } else {
                    item.column = colEnds.count; colEnds.append(item.end)
                }
                placed.append(item)
            }
            for var p in placed { p.columns = colEnds.count; result.append(p) }
            cluster = []
        }
        for item in items {
            if !cluster.isEmpty && item.start >= clusterEnd { flush() }
            if cluster.isEmpty { clusterEnd = item.end } else { clusterEnd = max(clusterEnd, item.end) }
            cluster.append(item)
        }
        if !cluster.isEmpty { flush() }
        return result
    }
}

private struct EntryBlock: View {
    let entry: GridEntry
    let hourHeight: CGFloat
    @EnvironmentObject private var store: DataStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch entry.kind {
        case .event(let e): eventBlock(e)
        case .task(let t): taskBlock(t)
        }
    }

    private func eventBlock(_ e: CalendarEventItem) -> some View {
        let c = TimeGridView.color(e.colorName)
        return HStack(alignment: .top, spacing: 4) {
            Rectangle().fill(c).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title).font(.system(size: 11, weight: .semibold)).lineLimit(2)
                Text(TimeGridView.timeText(e.start)).font(.system(size: 10)).foregroundStyle(.secondary)
                if let p = e.meetingProvider, e.meetingURL != nil {
                    Text(p).font(.system(size: 10)).foregroundStyle(c)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .background(c.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            if let url = e.meetingURL {
                Button("加入\(e.meetingProvider ?? "")会议") { openURL(url) }
            }
        }
        .help(e.title)
    }

    private func taskBlock(_ t: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Button { store.toggleTask(t) } label: {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundStyle(t.isDone ? JZ.success : JZ.accent)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.title).font(.system(size: 11, weight: .semibold)).lineLimit(2)
                    .strikethrough(t.isDone)
                if let s = t.scheduledStart, let e = t.scheduledEnd {
                    Text("\(TimeGridView.timeText(s))–\(TimeGridView.timeText(e))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5).padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(JZ.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .background(JZ.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .draggable(t.id.uuidString) {
            Text(t.title).font(.callout).padding(6)
                .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: 6))
        }
        .contextMenu {
            Menu("时长") {
                ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { m in
                    Button(m < 60 ? "\(m) 分钟" : (m % 60 == 0 ? "\(m / 60) 小时" : "\(Double(m) / 60) 小时")) {
                        store.updateTask(t.id) { $0.scheduledMinutes = m }
                    }
                }
            }
            Button(t.isDone ? "标为未完成" : "完成") { store.toggleTask(t) }
            Divider()
            Button("移出日程") { store.unschedule(taskID: t.id) }
        }
        .help("今朝任务 · 拖动改时间，右键改时长")
    }
}

/// 待排期任务栏：还没排时间的待办，拖进左边时间格即可
struct UnscheduledTray: View {
    @EnvironmentObject private var store: DataStore

    private var items: [TaskItem] {
        store.tasks.filter { !$0.isDone && $0.scheduledStart == nil }
            .sorted { a, b in
                if a.isImportant != b.isImportant { return a.isImportant }
                return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("待排期").font(.jzSection)
                Text("\(items.count)").font(.jzCaption).foregroundStyle(.secondary)
            }
            Text("把任务拖到左边的时间格里，排成时间块。")
                .font(.jzCaption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(spacing: 4) {
                    if items.isEmpty {
                        Text("没有待排期的任务").font(.callout).foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    ForEach(items) { t in TaskChip(task: t) }
                }
            }
        }
        .padding(10)
        .frame(width: 180)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusS))
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            store.unschedule(taskID: id)
            return true
        }
    }
}
