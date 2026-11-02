# 今朝 Jinzhao（开发代号，正式名待商标/域名核查后定）

Mac 上的「今天」：日历、任务、习惯、笔记合一，农历、节气、法定节假日与调休全部本地化。
液态玻璃界面，数据存本地、断网可用，GitHub 开源，免费版 + 授权码解锁 Pro。

## 文档
- `spec-v1.md` — Hanson 的 v1 原始规格
- `DECISIONS-v1.md` — 定版决策（国行优先、发行与授权、数据验收基线）
- 效果图：深/浅两版「今天」页（三栏布局），已定版为 UI 验收基准（图片暂存项目档案，后补进仓库）

## 代码（Jinzhao/）
- `Core/HolidayService.swift` — holiday-cn 数据加载与判断：休/班角标、空年份处理、下一个假期（数据优先，法定锚点回退）
- `Core/HolidayUpdater.swift` — 数据更新：自建镜像 → jsdelivr → fastly → GitHub raw，5 秒超时静默切换，校验后落盘，空数据不覆盖，新安排到达回调
- `Core/LunarCalendar.swift` — 农历月日、干支、生肖（系统中国历），农历日期反查公历（春节/端午/中秋锚点用）
- `Core/SolarTermTable.swift` — 节气表（2025–2030，生成后校验）与查询
- `Resources/Holidays/` — 内置节假日数据 2025 / 2026 / 2027（2027 为空数组，安排未公布，符合预期）
- `Core/AppModels.swift` — 任务/日程/习惯/收件箱模型 + 与效果图一致的演示数据
- `JinzhaoApp.swift` — 入口（⌘N 随手记、⌘K 启动器命令占位）
- `Features/` — 三栏外壳、侧边栏、今天页（日期条/问候/调休条/混排/习惯/笔记/明天）、右栏（收件箱 + 下一个假期小日历）
  - 注：按定版决策，今天页未放 AI 摘要；「看板」是 Pro 锁定入口
  - UI 代码已写完但尚未在 Xcode 编译（本机无 macOS 环境），与 Core 层一起待真机验证

## 已验收（2026-11-02，对照效果图基线）
- 2026-10-04～07 国庆休、10-10 班、10-08 普通工作日、10-11 普通周末，与效果图一致
- 2027 数据为空时，「下一个假期」回退逻辑给出 元旦 2027-01-01、85 天、待公布标记，与效果图一致

## 在 Xcode 里继续
1. 新建 macOS App 工程（SwiftUI，macOS 26+），把 `Jinzhao/` 源码加入 target，`Resources/Holidays` 整个文件夹以 folder reference 方式加入
2. 先跑 Core 层真机验证：用验收基线日期逐条断言（见 DECISIONS-v1.md 末节）
3. 再按模块推进 UI：外壳三栏 → 今天页 → 日历（EventKit）→ 任务 → 习惯 → 收件箱/⌘K → 笔记 → 授权

## 许可
- 本项目代码许可待定（开源协议在建仓时定）
- 节假日数据来自 [holiday-cn](https://github.com/NateScarlet/holiday-cn)（NateScarlet），MIT 许可。关于页须附项目链接与 MIT 全文（见 spec-v1.md 版权节）
