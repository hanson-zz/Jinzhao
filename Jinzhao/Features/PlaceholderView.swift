import SwiftUI

/// 尚未开发的栏目占位页：说明这一页接下来会做什么，避免点过去一片空白
struct PlaceholderView: View {
    let section: ShellView.Section

    private var blurb: String {
        switch section {
        case .upcoming: return "未来 14 天的日程和任务会按天排在这里，过期的会醒目提醒。"
        case .calendar: return "周 / 月视图，读写苹果日历，腾讯会议、飞书、Zoom 一键入会。"
        case .notes: return "块编辑笔记，笔记里的待办可以一键转成任务。"
        case .habits: return "打卡、连续天数和完成率统计。打卡已经可以在「今天」页用，完整统计页马上就来。"
        case .inbox: return "随手记先落在这里，之后再分流成任务、笔记或日程。右栏的收件箱现在就能用。"
        default: return ""
        }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(section.rawValue)
                    .font(.title3.weight(.semibold))
                Text("即将推出")
                    .font(.jzCaption.weight(.bold))
                    .foregroundStyle(JZ.warm)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(JZ.warm.opacity(0.15), in: Capsule())
                Text(blurb)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
    }
}
