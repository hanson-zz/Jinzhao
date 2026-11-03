import SwiftUI

/// 日历页：月视图（农历/节气/休班 + 日程圆点）+ 选中日的日程列表 + 新建日程（写入苹果日历）
struct CalendarView: View {
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.holidayService) private var holidays
    @Environment(\.openURL) private var openURL
    @State private var monthAnchor: Date = Date()
    @State private var selectedDay: Date = Date()
    @State private var showingNewEvent = false

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
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                header
                if calendar.authState == .authorized {
                    weekdayRow
                    monthGrid
                    dayDetail
                } else {
                    authPrompt
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
            Text(monthTitle).font(.system(size: 22, weight: .bold))
            Spacer()
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.bordered).controlSize(.small)
            Button("今天") {
                monthAnchor = Date()
                selectedDay = Date()
            }
            .buttonStyle(.bordered).controlSize(.small)
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.bordered).controlSize(.small)
            Button("+ 新建日程") { showingNewEvent = true }
                .glassButton().controlSize(.small)
                .disabled(calendar.authState != .authorized)
        }
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
                    .foregroundStyle(isSelected || isToday ? .white : (holidays.isOffDay(on: day) ? .red : .primary))
                if let t = badge.text {
                    Text(t).font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(isWorkBadge(badge) ? Color.gray : Color.red, in: Capsule())
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
        .background(isSelected ? JZ.accent : (isToday ? JZ.accent.opacity(0.35) : Color.white.opacity(0.05)),
                    in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
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
                    .buttonStyle(.borderedProminent)
            } else {
                Button("连接日历") { Task { await calendar.requestAccess() } }
                    .buttonStyle(.borderedProminent)
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
                    .font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存到苹果日历") {
                    if calendar.createEvent(title: title.isEmpty ? "（无标题）" : title,
                                            start: start, end: end,
                                            location: location.isEmpty ? nil : location) {
                        dismiss()
                    } else {
                        failed = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
