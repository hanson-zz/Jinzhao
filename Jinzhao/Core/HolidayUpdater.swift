import Foundation

/// 节假日数据更新（定版规则）：
/// - 启动时拉一次，之后每天拉一次当年和次年
/// - 来源顺序（国行优先）：自建 Cloudflare 镜像 → jsdelivr → fastly.jsdelivr → GitHub raw
///   每个地址最多等约 5 秒，失败悄悄换下一个，全程无错误弹窗
/// - 校验通过才落盘（JSON 可解析、年份对得上、日期格式正确）；拉到空数据不覆盖本地已有数据
/// - 某年从「无数据」第一次变成「有数据」时，回调 onNewArrangement，App 层据此发本地通知（如「2027 年放假安排已更新」）
final class HolidayUpdater {
    /// 自建镜像基地址，域名定名后填，例如 https://holiday.example.com （按 /年份.json 提供）
    static var mirrorBaseURL: URL? = nil

    var onNewArrangement: ((Int) -> Void)?

    private let service: HolidayService
    private let storeDir: URL
    private let session: URLSession

    init(service: HolidayService, storeDir: URL) {
        self.service = service
        self.storeDir = storeDir
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        self.session = URLSession(configuration: config)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        // 本地缓存优先于内置：先内置加载完，再合并缓存目录
        service.loadDirectory(storeDir)
    }

    static func sources(for year: Int) -> [URL] {
        var urls: [URL] = []
        if let base = mirrorBaseURL { urls.append(base.appendingPathComponent("\(year).json")) }
        urls.append(URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!)
        urls.append(URL(string: "https://fastly.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!)
        urls.append(URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!)
        return urls
    }

    /// 拉取指定年份，成功返回 true。hadDataBefore 用于判断是否需要发「安排已更新」通知。
    func refresh(year: Int, hadDataBefore: Bool) async -> Bool {
        for url in HolidayUpdater.sources(for: year) {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let file = try? JSONDecoder().decode(HolidayYearFile.self, from: data),
                  file.year == year,
                  HolidayService.isValid(file) else { continue }
            if file.days.isEmpty { return true } // 拉通了但安排未公布：正常情况，不覆盖、不通知
            let target = storeDir.appendingPathComponent("\(year).json")
            try? data.write(to: target, options: .atomic)
            service.merge(data: data)
            if !hadDataBefore { onNewArrangement?(year) }
            return true
        }
        return false
    }

    func refreshCurrentAndNext() async {
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        // 是否已有数据：借道 badge 查询无法区分，故直接看内置/缓存合并后的内部状态——
        // 简化处理：以「该年 1 月 1 日是否有条目」近似（元旦必在已公布年份数据中）。
        for y in [year, year + 1] {
            let jan1 = Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: 1, day: 1))!
            let had = service.dayEntry(on: jan1) != nil
            _ = await refresh(year: y, hadDataBefore: had)
        }
    }
}
