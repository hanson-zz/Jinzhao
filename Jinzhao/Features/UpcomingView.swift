import SwiftUI

/// 即将到来：未来 14 天，按天分组显示日程 + 到期任务，空日子跳过
struct UpcomingView: View {
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.openURL) private var openURL

    private var cal: Calendar { Calendar(identifier: .gregorian) }

    private var days: [Date] {
        let today = cal.startOfDay(for: Date())
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    private func tasksDue(on day: Date) -> [TaskItem] {
        store.tasks.filter { t in
            guard let due = t.dueDate, !t.isDone else { return false }
            return cal.isDate(due, inSameDayAs: day)
        }
    }

    private func hasContent(on day: Date) -> Bool {
        !calendar.events(on: day).isEmpty || !tasksDue(on: day).isEmpty
    }

    var body: some View {
        SolidCard {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("即将到来").font(.system(size: 24, weight: .bold))
                    if calendar.authState != .authorized {
                        Text("连接苹果日历后，这里会把未来 14 天的日程和到期任务按天排好。")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if !days.contains(where: hasContent) {
                        Text("未来 14 天还没有安排。")
                            .font(.callout).foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    }
                    ForEach(days.filter { hasContent(on: $0) }, id: \.self) { day in
                        daySection(day)
                    }
                }
                .padding(20)
            }
        }
    }

    private func daySection(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(dayLabel(day)).font(.subheadline.weight(.semibold))
                Text("农历\(LunarCalendar.info(for: day).shortText)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(calendar.events(on: day)) { e in
                HStack(spacing: 10) {
                    Text(e.isAllDay ? "全天" : timeText(e.start))
                        .font(.callout.weight(.medium))
                        .frame(width: 46, alignment: .leading)
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
                .padding(.vertical, 2)
            }
            ForEach(tasksDue(on: day)) { t in
                HStack(spacing: 10) {
                    Image(systemName: "circle").foregroundStyle(.secondary)
                        .frame(width: 46)
                    Text(t.title).font(.callout)
                    if t.isImportant {
                        Label("重要", systemImage: "flag.fill").font(.caption).foregroundStyle(JZ.warm)
                    }
                    Spacer()
                    Text("任务").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if cal.isDateInToday(day) { return "今天" }
        if cal.isDateInTomorrow(day) { return "明天" }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 EEEE"
        return f.string(from: day)
    }

    private func timeText(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}
