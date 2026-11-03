import SwiftUI

/// 右栏（常驻）：收件箱 + 下一个假期卡（带完整小日历：月份标题 / 农历 / 休班标记）
struct InboxRailView: View {
    let today: Date
    @EnvironmentObject private var store: DataStore
    @Environment(\.holidayService) private var holidays
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JZ.spaceM) {
                inboxSection
                nextHolidayCard
                Spacer()
            }
            .padding(16)
        }
        // ⌘N / 菜单「随手记到收件箱」：光标直接落进输入框（之前命令发了没人接，是死的）
        .onReceive(NotificationCenter.default.publisher(for: .jinzhaoQuickCapture)) { _ in
            draftFocused = true
        }
    }

    // MARK: 收件箱

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("收件箱").font(.jzSection)
                // 计数胶囊改玻璃底（全页蓝色焦点只留给小日历的今天）
                Text("\(store.inbox.count)")
                    .font(.jzCaption.weight(.bold))
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(JZ.controlFill, in: Capsule())
                Spacer()
            }
            HStack {
                TextField("随手记一笔…", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($draftFocused)
                    .onSubmit {
                        store.addInbox(text: draft)
                        draft = ""
                    }
                Text("⌘N").font(.jzCaption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(JZ.controlFill, in: RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous))

            if store.inbox.isEmpty {
                Text("空空如也。想到什么先记在这里，回头再分流。")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            ForEach(store.inbox) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "circle").font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text).font(.callout)
                        if let lunar = item.lunarNote {
                            Text(lunar).font(.caption).foregroundStyle(JZ.teal)
                        }
                    }
                    Spacer()
                    Text(relativeText(item.createdAt)).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .hoverHighlight()
                .contextMenu {
                    Button("删除", role: .destructive) { store.deleteInbox(item) }
                }
            }
        }
    }

    private func relativeText(_ d: Date) -> String {
        if cal.isDateInToday(d) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return "今天 \(f.string(from: d))"
        }
        if cal.isDateInYesterday(d) {
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            return "昨天 \(f.string(from: d))"
        }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日"
        return f.string(from: d)
    }

    // MARK: 下一个假期卡

    @ViewBuilder private var nextHolidayCard: some View {
        if let next = holidays.nextHoliday(after: today) {
            VStack(alignment: .leading, spacing: 8) {
                Text("下一个假期").font(.jzCaption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(next.name).font(.system(size: 24, weight: .bold))
                    Text("还有 \(next.daysAway) 天").font(.callout).foregroundStyle(.secondary)
                }
                Text(next.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.jzCaption).foregroundStyle(.secondary)
                if next.arrangementPending {
                    // 短句防截断（更新模块已接线，公布后会自动换成正式安排）
                    Text("调休安排待公布")
                        .font(.jzCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                miniMonth
            }
            .padding(JZ.spaceM)
            .background(JZ.warm.opacity(0.13), in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
        }
    }

    /// 当月小日历（卖点做足）：月份标题 + 每天带农历/节气 + 休红字、班小角标 + 今天蓝圈
    private var miniMonth: some View {
        let year = cal.component(.year, from: today)
        let month = cal.component(.month, from: today)
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let daysInMonth = cal.range(of: .day, in: .month, for: first)!.count
        let lead = cal.component(.weekday, from: first) - 1 // 周日起
        let cells: [Date?] = Array(repeating: nil, count: lead) + (1...daysInMonth).map {
            cal.date(from: DateComponents(year: year, month: month, day: $0))
        }
        return VStack(spacing: 5) {
            HStack {
                Text(verbatim: "\(year)年\(month)月").font(.jzCaption.weight(.semibold))
                Spacer()
                Text("农历\(LunarCalendar.info(for: today).monthText)")
                    .font(.jzCaption).foregroundStyle(.secondary)
            }
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) {
                    Text($0).font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let d = cell {
                        miniCell(d)
                    } else {
                        Text("").frame(height: 30)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func miniCell(_ d: Date) -> some View {
        let isToday = cal.isDate(d, inSameDayAs: today)
        let badge = holidays.badge(on: d)
        let sub = SolarTermTable.term(on: d) ?? LunarCalendar.info(for: d).dayText
        return VStack(spacing: 0) {
            HStack(spacing: 1) {
                Text("\(cal.component(.day, from: d))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : (holidays.isOffDay(on: d) ? JZ.danger : .primary))
                if let t = badge.text {
                    Text(t)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(isToday ? .white : (badgeIsWork(badge) ? .secondary : JZ.danger))
                }
            }
            Text(sub)
                .font(.system(size: 8))
                .foregroundStyle(isToday ? .white.opacity(0.85) : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(isToday ? JZ.accent : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func badgeIsWork(_ badge: DayBadge) -> Bool {
        if case .work = badge { return true }
        return false
    }
}
