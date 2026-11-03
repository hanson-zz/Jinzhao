import SwiftUI
import AppKit

/// 今朝设计规范（定版，全 App 统一使用，不再随手写数值）
///
/// 字号 5 级：display 26 / title 20 / section 15 / body 13.5 / caption 11
/// 间距 3 档：S 8 / M 14 / L 20
/// 圆角 3 档：S 10（控件）/ M 15（内嵌卡）/ L 20（外层玻璃卡）
/// 配色：语义色随浅/深色自动切换；蓝色（accent）只给全页唯一焦点（日期条「今天」、小日历今天），
/// 其余控件一律玻璃底 + 白/黑字，避免满屏蓝。
enum JZ {
    // MARK: 间距（3 档）
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 14
    static let spaceL: CGFloat = 20

    // MARK: 圆角（3 档）
    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 15
    static let radiusL: CGFloat = 20

    // MARK: 配色（浅 / 深双套）
    /// 唯一焦点蓝
    static let accent = Color.dynamic(light: (0.10, 0.42, 0.95), dark: (0.25, 0.55, 1.00))
    /// 习惯环等第二信息色（青），与焦点蓝区分
    static let teal = Color.dynamic(light: (0.02, 0.62, 0.55), dark: (0.18, 0.83, 0.72))
    /// 假期暖橙（下一个假期卡）
    static let warm = Color.dynamic(light: (0.92, 0.45, 0.10), dark: (1.00, 0.62, 0.25))
    static let danger = Color.dynamic(light: (0.88, 0.20, 0.20), dark: (1.00, 0.35, 0.35))
    static let success = Color.dynamic(light: (0.12, 0.65, 0.30), dark: (0.30, 0.85, 0.45))
    /// 内嵌卡底色
    static let innerFill = Color.dynamic(light: (0, 0, 0, 0.045), dark: (1, 1, 1, 0.06))
    /// 控件底色（搜索框、胶囊等）
    static let controlFill = Color.dynamic(light: (0, 0, 0, 0.055), dark: (1, 1, 1, 0.10))
    /// hover 高亮
    static let hoverFill = Color.dynamic(light: (0, 0, 0, 0.05), dark: (1, 1, 1, 0.09))

    /// 文件夹 / 标签胶囊色板（按名称哈希稳定取色）
    static let capsulePalette: [Color] = [.orange, .purple, .pink, .teal, .indigo, .brown]
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

extension Color {
    /// 由浅/深两套 RGB(A) 生成随系统外观切换的颜色
    static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        dynamic(light: (light.0, light.1, light.2, 1), dark: (dark.0, dark.1, dark.2, 1))
    }

    static func dynamic(light: (Double, Double, Double, Double), dark: (Double, Double, Double, Double)) -> Color {
        let ns = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        }
        return Color(nsColor: ns)
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
            .background(c.opacity(0.16), in: Capsule())
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
