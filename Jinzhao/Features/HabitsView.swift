import SwiftUI

/// 习惯统计页：每个习惯一张卡——今日打卡、连续天数、最长连续、近 30 天完成率、近 12 周热力图
struct HabitsView: View {
    @EnvironmentObject private var store: DataStore
    @State private var newName = ""
    @State private var newTarget = 1
    @State private var newUnit = ""
    @State private var editing: HabitItem?

    var body: some View {
        SolidCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    addBar
                    if store.habits.isEmpty {
                        empty
                    } else {
                        summary
                        ForEach(store.habits) { h in
                            HabitStatsCard(habit: h, onEdit: { editing = h })
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $editing) { h in
            HabitEditSheet(habit: h)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("习惯统计").font(.system(size: 24, weight: .bold))
            Text("今天完成 \(store.habits.filter { $0.isComplete }.count)/\(store.habits.count)")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle").foregroundStyle(.secondary)
            TextField("新习惯，如：喝水、读书、早睡", text: $newName)
                .textFieldStyle(.plain)
                .onSubmit(add)
            Stepper(value: $newTarget, in: 1...50) {
                Text("每天 \(newTarget) 次").font(.callout).foregroundStyle(.secondary)
            }
            .fixedSize()
            TextField("单位", text: $newUnit)
                .textFieldStyle(.plain)
                .frame(width: 44)
            if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("添加", action: add).glassButton()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: 11))
    }

    private func add() {
        store.addHabit(name: newName, targetPerDay: Double(newTarget), unit: newUnit)
        newName = ""; newTarget = 1; newUnit = ""
    }

    private var summary: some View {
        let stats = store.habits.map { HabitStats(habit: $0) }
        let hits = stats.map { $0.hits(days: 30) }
        let avgHits = hits.isEmpty ? 0 : Int((Double(hits.reduce(0, +)) / Double(hits.count)).rounded())
        let avg = Double(avgHits) / 30
        let best = stats.map { $0.longestStreak }.max() ?? 0
        let current = store.habits.map { $0.streakDays }.max() ?? 0
        return HStack(spacing: 12) {
            summaryCard {
                ZStack {
                    Circle().stroke(JZ.controlFill, lineWidth: 7)
                    Circle().trim(from: 0, to: avg)
                        .stroke(JZ.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((avg * 100).rounded()))%").font(.system(size: 17, weight: .bold)).monospacedDigit()
                }
                .frame(width: 64, height: 64)
            } text: {
                Text("近 30 天完成率").font(.system(size: 14, weight: .semibold))
                Text("\(avgHits) / 30 天").font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
            }
            summaryCard {
                iconBadge("flame.fill")
            } text: {
                Text("当前最长连续").font(.system(size: 14, weight: .semibold))
                bigDays(current)
            }
            summaryCard {
                iconBadge("trophy.fill")
            } text: {
                Text("历史最长连续").font(.system(size: 14, weight: .semibold))
                bigDays(best)
            }
        }
    }

    private func summaryCard<L: View, T: View>(@ViewBuilder _ leading: () -> L, @ViewBuilder text: () -> T) -> some View {
        HStack(spacing: 16) {
            leading()
            Rectangle().fill(JZ.separator.opacity(0.5)).frame(width: 0.5, height: 44)
            VStack(alignment: .leading, spacing: 4) { text() }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [JZ.accent.opacity(0.10), JZ.accent.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous).strokeBorder(JZ.separator.opacity(0.35), lineWidth: 0.5)
        }
    }

    private func iconBadge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(JZ.accent)
            .frame(width: 60, height: 60)
            .background(JZ.accent.opacity(0.14), in: Circle())
    }

    private func bigDays(_ n: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(n)").font(.system(size: 26, weight: .bold)).monospacedDigit()
            Text("天").font(.system(size: 14))
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "repeat").font(.largeTitle).foregroundStyle(.secondary)
            Text("还没有习惯").font(.jzSection)
            Text("加一个小习惯，每天在今天页或这里点一下打卡。")
                .font(.jzBody).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

/// 统计计算：基于 doneDays（0.2 起记录）；旧数据没有历史时，用连续天数回推最近几天
struct HabitStats {
    let habit: HabitItem
    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var doneSet: Set<String> {
        var set = Set(habit.doneDays ?? [])
        if set.isEmpty, let last = habit.lastDoneDay, habit.streakDays > 0,
           let lastDate = HabitStats.date(from: last) {
            for i in 0..<habit.streakDays {
                if let d = cal.date(byAdding: .day, value: -i, to: lastDate) { set.insert(DataStore.key(for: d)) }
            }
        }
        return set
    }

    func hits(days: Int) -> Int {
        let set = doneSet
        var hit = 0
        for i in 0..<max(days, 0) {
            if let d = cal.date(byAdding: .day, value: -i, to: Date()), set.contains(DataStore.key(for: d)) { hit += 1 }
        }
        return hit
    }

    func rate(days: Int) -> Double {
        guard days > 0 else { return 0 }
        return Double(hits(days: days)) / Double(days)
    }

    var longestStreak: Int {
        let dates = doneSet.compactMap { HabitStats.date(from: $0) }.sorted()
        var best = 0, run = 0
        var prev: Date? = nil
        for d in dates {
            if let p = prev, let next = cal.date(byAdding: .day, value: 1, to: p), cal.isDate(next, inSameDayAs: d) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            prev = d
        }
        return max(best, habit.streakDays)
    }

    static func date(from key: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: key)
    }
}

private struct HabitStatsCard: View {
    let habit: HabitItem
    let onEdit: () -> Void
    @EnvironmentObject private var store: DataStore
    private var cal: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }

    var body: some View {
        let stats = HabitStats(habit: habit)
        let done = stats.doneSet
        let hits = stats.hits(days: 30)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button { store.advanceHabit(habit) } label: {
                    ZStack {
                        if habit.isComplete {
                            Circle().fill(JZ.accent)
                            Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        } else {
                            Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)
                            if habit.todayProgress > 0 {
                                Circle().trim(from: 0, to: habit.fraction)
                                    .stroke(JZ.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                    }
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(habit.targetPerDay > 1 ? "点一下 +1（今天 \(Int(habit.todayProgress))/\(Int(habit.targetPerDay))），满了再点清零" : "点一下打卡；再点一下取消")
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: habit.todayProgress)

                Rectangle().fill(JZ.separator.opacity(0.5)).frame(width: 0.5, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name).font(.system(size: 17, weight: .bold))
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                stat("连续", "\(habit.streakDays)", suffix: "天", highlight: true)
                divider
                stat("最长", "\(stats.longestStreak)", suffix: "天")
                divider
                stat("30天", "\(hits)", suffix: "天（\(Int((Double(hits) / 30 * 100).rounded()))%）")
                Menu {
                    Button("编辑…", action: onEdit)
                    Divider()
                    Button("删除习惯", role: .destructive) { store.deleteHabit(habit) }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
            heatmap(done)
        }
        .padding(16)
        .background(JZ.cardBg, in: RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: JZ.radiusL, style: .continuous).strokeBorder(JZ.separator.opacity(0.35), lineWidth: 0.5)
        }
    }

    private var divider: some View {
        Rectangle().fill(JZ.separator.opacity(0.5)).frame(width: 0.5, height: 34).padding(.horizontal, 10)
    }

    private var subtitle: String {
        let unit = habit.unit.isEmpty ? "次" : habit.unit
        return "每日目标：\(Int(habit.targetPerDay)) \(unit)"
    }

    private func stat(_ label: String, _ value: String, suffix: String, highlight: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit()
                Text(suffix).font(.system(size: 13))
            }
            .foregroundStyle(highlight ? JZ.accent : Color.primary)
        }
        .frame(minWidth: 64)
    }

    /// 近 12 周：每周一组 7 格（周一到周日），下面写「第 N 周」
    private func heatmap(_ done: Set<String>) -> some View {
        let today = cal.startOfDay(for: Date())
        let mondayThisWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstMonday = cal.date(byAdding: .day, value: -7 * 11, to: mondayThisWeek) ?? today
        return HStack(alignment: .top, spacing: 10) {
            Text("近 12 周").font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
                .padding(.top, 1)
            ForEach(0..<12, id: \.self) { week in
                let monday = cal.date(byAdding: .day, value: week * 7, to: firstMonday) ?? today
                VStack(spacing: 5) {
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { dayIdx in
                            let d = cal.date(byAdding: .day, value: dayIdx, to: monday) ?? today
                            let future = d > today
                            let hit = done.contains(DataStore.key(for: d))
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(future ? JZ.controlFill.opacity(0.4) : (hit ? JZ.accent : JZ.controlFill))
                                .frame(height: 14)
                                .overlay {
                                    if cal.isDate(d, inSameDayAs: today) {
                                        RoundedRectangle(cornerRadius: 2.5).strokeBorder(Color.primary.opacity(0.5), lineWidth: 1)
                                    }
                                }
                                .help(DataStore.key(for: d) + (hit ? " 已完成" : ""))
                        }
                    }
                    Text("第 \(cal.component(.weekOfYear, from: monday)) 周")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1).fixedSize()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HabitEditSheet: View {
    let habit: HabitItem
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = 1
    @State private var unit = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("编辑习惯").font(.title3.weight(.bold))
            TextField("名称", text: $name).textFieldStyle(.roundedBorder)
            Stepper("每天 \(target) 次", value: $target, in: 1...50)
            TextField("单位（如 杯、分钟，可空）", text: $unit).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.glassButton()
                Button("保存") {
                    store.renameHabit(habit, name: name, targetPerDay: Double(target), unit: unit)
                    dismiss()
                }
                .glassButton(prominent: true)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            name = habit.name
            target = max(1, Int(habit.targetPerDay))
            unit = habit.unit
        }
    }
}
