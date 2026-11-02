import SwiftUI

/// 今天页（照效果图）：日期条 → 问候汇总 → 调休提醒条 → 日程任务混排 + 习惯/笔记/明天
struct TodayView: View {
    let date: Date
    @EnvironmentObject private var store: DataStore
    @Environment(\.holidayService) private var holidays
    @State private var mode: Mode = .list

    enum Mode: String, CaseIterable { case list = "列表", timeline = "时间轴", board = "看板" }

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var headerTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
    }

    var body: some View {
        GlassCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    greetingLine
                    dateStrip
                    workdayAlert
                    HStack(alignment: .top, spacing: 16) {
                        todayList.frame(maxWidth: .infinity)
                        VStack(spacing: 16) {
                            habitsCard
                            tomorrowCard
                        }
                        .frame(width: 288)
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.system(size: 27, weight: .bold))
                let lunar = LunarCalendar.info(for: date)
                let term = SolarTermTable.term(on: date) ?? SolarTermTable.currentTerm(on: date) ?? ""
                Text("农历\(lunar.shortText) · \(term) · \(lunar.ganzhiYear)\(lunar.zodiac)年")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Text(m == .board ? "看板 🔒" : m.rawValue).tag(m) // 看板是 Pro，先做锁定入口（定版决策）
                }
            }
            .pickerStyle(.segmented).frame(width: 210)
            Button { } label: { Text("+ 新建") }
                .buttonStyle(.borderedProminent)
        }
    }

    private var greetingLine: some View {
        let hour = cal.component(.hour, from: date)
        let greet = hour < 12 ? "早上好" : hour < 18 ? "下午好" : "晚上好"
        let openTasks = store.tasks.filter { !$0.isDone }.count
        let important = store.tasks.filter { $0.isImportant && !$0.isDone }.count
        return HStack(spacing: 8) {
            Text("\(greet)，老板。").fontWeight(.medium)
            if isFirstWorkdayAfterHoliday {
                Text("假期结束第一天，今天").foregroundStyle(.secondary)
            }
            if !store.events.isEmpty {
                Label("\(store.events.count) 个日程", systemImage: "circle.fill").font(.callout)
            }
            Label("\(store.habits.count) 个习惯", systemImage: "repeat").font(.callout)
            if important > 0 {
                Label("\(important) 件重要", systemImage: "flag.fill").font(.callout).foregroundStyle(.red)
            }
            Text("· \(openTasks) 项待办").font(.callout).foregroundStyle(.secondary)
        }
    }

    /// 昨天休、今天不休 → 假期后第一个工作日
    private var isFirstWorkdayAfterHoliday: Bool {
        let yesterday = cal.date(byAdding: .day, value: -1, to: date)!
        return holidays.badge(on: yesterday) != .none && holidays.isOffDay(on: yesterday) && !holidays.isOffDay(on: date)
    }

    // MARK: 日期条（9 格：本周日到下周一）

    private var stripDays: [Date] {
        let weekday = cal.component(.weekday, from: date) // 1 = 周日
        let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: date))!
        return (0..<9).map { cal.date(byAdding: .day, value: $0, to: sunday)! }
    }

    private var dateStrip: some View {
        HStack(spacing: 8) {
            ForEach(stripDays, id: \.self) { day in
                let isToday = cal.isDate(day, inSameDayAs: date)
                let badge = holidays.badge(on: day)
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Text(isToday ? "今天" : "周\(weekdayText(day))")
                            .font(.caption2).foregroundStyle(isToday ? .white : .secondary)
                        if let t = badge.text {
                            Text(t).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(isWork(badge) ? Color.gray : Color.red,
                                            in: Capsule())
                        }
                    }
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(dayNumberColor(day, isToday: isToday))
                    Text(SolarTermTable.term(on: day) ?? LunarCalendar.info(for: day).dayText)
                        .font(.caption2).foregroundStyle(isToday ? .white.opacity(0.9) : .secondary)
                    if isToday {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in Circle().fill(.white).frame(width: 3, height: 3) }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isToday ? Color.blue : Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private func isWork(_ badge: DayBadge) -> Bool {
        if case .work = badge { return true }
        return false
    }

    private func dayNumberColor(_ day: Date, isToday: Bool) -> Color {
        if isToday { return .white }
        return holidays.isOffDay(on: day) ? .red : .primary
    }

    private func weekdayText(_ day: Date) -> String {
        ["日", "一", "二", "三", "四", "五", "六"][cal.component(.weekday, from: day) - 1]
    }

    // MARK: 调休提醒条

    @ViewBuilder private var workdayAlert: some View {
        if let next = nextAdjustedWorkday {
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(.orange)
                Text("\(holidayText(next)) 调休上班，已帮你把当天的闹钟和例会提醒加上。")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private var nextAdjustedWorkday: Date? {
        (1...14).compactMap { offset -> Date? in
            let d = cal.date(byAdding: .day, value: offset, to: date)!
            return isWork(holidays.badge(on: d)) ? d : nil
        }.first
    }

    private func holidayText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日（EEE）"
        return f.string(from: d)
    }

    // MARK: 今日混排列表

    /// 今天页显示的任务：未完成且（无截止 / 已到期 / 今天到期） + 今天完成的
    private var displayTasks: [TaskItem] {
        let endOfToday = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date))!
        let open = store.tasks.filter { !$0.isDone && ($0.dueDate == nil || $0.dueDate! < endOfToday) }
        let doneToday = store.tasks.filter { t in
            t.isDone && (t.doneAt.map { cal.isDate($0, inSameDayAs: date) } ?? false)
        }
        return open + doneToday
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今天 日程与任务 · \(store.events.filter { isToday($0.start) }.count + displayTasks.count)")
                .font(.subheadline.weight(.semibold)).padding(.bottom, 6)
            if store.events.filter({ isToday($0.start) }).isEmpty && displayTasks.isEmpty {
                Text("今天还没有安排。去「任务」页加几件今天要做的事，或者先在右栏随手记一笔。")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            ForEach(store.events.filter { isToday($0.start) }) { event in
                eventRow(event)
                Divider().opacity(0.4)
            }
            ForEach(displayTasks) { task in
                taskRow(task)
                Divider().opacity(0.4)
            }
        }
    }

    private func isToday(_ d: Date) -> Bool { cal.isDate(d, inSameDayAs: date) }

    private func eventRow(_ e: CalendarEventItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(e.start, style: .time).font(.callout.weight(.semibold))
                Text(e.end, style: .time).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 44, alignment: .leading)
            Rectangle().fill(color(e.colorName)).frame(width: 3).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title).fontWeight(.medium).lineLimit(2)
                if let loc = e.location {
                    Text("📍 \(loc)").font(.caption).foregroundStyle(.secondary)
                } else if let p = e.meetingProvider {
                    Text("\(p)会议").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if e.meetingProvider != nil {
                Button("加入会议") { }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(.vertical, 7)
    }

    private func taskRow(_ t: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { store.toggleTask(t) } label: {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(t.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.title)
                    .fontWeight(.medium)
                    .strikethrough(t.isDone)
                    .foregroundStyle(t.isDone ? .secondary : .primary)
                HStack(spacing: 8) {
                    if t.isImportant {
                        Label("重要", systemImage: "flag.fill").font(.caption).foregroundStyle(.red)
                    }
                    if !t.subtasks.isEmpty {
                        Text("子任务 \(t.subtasks.filter { $0.isDone }.count)/\(t.subtasks.count)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let due = t.dueDate {
                        Text("截止 \(due, style: .time)").font(.caption).foregroundStyle(.secondary)
                    }
                    if let done = t.doneAt {
                        Text("\(done, style: .time) 完成").font(.caption).foregroundStyle(.secondary)
                    }
                    if let folder = t.folderName {
                        Text(folder).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 7)
    }

    private func color(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        default: return .blue
        }
    }

    // MARK: 右列卡片

    @State private var newHabitName = ""

    private var habitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日习惯").font(.subheadline.weight(.semibold))
                Spacer()
                if !store.habits.isEmpty {
                    Text("连续打卡 \(store.habits.map { $0.streakDays }.max() ?? 0) 天")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if store.habits.isEmpty {
                Text("还没有习惯。加一个从今天开始坚持的小事，比如「喝水」。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                ForEach(store.habits) { habit in
                    VStack(spacing: 6) {
                        ZStack {
                            if habit.isComplete {
                                Circle().fill(.green)
                                Image(systemName: "checkmark").foregroundStyle(.white).fontWeight(.bold)
                            } else if let time = habit.scheduledTime {
                                Circle().stroke(.white.opacity(0.15), lineWidth: 5)
                                Text(time).font(.system(size: 13, weight: .semibold))
                            } else {
                                Circle().trim(from: 0, to: habit.fraction)
                                    .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Circle().stroke(.white.opacity(0.12), lineWidth: 5)
                                    .zIndex(-1)
                                Text("\(Int(habit.todayProgress))/\(Int(habit.targetPerDay))")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .frame(width: 52, height: 52)
                        Text(habit.name).font(.caption)
                        Text(habit.isComplete ? "已完成" : habitDetail(habit))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { store.advanceHabit(habit) }
                    .help("点一下打卡 +1，满了再点清零")
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
                TextField("添加习惯，回车保存", text: $newHabitName)
                    .textFieldStyle(.plain).font(.callout)
                    .onSubmit {
                        store.addHabit(name: newHabitName)
                        newHabitName = ""
                    }
            }
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
    }

    private func habitDetail(_ h: HabitItem) -> String {
        if let _ = h.scheduledTime { return "今晚" }
        return "还差 \(Int(h.targetPerDay - h.todayProgress)) \(h.unit)"
    }

    private var tomorrowCard: some View {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: date)!
        let lunar = LunarCalendar.info(for: tomorrow)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("明天 · \(holidayText(tomorrow))").font(.subheadline.weight(.semibold))
                Spacer()
                Text("农历\(lunar.shortText)").font(.caption).foregroundStyle(.secondary)
            }
            if store.events.filter({ cal.isDate($0.start, inSameDayAs: tomorrow) }).isEmpty
                && store.tasks.filter({ !$0.isDone }).isEmpty {
                Text("明天暂无安排").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(store.events.filter { cal.isDate($0.start, inSameDayAs: tomorrow) }) { e in
                HStack(spacing: 8) {
                    Text(e.start, style: .time).font(.callout.weight(.medium))
                    Text(e.title).font(.callout)
                }
                if let loc = e.location {
                    Text(loc).font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(store.tasks.filter { !$0.isDone }.prefix(1)) { t in
                HStack(spacing: 8) {
                    Image(systemName: "circle").foregroundStyle(.secondary)
                    Text(t.title).font(.callout)
                }
                if let folder = t.folderName {
                    Text(folder).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
    }
}
