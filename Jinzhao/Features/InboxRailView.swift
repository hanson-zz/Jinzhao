import SwiftUI

/// 右栏（常驻）：收件箱 + 下一个假期卡
struct InboxRailView: View {
    let today: Date
    @EnvironmentObject private var store: DemoStore
    @Environment(\.holidayService) private var holidays
    @State private var draft = ""

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                inboxSection
                Spacer()
                nextHolidayCard
            }
            .padding(16)
        }
    }

    // MARK: 收件箱

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("收件箱").font(.headline)
                Text("\(store.inbox.count)")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(.blue, in: Capsule())
                Spacer()
            }
            HStack {
                TextField("随手记一笔…", text: $draft)
                    .textFieldStyle(.plain)
                Text("⌘N").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            ForEach(store.inbox) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "circle").font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text).font(.callout)
                        if let lunar = item.lunarNote {
                            Text(lunar).font(.caption).foregroundStyle(.blue)
                        }
                    }
                    Spacer()
                    Text(relativeText(item.createdAt)).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func relativeText(_ d: Date) -> String {
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
                Text("下一个假期").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(next.name).font(.system(size: 24, weight: .bold))
                    Text("还有 \(next.daysAway) 天").font(.callout).foregroundStyle(.secondary)
                }
                Text(next.arrangementPending ? "调休安排公布后自动更新" : (next.date.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption).foregroundStyle(.secondary)
                miniMonth
            }
            .padding(14)
            .background(Color.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))
        }
    }

    /// 当月小日历：今天高亮，休的日子标红
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
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) {
                    Text($0).font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 5) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let d = cell {
                        let isToday = cal.isDate(d, inSameDayAs: today)
                        Text("\(cal.component(.day, from: d))")
                            .font(.system(size: 11, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .white : (holidays.isOffDay(on: d) ? .red : .primary))
                            .frame(width: 22, height: 22)
                            .background(isToday ? Color.blue : .clear, in: Circle())
                    } else {
                        Text("").frame(width: 22, height: 22)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}
