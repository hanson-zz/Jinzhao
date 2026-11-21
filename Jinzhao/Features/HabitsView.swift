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
            Text("习惯").font(.system(size: 24, weight: .bold))
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
        let rates = store.habits.map { HabitStats(habit: $0).rate(days: 30) }
        let avg = rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
        let best = store.habits.map { HabitStats(habit: $0).longestStreak }.max() ?? 0
        let current = store.habits.map { $0.streakDays }.max() ?? 0
        return HStack(spacing: 10) {
            metric("近 30 天完成率", "\(Int((avg * 100).rounded()))%", "chart.bar.fill", JZ.accent)
            metric("当前最长连续", "\(current) 天", "flame.fill", JZ.warm)
            metric("历史最长连续", "\(best) 天", "trophy.fill", JZ.success)
        }
    }

    private func metric(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .bold))
                Text(title).font(.jzCaption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusM))
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

    func rate(days: Int) -> Double {
        let set = doneSet
        guard days > 0 else { return 0 }
        var hit = 0
        for i in 0..<days {
            if let d = cal.date(byAdding: .day, value: -i, to: Date()), set.contains(DataStore.key(for: d)) { hit += 1 }
        }
        return Double(hit) / Double(days)
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
    private var cal: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        let stats = HabitStats(habit: habit)
        let done = stats.doneSet
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Button { store.advanceHabit(habit) } label: {
                    ZStack {
                        Circle().stroke(JZ.controlFill, lineWidth: 5)
                        Circle().trim(from: 0, to: habit.isComplete ? 1 : habit.fraction)
                            .stroke(habit.isComplete ? JZ.success : JZ.teal,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        if habit.isComplete {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(JZ.success)
                        } else {
                            Text("\(Int(habit.todayProgress))/\(Int(habit.targetPerDay))")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("点一下打卡；满了再点一下清零")
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: habit.todayProgress)

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name).font(.jzSection)
                    Text(subtitle).font(.jzCaption).foregroundStyle(.secondary)
                }
                Spacer()
                stat("\(habit.streakDays)", "连续")
                stat("\(stats.longestStreak)", "最长")
                stat("\(Int((stats.rate(days: 30) * 100).rounded()))%", "30 天")
                Menu {
                    Button("编辑…", action: onEdit)
                    Divider()
                    Button("删除习惯", role: .destructive) { store.deleteHabit(habit) }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
            heatmap(done)
        }
        .padding(14)
        .background(JZ.innerFill, in: RoundedRectangle(cornerRadius: JZ.radiusM, style: .continuous))
    }

    private var subtitle: String {
        let unit = habit.unit.isEmpty ? "次" : habit.unit
        return "每天 \(Int(habit.targetPerDay)) \(unit)"
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 15, weight: .bold))
            Text(label).font(.jzCaption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 42)
    }

    /// 近 12 周热力图：列 = 周（周一开始），行 = 周一…周日
    private func heatmap(_ done: Set<String>) -> some View {
        let today = cal.startOfDay(for: Date())
        let w = cal.component(.weekday, from: today)
        let mondayThisWeek = cal.date(byAdding: .day, value: -((w + 5) % 7), to: today) ?? today
        let firstMonday = cal.date(byAdding: .day, value: -7 * 11, to: mondayThisWeek) ?? today
        return HStack(alignment: .top, spacing: 3) {
            VStack(spacing: 3) {
                ForEach(Array(["一", "二", "三", "四", "五", "六", "日"].enumerated()), id: \.offset) { i, n in
                    Text(i % 2 == 0 ? n : "").font(.system(size: 8)).foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                }
            }
            ForEach(0..<12, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { dayIdx in
                        let d = cal.date(byAdding: .day, value: week * 7 + dayIdx, to: firstMonday) ?? today
                        let future = d > today
                        let hit = done.contains(DataStore.key(for: d))
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(future ? Color.clear : (hit ? JZ.success : JZ.controlFill))
                            .frame(width: 12, height: 12)
                            .overlay {
                                if cal.isDate(d, inSameDayAs: today) {
                                    RoundedRectangle(cornerRadius: 2.5).strokeBorder(JZ.accent, lineWidth: 1)
                                }
                            }
                            .help(DataStore.key(for: d) + (hit ? " 已完成" : ""))
                    }
                }
            }
            Spacer(minLength: 0)
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
