import SwiftUI

/// 右栏（常驻）：收件箱 + 下一个假期卡（带完整小日历：月份标题 / 农历 / 休班标记）
struct InboxRailView: View {
    let today: Date
    /// 今天页正在看的日子（nil = 今天），点小日历会改它
    @Binding var focusDay: Date?
    /// 点了小日历某天后让外壳切到「今天」页
    var onPickDay: () -> Void = {}
    /// 小日历相对本月的偏移（‹ › 翻月）
    @State private var monthOffset = 0
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
            // 延一拍再聚焦：按钮/菜单还握着焦点时同步设置会被吞掉
            DispatchQueue.main.async { draftFocused = true }
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
                    Text(next.name).font(.system(size: 22, weight: .bold))
                    Spacer(minLength: 4)
                    Text("\(next.daysAway)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(JZ.accent)
                    Text("天后").font(.jzCaption).foregroundStyle(.secondary)
                }
                Text(holidayDateText(next.date))
                    .font(.jzCaption).foregroundStyle(.secondary)
                if next.arrangementPending {
                    // 短句防截断（更新模块已接线，公布后会自动换成正式安排）
                    Text("调休安排待公布")
                        .font(.jzCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().opacity(0.5).padding(.vertical, 2)
                miniMonth
            }
            .padding(JZ.spaceM)
            // 改成和其他卡片一致的中性底 + 细描边（原来的橙褐色底在深色下发闷）
            .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous)
                    .strokeBorder(JZ.separator.opacity(0.35), lineWidth: 0.5)
            }
        }
    }

    private func holidayDateText(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: d)
    }

    private var shownMonth: Date {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        return cal.date(byAdding: .month, value: monthOffset, to: first)!
    }

    /// 当月小日历（卖点做足）：月份标题 + 每天带农历/节气 + 休红字、班小角标 + 今天蓝圈
    private var miniMonth: some View {
        let year = cal.component(.year, from: shownMonth)
        let month = cal.component(.month, from: shownMonth)
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let daysInMonth = cal.range(of: .day, in: .month, for: first)!.count
        let lead = cal.component(.weekday, from: first) - 1 // 周日起
        let cells: [Date?] = Array(repeating: nil, count: lead) + (1...daysInMonth).map {
            cal.date(from: DateComponents(year: year, month: month, day: $0))
        }
        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text(verbatim: "\(year)年\(month)月").font(.jzCaption.weight(.semibold))
                Text("农历\(LunarCalendar.info(for: monthOffset == 0 ? today : shownMonth).monthText)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                if monthOffset != 0 {
                    Button("本月") { withAnimation(.easeInOut(duration: 0.15)) { monthOffset = 0 } }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(JZ.accent)
                }
                monthArrow("chevron.left", -1)
                monthArrow("chevron.right", 1)
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

    private func monthArrow(_ symbol: String, _ delta: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { monthOffset += delta }
        } label: {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.secondary)
        .help(delta < 0 ? "上个月" : "下个月")
    }

    private func miniCell(_ d: Date) -> some View {
        let isToday = cal.isDate(d, inSameDayAs: today)
        let isFocused = focusDay.map { cal.isDate($0, inSameDayAs: d) } ?? false
        let badge = holidays.badge(on: d)
        let sub = SolarTermTable.term(on: d) ?? LunarCalendar.info(for: d).dayText
        return VStack(spacing: 0) {
            HStack(spacing: 1) {
                Text("\(cal.component(.day, from: d))")
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : (holidays.isOffDay(on: d) ? JZ.success : .primary))
                if let t = badge.text {
                    Text(t)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(isToday ? .white : (badgeIsWork(badge) ? JZ.warm : JZ.success))
                }
            }
            Text(sub)
                .font(.system(size: 8))
                .foregroundStyle(isToday ? .white.opacity(0.85) : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(isToday ? JZ.accent : (isFocused ? JZ.accent.opacity(0.22) : Color.clear),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onTapGesture {
            focusDay = isToday ? nil : cal.startOfDay(for: d)
            onPickDay()
        }
        .help("在今天页查看这一天")
    }

    private func badgeIsWork(_ badge: DayBadge) -> Bool {
        if case .work = badge { return true }
        return false
    }
}
