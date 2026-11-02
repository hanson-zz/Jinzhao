import SwiftUI

/// 三栏外壳（照效果图）：左导航（渐变玻璃）｜ 中「今天」｜ 右常驻收件箱栏
struct ShellView: View {
    let today: Date
    @State private var selection: Section = .today

    enum Section: String, CaseIterable {
        case today = "今天"
        case upcoming = "即将到来"
        case calendar = "日历"
        case notes = "笔记"
        case tasks = "任务"
        case habits = "习惯"
        case inbox = "收件箱"

        var symbol: String {
            switch self {
            case .today: return "sun.max"
            case .upcoming: return "arrow.right"
            case .calendar: return "calendar"
            case .notes: return "doc.text"
            case .tasks: return "checklist"
            case .habits: return "repeat"
            case .inbox: return "tray"
            }
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            SidebarView(selection: $selection)
                .frame(width: 208)
            TodayView(date: today)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            InboxRailView(today: today)
                .frame(width: 272)
        }
        .padding(14)
        .background(WindowBackdrop())
    }
}

/// 窗口底色：深色为深蓝紫渐变，浅色为桃蓝黄柔和渐变（效果图同款氛围）
struct WindowBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.13, green: 0.10, blue: 0.30), Color(red: 0.05, green: 0.10, blue: 0.32), Color(red: 0.02, green: 0.05, blue: 0.16)]
                : [Color(red: 0.98, green: 0.80, blue: 0.70), Color(red: 0.85, green: 0.88, blue: 0.98), Color(red: 0.98, green: 0.93, blue: 0.72)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

/// 玻璃卡片容器：macOS 26 用原生液态玻璃，视觉与效果图一致
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
    }
}
