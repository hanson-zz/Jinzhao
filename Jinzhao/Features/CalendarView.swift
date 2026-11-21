import SwiftUI

/// 日历页：月 / 周 / 3 天 / 日 四种视图
/// 月视图：农历/节气/休班 + 日程圆点 + 选中日列表；时间视图：日程 + 今朝任务时间块，可拖任务排期
struct CalendarView: View {
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.holidayService) private var holidays
    @Environment(\.openURL) private var openURL
    @State private var monthAnchor: Date = Date()
    @State private var selectedDay: Date = Date()
    @State private var showingNewEvent = false
    @AppStorage("jinzhao.calendarMode") private var modeRaw = ViewMode.week.rawValue

    enum ViewMode: String, CaseIterable {
        case day = "日", three = "3 天", week = "周", month = "月"
    }

    private var mode: ViewMode { ViewMode(rawValue: modeRaw) ?? .week }

    /// 时间视图显示的日期：周视图从周一开始（国内习惯）
    private var gridDays: [Date] {
        let start = cal.startOfDay(for: selectedDay)
        switch mode {
        case .day: return [start]
        case .three: return (0..<3).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        case .week, .month:
            let w = cal.component(.weekday, from: start)
            let back = (w + 5) % 7
            let monday = cal.date(byAdding: .day, value: -back, to: start) ?? start
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        }
    }

    private var rangeTitle: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        switch mode {
        case .month:
            return monthTitle
        case .day:
            f.dateFormat = "yyyy年M月d日"
            return f.string(from: selectedDay)
        default:
            guard let a = gridDays.first, let b = gridDays.last else { return monthTitle }
            f.dateFormat = "yyyy年M月d日"
            let g = DateFormatter(); g.locale = Locale(identifier: "zh_CN")
            g.dateFormat = cal.component(.month, from: a) == cal.component(.month, from: b) ? "d日" : "M月d日"
            return "\(f.string(from: a)) – \(g.string(from: b))"
        }
    }

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var monthTitle: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月"
        return f.string(from: monthAnchor)
    }

    private var cells: [Date?] {
        let year = cal.component(.year, from: monthAnchor)
        let month = cal.component(.month, from: monthAnchor)
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let daysInMonth = cal.range(of: .day, in: .month, for: first)!.count
        let lead = cal.component(.weekday, from: first) - 1
        return Array(repeating: nil, count: lead) + (1...daysInMonth).map {
            cal.date(from: DateComponents(year: year, month: month, day: $0))
        }
    }

    var body: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 14) {
                header
                if mode == .month {
                    if calendar.authState == .authorized {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                weekdayRow
                                monthGrid
                                dayDetail
                            }
                        }
                    } else {
                        authPrompt
                    }
                } else {
                    if calendar.authState != .authorized { authBanner }
                    HStack(alignment: .top, spacing: 12) {
                        TimeGridView(days: gridDays)
                        UnscheduledTray()
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showingNewEvent) {
            NewEventSheet()
        }
        // 菜单「新建日程」：切到日历页后自动打开新建表单（已授权时）
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoOpenNewEvent)) { _ in
            if calendar.authState == .authorized { showingNewEvent = true }
        }
    }

    private var header: some View {
        HStack {
            Text(rangeTitle).font(.system(size: 22, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Picker("视图", selection: $modeRaw) {
                ForEach(ViewMode.allCases, id: \.self) { m in
                    Text(LocalizedStringKey(m.rawValue)).tag(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .glassButton().controlSize(.small)
            Button("今天") {
                monthAnchor = Date()
                selectedDay = Date()
            }
            .glassButton().controlSize(.small)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .glassButton().controlSize(.small)
            Button("+ 新建日程") { showingNewEvent = true }
                .glassButton().controlSize(.small)
                .disabled(calendar.authState != .authorized)
        }
    }

    private func shift(_ delta: Int) {
        switch mode {
        case .month: shiftMonth(delta)
        case .day: move(days: delta)
        case .three: move(days: delta * 3)
        case .week: move(days: delta * 7)
        }
    }

    private func move(days: Int) {
        if let d = cal.date(byAdding: .day, value: days, to: selectedDay) {
            selectedDay = d
            monthAnchor = d
        }
    }

    private var authBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(JZ.warm)
            Text("还没连接苹果日历，这里先只显示今朝任务。").font(.callout)
            Spacer()
            if calendar.authState == .denied {
                Button("打开系统设置") { calendar.openPrivacySettings() }.glassButton().controlSize(.small)
            } else {
                Button("连接日历") { Task { await calendar.requestAccess() } }.glassButton().controlSize(.small)
            }
        }
        .padding(10)
        .background(JZ.warm.opacity(0.08), in: RoundedRectangle(cornerRadius: JZ.radiusS))
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) {
                Text("周\($0)").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    dayCell(day)
                } else {
                    Text("").frame(height: 46)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let dayEvents = calendar.events(on: day)
        let badge = holidays.badge(on: day)
        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected || isToday ? .white : (holidays.isOffDay(on: day) ? JZ.success : .primary))
                if let t = badge.text {
                    Text(t).font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(isWorkBadge(badge) ? JZ.warm : JZ.success, in: Capsule())
                }
            }
            Text(SolarTermTable.term(on: day) ?? LunarCalendar.info(for: day).dayText)
                .font(.system(size: 9))
                .foregroundStyle(isSelected || isToday ? .white.opacity(0.85) : .secondary)
            HStack(spacing: 2) {
                ForEach(dayEvents.prefix(3)) { e in
                    Circle().fill(dotColor(e.colorName)).frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(isSelected ? JZ.accent : (isToday ? JZ.accent.opacity(0.35) : JZ.innerFill),
                    in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { selectedDay = day; modeRaw = ViewMode.day.rawValue }
        .onTapGesture { selectedDay = day }
    }

    private func isWorkBadge(_ badge: DayBadge) -> Bool {
        if case .work = badge { return true }
        return false
    }

    private func dotColor(_ name: String) -> Color {
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

    // MARK: 选中日详情

    private var dayDetail: some View {
        let dayEvents = calendar.events(on: selectedDay)
        return VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle(selectedDay)).font(.subheadline.weight(.semibold))
            if dayEvents.isEmpty {
                Text("这一天没有日程").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(dayEvents) { e in
                HStack(spacing: 10) {
                    Text(e.isAllDay ? "全天" : timeText(e.start))
                        .font(.callout.weight(.medium))
                        .frame(width: 46, alignment: .leading)
                    Rectangle().fill(dotColor(e.colorName)).frame(width: 3).clipShape(Capsule())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.title).fontWeight(.medium).lineLimit(1)
                        if let loc = e.location {
                            Text(loc).font(.caption).foregroundStyle(.secondary)
                        } else if let p = e.meetingProvider {
                            Text("\(p)会议").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let url = e.meetingURL {
                        Button("加入会议") { openURL(url) }.glassButton().controlSize(.small)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 EEEE"
        let lunar = LunarCalendar.info(for: day)
        return "\(f.string(from: day)) · 农历\(lunar.shortText)"
    }

    private func timeText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    // MARK: 未授权引导

    private var authPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus").font(.system(size: 36)).foregroundStyle(.secondary)
            Text("先连接苹果日历").font(.headline)
            Text("授权后，这里会显示你所有日历的月视图，新建的日程也会直接写进苹果日历。")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            if calendar.authState == .denied {
                Button("打开系统设置") { calendar.openPrivacySettings() }
                    .glassButton(prominent: true)
            } else {
                Button("连接日历") { Task { await calendar.requestAccess() } }
                    .glassButton(prominent: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - 新建日程表单

struct NewEventSheet: View {
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(3600)
    @State private var location = ""
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("新建日程").font(.title3.weight(.bold))
            TextField("日程标题", text: $title).textFieldStyle(.roundedBorder)
            DatePicker("开始", selection: $start)
            DatePicker("结束", selection: $end)
            TextField("地点（可空）", text: $location).textFieldStyle(.roundedBorder)
            if failed {
                Text("保存失败：请确认日历权限已开启，并且系统里有可用的默认日历。")
                    .font(.caption).foregroundStyle(JZ.danger)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .glassButton()
                Button("保存到苹果日历") {
                    if calendar.createEvent(title: title.isEmpty ? "（无标题）" : title,
                                            start: start, end: end,
                                            location: location.isEmpty ? nil : location) {
                        dismiss()
                    } else {
                        failed = true
                    }
                }
                .glassButton(prominent: true)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
