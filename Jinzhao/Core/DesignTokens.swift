import SwiftUI
import AppKit

/// 今朝设计规范（定版，全 App 统一使用，不再随手写数值）
///
/// 字号 5 级：display 26 / title 20 / section 15 / body 13.5 / caption 11
/// 间距 3 档：S 8 / M 14 / L 20
/// 圆角 3 档：S 10（控件）/ M 15（内嵌卡）/ L 20（外层卡）
/// 配色：全部用 macOS 系统语义色（日历 / 提醒事项 / 备忘录同款），不写死任何数值：
/// 浅/深由系统适配，强调色跟随用户在「系统设置 > 外观」里的选择。
/// 强调色只出现在三处：今天的日期、当前选中项、主按钮。
enum JZ {
    // MARK: 间距（3 档）
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 14
    static let spaceL: CGFloat = 20

    // MARK: 圆角（3 档）
    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 15
    static let radiusL: CGFloat = 20

    // MARK: 配色（系统语义色）
    /// 窗口底
    static let windowBg = Color(nsColor: .windowBackgroundColor)
    /// 内容卡实底
    static let cardBg = Color(nsColor: .controlBackgroundColor)
    /// 分割线 / 发丝描边
    static let separator = Color(nsColor: .separatorColor)
    /// 系统强调色（跟随用户系统设置，不写死蓝色）
    static let accent = Color.accentColor
    /// 选中项底（系统选中色）
    static let selectedBg = Color(nsColor: .selectedContentBackgroundColor)
    /// 休 = 绿
    static let success = Color.green
    /// 班 / 重要 / 假期 = 橙
    static let warm = Color.orange
    /// 过期 / 删除 = 红
    static let danger = Color.red
    /// 节气 = 青
    static let teal = Color.teal
    /// 内嵌底（输入条、嵌套块）
    static let innerFill = Color.primary.opacity(0.045)
    /// 控件底（搜索框、胶囊等）
    static let controlFill = Color.primary.opacity(0.06)
    /// 浮层小卡底 / 描边（侧栏内的小卡，压在玻璃上）
    static let cardFill = Color(nsColor: .controlBackgroundColor)
    static let hairline = Color(nsColor: .separatorColor)
    /// hover 高亮
    static let hoverFill = Color.primary.opacity(0.06)

    /// 标签色盘：只用系统 12 色（胶囊底为该色 15% 透明，字用本色）
    static let capsulePalette: [Color] = [.red, .orange, .yellow, .green, .mint, .teal,
                                           .cyan, .blue, .indigo, .purple, .pink, .brown]
    static func capsuleColor(for name: String) -> Color {
        let idx = abs(name.hashValue) % capsulePalette.count
        return capsulePalette[idx]
    }
}

/// 外观设置（跟随系统 / 浅色 / 深色），菜单栏「显示」与设置页共用，存 UserDefaults
enum AppearanceSetting: String, CaseIterable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"

    static let storageKey = "jz.appearance"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Font {
    // MARK: 字号 5 级
    static let jzDisplay = Font.system(size: 26, weight: .bold)   // 页标题（日期大字）
    static let jzTitle = Font.system(size: 20, weight: .semibold) // 区块大标题
    static let jzSection = Font.system(size: 15, weight: .semibold) // 卡片标题
    static let jzBody = Font.system(size: 13.5)                    // 正文
    static let jzCaption = Font.system(size: 11)                   // 辅助小字
}

// MARK: - 共享小组件

/// 彩色胶囊标签（文件夹 / 标签统一用）
struct CapsuleTag: View {
    let text: String
    var color: Color? = nil

    var body: some View {
        let c = color ?? JZ.capsuleColor(for: text)
        Text(text)
            .font(.jzCaption)
            .foregroundStyle(c)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(c.opacity(0.15), in: Capsule())
    }
}

/// 列表行 hover 高亮（鼠标移入时底色浮现）
struct HoverHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(hovering ? JZ.hoverFill : Color.clear,
                        in: RoundedRectangle(cornerRadius: JZ.radiusS, style: .continuous))
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverHighlight() -> some View { modifier(HoverHighlight()) }

    /// 玻璃按钮：macOS 26 用原生玻璃按钮样式，旧系统回退系统描边样式
    @ViewBuilder func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}
