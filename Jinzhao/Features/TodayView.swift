import SwiftUI

/// 今天页（照效果图）：日期条 → 问候汇总 → 调休提醒条 → 日程任务混排 + 习惯/笔记/明天
struct TodayView: View {
    /// 真实的今天（由外壳每天刷新传入）
    let today: Date
    /// 用户在日期条 / 右栏小日历里点选的日子；nil = 看今天
    @Binding var selectedDay: Date?
    /// 当前展示的日子
    private var date: Date { selectedDay ?? today }
    private var viewingToday: Bool { cal.isDate(date, inSameDayAs: today) }
    @State private var showCapture = false
    @State private var captureText = ""
    @FocusState private var captureFocused: Bool
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.holidayService) private var holidays
    @State private var mode: Mode = .list
    @AppStorage("jinzhao.todayStickyExpanded") private var stickyExpanded = false

    enum Mode: String, CaseIterable { case list = "列表", timeline = "时间轴", board = "看板" }

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var headerTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
    }

    var body: some View {
        SolidCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    greetingLine
                    dateStrip
                    workdayAlert
                    calendarBanner
                    dailyOverview
                    // 宽：便签 | 习惯+明天 两栏；中：便签在上，习惯和明天并排；窄：全部单栏
                    ViewThatFits(in: .horizontal) {
                        dashboardColumns
                        VStack(alignment: .leading, spacing: 12) {
                            primaryPanel
                            HStack(alignment: .top, spacing: 12) {
                                habitsCard.frame(minWidth: 230, maxWidth: .infinity, alignment: .topLeading)
                                tomorrowCard.frame(minWidth: 230, maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            primaryPanel
                            habitsCard
                            tomorrowCard
                        }
                    }
                }
                .padding(18)
            }
        }
    }

    // MARK: 今日工作区布局

    /// 有足够宽度时采用两栏，窄窗口自动改为单栏，避免挤压主任务列表。
    private var dashboardColumns: some View {
        HStack(alignment: .top, spacing: 12) {
            primaryPanel
                .frame(minWidth: 380, maxWidth: .infinity, alignment: .topLeading)
            VStack(spacing: 12) {
                habitsCard
                tomorrowCard
            }
            .frame(width: 260)
        }
    }

    /// 今日便签：默认压缩为摘要；展开仍复用原来的完整任务与日程列表。
    /// 不引入新的存储模型，所有勾选继续写入 DataStore。
    private var primaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "note.text")
                    .foregroundStyle(Color.orange)
                    .font(.system(size: 17, weight: .medium))
                Text("今天的便签")
                    .font(.jzSection)
                Text("\(displayTasks.filter { !$0.isDone }.count) 项待办")
                    .font(.jzCaption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeInOut(duration: 0.20)) { stickyExpanded.toggle() }
                } label: {
                    Label(stickyExpanded ? "收起" : "展开",
                          systemImage: stickyExpanded ? "chevron.up" : "chevron.down")
                        .font(.jzCaption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(stickyExpanded ? "收起今日便签" : "展开完整今日任务与日程")
            }
            if mode == .list {
                if stickyExpanded {
                    todayList
                } else {
                    compactStickyContent
                }
            } else if mode == .timeline {
                TimeGridView(days: [cal.startOfDay(for: date)], hourHeight: 38, showsHeader: false)
                    .frame(height: 460)
            } else {
                TaskBoardView(tasks: displayTasks, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous)
                        .fill(Color.orange.opacity(0.055))
                }
        )
        .overlay {
            RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.17), lineWidth: 0.7)
        }
    }

    private var compactStickyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            let unfinished = displayTasks.filter { !$0.isDone }
            if unfinished.isEmpty {
                Text("给今天留一点空间，想到的事随手记下。")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(unfinished.prefix(3)) { task in
                    HStack(spacing: 9) {
                        Button {
                            store.toggleTask(task)
                        } label: {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Text(task.title)
                            .font(.jzBody)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                if unfinished.count > 3 {
                    Text("另有 \(unfinished.count - 3) 项，展开查看")
                        .font(.jzCaption).foregroundStyle(.secondary)
                }
            }
            let dayEvents = calendar.events(on: date)
            if !dayEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                    Text("还有 \(dayEvents.count) 项今日日程")
                        .foregroundStyle(.secondary)
                }
                .font(.jzCaption)
            }
            HStack(spacing: 10) {
                Button {
                    NotificationCenter.default.post(name: .jinzhaoNewTask, object: nil)
                } label: {
                    Label("添加任务", systemImage: "plus")
                }
                .glassButton()
                .controlSize(.small)
                captureButton(prominent: false, small: true)
            }
        }
        .padding(.vertical, 4)
    }

    /// 轻量状态栏而非三块灰色统计卡，避免在空数据时堆叠空容器。
    private var dailyOverview: some View {
        let events = calendar.events(on: date).count
        let unfinished = store.tasks.filter { !$0.isDone }.count
        let checked = store.habits.filter { $0.isComplete }.count
        return HStack(spacing: 18) {
            overviewMetric("待办", value: "\(unfinished)", symbol: "checkmark.circle", color: JZ.accent)
            overviewMetric("日程", value: "\(events)", symbol: "calendar", color: JZ.teal)
            overviewMetric("习惯", value: "\(checked)/\(store.habits.count)", symbol: "circle.dotted.circle", color: JZ.warm)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(JZ.separator.opacity(0.35)).frame(height: 0.5)
        }
    }

    private func overviewMetric(_ title: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(color)
            Text(value).font(.jzBody.weight(.semibold)).foregroundStyle(.primary)
            Text(title).font(.jzCaption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.jzDisplay)
                let lunar = LunarCalendar.info(for: date)
                let term = SolarTermTable.term(on: date) ?? SolarTermTable.currentTerm(on: date) ?? ""
                Text("农历\(lunar.shortText) · \(term) · \(lunar.ganzhiYear)\(lunar.zodiac)年")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !viewingToday {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedDay = nil }
                } label: {
                    Label("回到今天", systemImage: "arrow.uturn.backward")
                        .font(.jzBody)
                }
                .glassButton()
                .padding(.trailing, 6)
            }
            // 分段控件：玻璃底 + 白字，不用饱和蓝（全页蓝色焦点只留给日期条「今天」）
            HStack(spacing: 2) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { mode = m }
                    } label: {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(m.rawValue))
                        }
                        .font(.jzBody)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(mode == m ? JZ.hoverFill : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(JZ.controlFill, in: Capsule())
        }
    }

    private var greetingLine: some View {
        let hour = cal.component(.hour, from: Date())
        let greet = hour < 12 ? "早上好" : hour < 18 ? "下午好" : "晚上好"
        let openTasks = store.tasks.filter { !$0.isDone }.count
        let important = store.tasks.filter { $0.isImportant && !$0.isDone }.count
        return VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 8) {
            Text(viewingToday ? "\(greet)，老板。" : "\(relativeDayText)，").fontWeight(.medium)
            if isFirstWorkdayAfterHoliday {
                Text("假期结束第一天，今天").foregroundStyle(.secondary)
            }
            let dayEventCount = calendar.events(on: date).count
            if dayEventCount > 0 {
                Label("\(dayEventCount) 个日程", systemImage: "calendar").font(.callout)
            }
            Label("\(store.habits.count) 个习惯", systemImage: "repeat").font(.callout)
            if important > 0 {
                Label("\(important) 件重要", systemImage: "flag.fill").font(.callout).foregroundStyle(JZ.warm)
            }
            Text("· \(openTasks) 项待办").font(.callout).foregroundStyle(.secondary)
          }
          // 宣传语：问候下方小字，每天打开第一眼能看到，不抢汇总信息
          Text("把今天，过得井井有条。")
            .font(.jzCaption).foregroundStyle(.secondary)
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
            stripArrow("chevron.left", days: -7)
            ForEach(stripDays, id: \.self) { day in
                // isToday 在这里表示「选中」：选中格用品牌橙；真正的今天另用文字「今天」标出
                let isToday = cal.isDate(day, inSameDayAs: date)
                let isRealToday = cal.isDate(day, inSameDayAs: today)
                let badge = holidays.badge(on: day)
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Text(isRealToday ? "今天" : "周\(weekdayText(day))")
                            .font(.caption2).foregroundStyle(isToday ? .white : .secondary)
                        if let t = badge.text {
                            Text(t).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(isWork(badge) ? JZ.warm : JZ.success,
                                            in: Capsule())
                        }
                    }
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(dayNumberColor(day, isToday: isToday))
                    Text(SolarTermTable.term(on: day) ?? LunarCalendar.info(for: day).dayText)
                        .font(.caption2).foregroundStyle(isToday ? .white.opacity(0.9) : .secondary)
                    // 有日程/任务的日子底部一个小点（选中格白点，其余橙点）
                    Circle()
                        .fill(isToday ? Color.white : JZ.accent)
                        .frame(width: 4, height: 4)
                        .opacity(hasItems(on: day) ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isToday ? JZ.accent : JZ.controlFill,
                            in: RoundedRectangle(cornerRadius: 13))
                .overlay {
                    if isRealToday && !isToday {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(JZ.accent.opacity(0.7), lineWidth: 1.2)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 13))
                .onTapGesture { select(day) }
                .hoverHighlight()
                .help(isToday ? "" : "查看这一天")
            }
            stripArrow("chevron.right", days: 7)
        }
    }

    private func stripArrow(_ symbol: String, days: Int) -> some View {
        Button {
            select(cal.date(byAdding: .day, value: days, to: date)!)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(days < 0 ? "上一周" : "下一周")
    }

    private func select(_ day: Date) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedDay = cal.isDate(day, inSameDayAs: today) ? nil : cal.startOfDay(for: day)
        }
    }

    private func hasItems(on day: Date) -> Bool {
        if !calendar.events(on: day).isEmpty { return true }
        return store.tasks.contains { t in
            !t.isDone && (t.dueDate.map { cal.isDate($0, inSameDayAs: day) } ?? false)
        }
    }

    /// 非今天时问候语换成「明天 / 昨天 / 11月23日」
    private var relativeDayText: String {
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: today), to: cal.startOfDay(for: date)).day ?? 0
        switch diff {
        case 1: return "明天"
        case -1: return "昨天"
        case 2: return "后天"
        default:
            let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"
            return f.string(from: date)
        }
    }

    // MARK: 随手记录（弹出小输入框，存进收件箱或直接成为任务）

    private func captureButton(prominent: Bool, small: Bool) -> some View {
        Button {
            captureText = ""
            showCapture = true
        } label: {
            Label("随手记录", systemImage: "square.and.pencil")
        }
        .glassButton(prominent: prominent)
        .controlSize(small ? .small : .regular)
        .popover(isPresented: $showCapture, arrowEdge: .bottom) { capturePopover }
    }

    private var capturePopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("随手记录").font(.jzSection)
            TextField("想到什么，先写下来…", text: $captureText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($captureFocused)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous))
                .onSubmit { saveCapture(asTask: false) }
            HStack {
                Text("回车存入收件箱").font(.jzCaption).foregroundStyle(.secondary)
                Spacer()
                Button("设为\(viewingToday ? "今天" : relativeDayText)任务") { saveCapture(asTask: true) }
                    .glassButton()
                    .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("存入收件箱") { saveCapture(asTask: false) }
                    .glassButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
                    .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { DispatchQueue.main.async { captureFocused = true } }
    }

    private func saveCapture(asTask: Bool) {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if asTask {
            store.addTask(title: text, dueDate: date)
        } else {
            store.addInbox(text: text)
        }
        captureText = ""
        showCapture = false
    }

    private func isWork(_ badge: DayBadge) -> Bool {
        if case .work = badge { return true }
        return false
    }

    private func dayNumberColor(_ day: Date, isToday: Bool) -> Color {
        if isToday { return .white }
        return holidays.isOffDay(on: day) ? JZ.success : .primary
    }

    private func weekdayText(_ day: Date) -> String {
        ["日", "一", "二", "三", "四", "五", "六"][cal.component(.weekday, from: day) - 1]
    }

    // MARK: 调休提醒条

    @ViewBuilder private var workdayAlert: some View {
        if let next = nextAdjustedWorkday {
            HStack(spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(JZ.warm)
                Text("\(holidayText(next)) 为调休工作日，请留意当天安排。")
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(JZ.warm.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
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
        // 看其他日子时只列当天到期的任务；看今天时含无截止和已逾期的
        let open = viewingToday
            ? store.tasks.filter { !$0.isDone && ($0.dueDate == nil || $0.dueDate! < endOfToday) }
            : store.tasks.filter { !$0.isDone && ($0.dueDate.map { cal.isDate($0, inSameDayAs: date) } ?? false) }
        let doneToday = store.tasks.filter { t in
            t.isDone && (t.doneAt.map { cal.isDate($0, inSameDayAs: date) } ?? false)
        }
        return open + doneToday
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(viewingToday ? "今天" : relativeDayText) 日程与任务 · \(calendar.events(on: date).count + displayTasks.count)")
                .font(.jzSection).padding(.bottom, 6)
            if calendar.events(on: date).isEmpty && displayTasks.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(JZ.accent.opacity(0.72))
                        .frame(width: 52, height: 52)
                        .background(JZ.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                    Text(viewingToday ? "今天，从一件小事开始" : "\(relativeDayText)还没有安排")
                        .font(.system(size: 16, weight: .semibold))
                    Text("还没有安排。记录一项待办，或先把想法放进收件箱。")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button {
                            NotificationCenter.default.post(name: .jinzhaoNewTask, object: nil)
                        } label: {
                            Label("新建任务", systemImage: "plus")
                        }
                        .glassButton(prominent: true)
                        captureButton(prominent: false, small: false)
                    }
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
                .padding(.vertical, 8)
            }
            // 无分隔线（定版规范），靠行距与 hover 高亮区分
            ForEach(calendar.events(on: date)) { event in
                eventRow(event)
            }
            ForEach(displayTasks) { task in
                taskRow(task)
            }
            if !displayTasks.isEmpty && displayTasks.count + calendar.events(on: date).count < 3 {
                // 内容少时给一个轻量提示，填住左下空白
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(.secondary)
                    Text("今天安排不多。用右上角「新建」把剩下的时间也安排上吧。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous))
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.tasks)
    }

    private func isToday(_ d: Date) -> Bool { cal.isDate(d, inSameDayAs: date) }

    @Environment(\.openURL) private var openURL

    /// 日历未授权时的连接引导（授权后自动消失）
    @ViewBuilder private var calendarBanner: some View {
        if calendar.authState == .notDetermined {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus").foregroundStyle(.secondary)
                Text("连接苹果日历后，你的日程会出现在这里，带会议链接的还能一键入会。")
                    .font(.callout)
                Spacer()
                Button("连接日历") { Task { await calendar.requestAccess() } }
                    .glassButton(prominent: true).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: 11))
        } else if calendar.authState == .denied {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(JZ.warm)
                Text("日历权限被拒绝了，去系统设置里给今朝打开就能看到日程。")
                    .font(.callout)
                Spacer()
                Button("打开系统设置") { calendar.openPrivacySettings() }
                    .glassButton().controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(JZ.warm.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private func eventRow(_ e: CalendarEventItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                if e.isAllDay {
                    Text("全天").font(.callout.weight(.semibold))
                } else {
                    Text(e.start, style: .time).font(.callout.weight(.semibold))
                    Text(e.end, style: .time).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, alignment: .leading)
            Rectangle().fill(color(e.colorName)).frame(width: 3).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title).fontWeight(.medium).lineLimit(2)
                if let loc = e.location {
                    Label(loc, systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundStyle(.secondary)
                } else if let p = e.meetingProvider {
                    Label("\(p)会议", systemImage: "video")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let url = e.meetingURL {
                Button("加入会议") { openURL(url) }.glassButton().controlSize(.small)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .hoverHighlight()
    }

    /// 勾选圈上色：已完成绿 / 已过期红 / 按优先级 / 普通灰
    private func checkColor(_ t: TaskItem) -> Color {
        if t.isDone { return JZ.success }
        if let due = t.dueDate, due < Date() { return JZ.danger }
        if t.priorityLevel != .none { return t.priorityLevel.color }
        return .secondary
    }

    private func taskRow(_ t: TaskItem) -> some View {
        // 紧凑两行（对 Woday 结构）：标题一行，时间与标签胶囊一行；勾选圈贴着文字
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { store.toggleTask(t) }
            } label: {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checkColor(t))
                    .font(.system(size: 16))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.title)
                    .font(.jzBody.weight(.medium))
                    .strikethrough(t.isDone)
                    .foregroundStyle(t.isDone ? .secondary : .primary)
                HStack(spacing: 6) {
                    if t.priorityLevel != .none {
                        Label(t.priorityLevel.label, systemImage: "flag.fill").font(.jzCaption).foregroundStyle(t.priorityLevel.color)
                    }
                    if let ev = t.linkedEventTitle {
                        Label(ev, systemImage: "calendar").font(.jzCaption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if !t.subtasks.isEmpty {
                        Label("子任务 \(t.subtasks.filter { $0.isDone }.count)/\(t.subtasks.count)", systemImage: "checklist")
                            .font(.jzCaption).foregroundStyle(.secondary)
                    }
                    if let due = t.dueDate {
                        Label("截止 \(due, style: .time)", systemImage: "clock")
                            .font(.jzCaption).foregroundStyle(.secondary)
                    }
                    if let done = t.doneAt {
                        Label("\(done, style: .time) 完成", systemImage: "checkmark")
                            .font(.jzCaption).foregroundStyle(.secondary)
                    }
                    if let folder = t.folderName {
                        CapsuleTag(text: folder)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .hoverHighlight()
    }

    private func color(_ name: String) -> Color {
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

    // MARK: 右列卡片

    @State private var newHabitName = ""

    private var habitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewingToday ? "今日习惯" : "习惯（按今天进度）").font(.subheadline.weight(.semibold))
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
                        // 统一圆环：未完成是轨道+进度弧，完成是满环变绿+对勾，不再跳实心圆
                        ZStack {
                            Circle().stroke(JZ.controlFill, lineWidth: 5)
                            Circle().trim(from: 0, to: habit.isComplete ? 1 : habit.fraction)
                                .stroke(habit.isComplete ? JZ.success : JZ.teal,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            if habit.isComplete {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(JZ.success).fontWeight(.bold)
                            } else if let time = habit.scheduledTime {
                                Text(time).font(.system(size: 12, weight: .semibold))
                            } else {
                                Text("\(Int(habit.todayProgress))/\(Int(habit.targetPerDay))")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .frame(width: 52, height: 52)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: habit.todayProgress)
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous)
                .strokeBorder(JZ.separator.opacity(0.35), lineWidth: 0.5)
        }
    }

    private func habitDetail(_ h: HabitItem) -> String {
        if let _ = h.scheduledTime { return "今晚" }
        return "还差 \(Int(h.targetPerDay - h.todayProgress)) \(h.unit)"
    }

    /// 明天卡只显示「明天到期」的任务（旧版拿任意未完成任务充数，导致今天的任务在明天卡里重复出现）
    private func tomorrowTasks(_ tomorrow: Date) -> [TaskItem] {
        store.tasks.filter { t in
            guard let due = t.dueDate, !t.isDone else { return false }
            return cal.isDate(due, inSameDayAs: tomorrow)
        }
    }

    private var tomorrowCard: some View {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: date)!
        let lunar = LunarCalendar.info(for: tomorrow)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(viewingToday ? "明天" : "次日") · \(holidayText(tomorrow))").font(.subheadline.weight(.semibold))
                Spacer()
                Text("农历\(lunar.shortText)").font(.caption).foregroundStyle(.secondary)
            }
            if calendar.events(on: tomorrow).isEmpty
                && tomorrowTasks(tomorrow).isEmpty {
                Text("明天暂无安排").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(calendar.events(on: tomorrow).filter { !$0.isAllDay }) { e in
                HStack(spacing: 8) {
                    Text(e.start, style: .time).font(.callout.weight(.medium))
                    Text(e.title).font(.callout)
                }
                if let loc = e.location {
                    Text(loc).font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(tomorrowTasks(tomorrow)) { t in
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous)
                .strokeBorder(JZ.separator.opacity(0.35), lineWidth: 0.5)
        }
    }
}
